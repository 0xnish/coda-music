import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/services/equalizer_service.dart';
import 'package:Coda/services/innertube_player.dart';
import 'package:Coda/services/yt_audio_stream.dart';
import 'package:Coda/services/blocked_songs.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/add_history.dart';
import '../ytmusic/ytmusic.dart';
import 'settings_manager.dart';

class MediaPlayer extends ChangeNotifier {
  late final AudioPlayer _player;

  // The queue in its ORIGINAL order (never reordered for shuffle, like
  // Metrolist's timeline). Shuffle is only an index permutation on top of it.
  List<IndexedAudioSource> _songList = [];
  final Map<String, IndexedAudioSource> _sourceCache = {};
  final ValueNotifier<MediaItem?> _currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _currentIndex = ValueNotifier(null);
  final ValueNotifier<ButtonState> _buttonState =
      ValueNotifier(ButtonState.loading);
  Timer? _timer;
  final ValueNotifier<Duration?> _timerDuration = ValueNotifier(null);

  final ValueNotifier<LoopMode> _loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<ProgressBarState> _progressBarState =
      ValueNotifier(ProgressBarState());

  // Metrolist-style shuffle: a permutation of indices with the current song
  // first. Empty when shuffle is disabled. The queue itself is never touched.
  bool _shuffleModeEnabled = false;
  List<int> _shuffleOrder = [];

  bool autoFetching = false;

  double _playbackSpeed = 1.0;
  double _pitch = 1.0;

  Timer? _loadingTimeoutTimer;
  int _loadingRetryCount = 0;
  static const Duration _loadingTimeout = Duration(seconds: 30);
  static const int _maxLoadingRetries = 8;
  String? _lastFailedVideoId;
  bool _retryPending = false;
  bool _isRetrying = false;

  final BehaviorSubject<List<IndexedAudioSource>> _sequenceSubject =
      BehaviorSubject.seeded([]);
  final BehaviorSubject<int?> _indexSubject = BehaviorSubject.seeded(null);

  int _switchSeq = 0;
  bool _progressBarLocked = false;
  bool _switching = false;
  bool _userSeeking = false;
  Duration? _bufferingResume;
  String? _bufferingResumeId;

  bool _handlingCompletion = false;
  String? _lastCompletionSongId;
  DateTime? _lastCompletionTime;
  static const Duration _completionDebounce = Duration(seconds: 2);

  MediaPlayer() {
    _player = AudioPlayer();
    _init();
  }

  AudioPlayer get player => _player;
  List<IndexedAudioSource> get songList => List.unmodifiable(_songList);
  ValueNotifier<MediaItem?> get currentSongNotifier => _currentSongNotifier;
  ValueNotifier<int?> get currentIndex => _currentIndex;
  ValueNotifier<ButtonState> get buttonState => _buttonState;
  ValueNotifier<ProgressBarState> get progressBarState => _progressBarState;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  ValueNotifier<LoopMode> get loopMode => _loopMode;
  ValueNotifier<Duration?> get timerDuration => _timerDuration;
  double get playbackSpeed => _playbackSpeed;
  double get pitch => _pitch;

  List<int> get _effectiveIndices =>
      (_shuffleModeEnabled && _shuffleOrder.length == _songList.length)
          ? _shuffleOrder
          : List.generate(_songList.length, (i) => i);

  List<IndexedAudioSource> get displayQueue {
    if (_shuffleModeEnabled && _shuffleOrder.length == _songList.length) {
      return [for (final i in _shuffleOrder) _songList[i]];
    }
    return _songList;
  }

  int? get displayCurrentIndex {
    final cur = _currentIndex.value;
    if (cur == null || cur < 0 || cur >= _songList.length) return null;
    if (_shuffleModeEnabled && _shuffleOrder.length == _songList.length) {
      final d = _shuffleOrder.indexOf(cur);
      return d < 0 ? null : d;
    }
    return cur;
  }

  Stream<
      ({
        List<IndexedAudioSource>? sequence,
        int? currentIndex,
        MediaItem? currentItem
      })> get currentTrackStream => Rx.combineLatest2<
          List<IndexedAudioSource>,
          int?,
          ({
            List<IndexedAudioSource>? sequence,
            int? currentIndex,
            MediaItem? currentItem
          })>(
        _sequenceSubject.stream,
        _indexSubject.stream,
        (sequence, currentIndex) {
          MediaItem? currentItem;
          if (currentIndex != null &&
              currentIndex >= 0 &&
              currentIndex < sequence.length) {
            final tag = sequence[currentIndex].tag;
            if (tag is MediaItem) currentItem = tag;
          }
          return (
            sequence: sequence,
            currentIndex: currentIndex,
            currentItem: currentItem,
          );
        },
      );

  Future<void> _init() async {
    _player.setLoopMode(LoopMode.off);
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToAutofetch();
    _listenToPlayerErrors();
  }

  void _emit() {
    final index = _currentIndex.value;
    MediaItem? current;
    if (index != null && index >= 0 && index < _songList.length) {
      final tag = _songList[index].tag;
      if (tag is MediaItem) current = tag;
    }
    _currentSongNotifier.value = current;
    _sequenceSubject.add(displayQueue);
    _indexSubject.add(displayCurrentIndex);
    notifyListeners();
  }

  void _syncIndex(int? index) {
    _currentIndex.value = index;
    _emit();
  }

  void _addHistoryForCurrent() {
    final index = _currentIndex.value;
    if (index == null || index < 0 || index >= _songList.length) return;
    final tag = _songList[index].tag;
    if (tag is MediaItem && tag.extras != null) {
      addHistory(tag.extras!);
    }
  }

  void _startLoadingTimeout(String videoId) {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(_loadingTimeout, () {
      _handleLoadingTimeout(videoId);
    });
  }

  void _cancelLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
  }

  void _resetProgressBar() {
    _progressBarState.value = ProgressBarState();
  }

  Future<void> _restorePosition(Duration resume) async {
    // Keep the bar frozen while the player's position is restored so a stale
    // (reset) position never overwrites the frozen thumb.
    try {
      await _player.seek(resume);
    } catch (_) {}
    _progressBarLocked = false;
  }

  void _handleLoadingTimeout(String videoId) {
    _retryPending = false;
    _retryPlayback(videoId);
  }

  Future<void> _retryPlayback(String videoId) async {
    if (_isRetrying) return;
    _isRetrying = true;
    _bufferingResume = null;
    _bufferingResumeId = null;
    try {
      if (_loadingRetryCount >= _maxLoadingRetries) {
        _retryPending = false;
        _loadingRetryCount = 0;
        _lastFailedVideoId = null;
        _cancelLoadingTimeout();
        _buttonState.value = ButtonState.paused;
        notifyListeners();
        return;
      }

      _loadingRetryCount++;
      _lastFailedVideoId = videoId;
      _cancelLoadingTimeout();

      final currentSong = _currentSongNotifier.value;
      if (currentSong == null || currentSong.id != videoId) {
        _loadingRetryCount = 0;
        return;
      }
      final songData = currentSong.extras;
      if (songData == null) {
        _loadingRetryCount = 0;
        return;
      }

      _sourceCache.remove(videoId);
      InnertubePlayer.instance.removeFromCache(videoId);

      // Freeze the bar at the last good position so a mid-song hiccup does not
      // visually jump to 0; restore and resume once the reload succeeds.
      final savedBar = _progressBarState.value;
      _progressBarLocked = true;
      _buttonState.value = ButtonState.loading;
      notifyListeners();

      await _player.stop();
      await _player.clearAudioSources();

      final source = await _getAudioSource(songData);
      await _player.setAudioSource(source);
      await _player.play();

      // Same song: restore the frozen visuals, then seek back to where we were
      // so the thumb never jumps to 0 (YouTube Music behavior).
      _progressBarState.value = savedBar;
      if (savedBar.current > Duration.zero) {
        try {
          await _player.seek(savedBar.current);
        } catch (_) {}
      }
      _progressBarLocked = false;
      _buttonState.value = ButtonState.playing;
      notifyListeners();

      _retryPending = true;
      _startLoadingTimeout(videoId);
    } on RestrictedStreamException {
      _progressBarLocked = false;
      await _skipRestricted(videoId);
    } catch (e) {
      _progressBarLocked = false;
      _retryPending = true;
      _startLoadingTimeout(videoId);
    } finally {
      _isRetrying = false;
    }
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((event) {
      final isPlaying = event.playing;
      final processingState = event.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        _progressBarLocked = true;
        // Mid-song hiccup: remember where playback was so we can restore it
        // once ready again (the player may reset its position on re-request).
        // Never for a user seek (that would undo the seek).
        if (processingState == ProcessingState.buffering &&
            !_switching &&
            !_isRetrying &&
            !_userSeeking &&
            _bufferingResume == null) {
          _bufferingResume = _progressBarState.value.current;
          _bufferingResumeId = _currentSongNotifier.value?.id;
        }
        // A seek of an already-loaded song must not flip the play/pause button
        // to loading (YouTube Music keeps the button as-is while seeking).
        if (!GetIt.I<EqualizerService>().isApplyingEQ && !_userSeeking) {
          _buttonState.value = ButtonState.loading;
        }
        final currentVideoId = _currentSongNotifier.value?.id;
        if (currentVideoId != null && _lastFailedVideoId != currentVideoId) {
          _loadingRetryCount = 0;
          _lastFailedVideoId = null;
        }
        if (currentVideoId != null && !_userSeeking) {
          _retryPending = true;
          _startLoadingTimeout(currentVideoId);
        }
      } else if (processingState == ProcessingState.ready) {
        _userSeeking = false;
        final resume = _bufferingResume;
        final resumeId = _bufferingResumeId;
        _bufferingResume = null;
        _bufferingResumeId = null;
        final needsRestore = resume != null &&
            resumeId == _currentSongNotifier.value?.id &&
            resume > Duration.zero &&
            _player.position < resume - const Duration(seconds: 1);
        if (needsRestore) {
          unawaited(_restorePosition(resume));
        } else {
          if (!_switching && !_isRetrying) {
            _progressBarLocked = false;
          }
        }
        _retryPending = false;
        _cancelLoadingTimeout();
        _loadingRetryCount = 0;
        _lastFailedVideoId = null;
        if (!_switching && !_isRetrying) {
          _buttonState.value =
              isPlaying ? ButtonState.playing : ButtonState.paused;
        }
        if (isPlaying) {
          GetIt.I<EqualizerService>().applyEqualizer();
        }
      } else if (processingState == ProcessingState.completed) {
        _userSeeking = false;
        if (!_switching && !_isRetrying) {
          _progressBarLocked = false;
        }
        _retryPending = false;
        _cancelLoadingTimeout();
        _loadingRetryCount = 0;
        _lastFailedVideoId = null;
        _handleSongCompleted();
      } else {
        _userSeeking = false;
        if (!_switching && !_isRetrying) {
          _progressBarLocked = false;
        }
        if (!_switching && !_isRetrying) {
          if (!_retryPending) {
            _cancelLoadingTimeout();
            _buttonState.value = ButtonState.paused;
          } else {
            _buttonState.value = ButtonState.loading;
          }
        }
      }
    });
  }

  Future<void> _handleSongCompleted() async {
    final songId = _currentSongNotifier.value?.id;
    final now = DateTime.now();
    if (_handlingCompletion) return;
    if (_lastCompletionSongId == songId &&
        _lastCompletionTime != null &&
        now.difference(_lastCompletionTime!) < _completionDebounce) {
      return;
    }
    _handlingCompletion = true;
    _lastCompletionSongId = songId;
    _lastCompletionTime = now;
    try {
      await _onSongCompleted();
    } catch (_) {} finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _onSongCompleted() async {
    if (_loopMode.value == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    await _next(afterCompletion: true);
  }

  void _listenToPlayerErrors() {
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        final videoId = _currentSongNotifier.value?.id;
        if (e is RestrictedStreamException ||
            e.toString().toLowerCase().contains('restricted')) {
          _skipRestricted(videoId ?? '');
          return;
        }
        if (videoId == null) {
          _buttonState.value = ButtonState.paused;
          notifyListeners();
        } else if (!_isRetrying) {
          if (_retryPending) {
      _buttonState.value = ButtonState.loading;
      _progressBarLocked = true;
      _resetProgressBar();
      notifyListeners();
          } else {
            _retryPlayback(videoId);
          }
        }
      },
    );
  }

  void _listenToCurrentPosition() {
    _player.positionStream.listen((position) {
      if (_progressBarLocked) return;
      if (_player.processingState != ProcessingState.ready) return;
      final oldState = _progressBarState.value;
      if (oldState.current != position) {
        _progressBarState.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToBufferedPosition() {
    _player.bufferedPositionStream.listen((position) {
      if (_progressBarLocked) return;
      if (_player.processingState != ProcessingState.ready) return;
      final oldState = _progressBarState.value;
      if (oldState.buffered != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: position,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToTotalDuration() {
    _player.durationStream.listen((position) {
      final oldState = _progressBarState.value;
      final total = position ?? Duration.zero;
      if (oldState.total != total) {
        // just_audio can briefly report null/0 at stream chunk boundaries;
        // never regress a known duration to 0 (that makes the thumb jump to
        // the start). A fresh song resets total to 0 via _resetProgressBar.
        if (oldState.total > Duration.zero && total == Duration.zero) {
          return;
        }
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: total,
        );
      }
    });
  }

  void _listenToAutofetch() {
    _indexSubject.stream.listen((displayIndex) async {
      if (displayIndex == null) return;
      final orig = (_shuffleModeEnabled &&
              _shuffleOrder.length == _songList.length &&
              displayIndex < _shuffleOrder.length)
          ? _shuffleOrder[displayIndex]
          : displayIndex;
      if (orig < 0 || orig >= _songList.length) return;
      if (_songList.length - orig < 5 &&
          GetIt.I<SettingsManager>().autofetchSongs &&
          autoFetching == false) {
        autoFetching = true;
        final tag = _songList[orig].tag;
        if (tag is MediaItem) {
          List nextSongs = await GetIt.I<YTMusic>()
              .getNextSongList(videoId: tag.id);
          if (nextSongs.isNotEmpty) nextSongs.removeAt(0);
          final songMaps =
              nextSongs.map((s) => Map<String, dynamic>.from(s)).toList();
          await _appendSongs(songMaps);
        }
        autoFetching = false;
      }
    });
  }

  void changeLoopMode() {
    switch (_loopMode.value) {
      case LoopMode.off:
        _loopMode.value = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode.value = LoopMode.one;
        break;
      default:
        _loopMode.value = LoopMode.off;
        break;
    }
    _player.setLoopMode(LoopMode.off);
  }

  Future<void> skipSilence(bool value) async {
    await _player.setSkipSilenceEnabled(value);
    GetIt.I<SettingsManager>().skipSilence = value;
  }

  Future<void> setShuffleModeEnabled(bool value) async {
    if (_shuffleModeEnabled == value) return;
    _shuffleModeEnabled = value;
    if (value) {
      _enableShuffle();
    } else {
      _shuffleOrder = [];
    }
    _emit();
  }

  // Metrolist: build a shuffled permutation of the queue with the current
  // song first. The queue itself is never reordered.
  void _enableShuffle() {
    final n = _songList.length;
    _shuffleOrder = [];
    if (n <= 1) return;
    final cur = (_currentIndex.value ?? 0).clamp(0, n - 1);
    final rest = <int>[for (var i = 0; i < n; i++) if (i != cur) i]..shuffle();
    _shuffleOrder = [cur, ...rest];
  }

  Future<IndexedAudioSource> _getAudioSource(Map<String, dynamic> song,
      {bool useCache = true}) async {
    final videoId = song['videoId'];
    if (videoId == null) {
      throw Exception('No videoId');
    }

    if (useCache) {
      final cached = _sourceCache[videoId];
      if (cached != null) {
        return cached;
      }
    }

    MediaItem tag = MediaItem(
      id: videoId,
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: song['thumbnails'] != null && (song['thumbnails'] as List).isNotEmpty
          ? Uri.parse(song['thumbnails'][0]['url'].toString().replaceAll('w60-h60', 'w225-h225'))
          : null,
      artist: song['artists'] != null
          ? song['artists'].map((artist) => artist['name']).join(',')
          : null,
      extras: song,
    );

    final bool isDownloaded = song['status'] == 'DOWNLOADED' &&
        song['path'] != null &&
        (await File(song['path']).exists());

    final IndexedAudioSource source = isDownloaded
        ? AudioSource.file(song['path'], tag: tag)
        : YouTubeAudioSource(
            videoId: videoId,
            quality:
                GetIt.I<SettingsManager>().streamingQuality.name.toLowerCase(),
            tag: tag,
          );

    if (useCache) {
      _sourceCache[videoId] = source;
    }

    return source;
  }

  Future<IndexedAudioSource> _sourceFor(int index) async {
    final entry = _songList[index];
    final tag = entry.tag;
    if (tag is MediaItem && tag.extras != null) {
      return _getAudioSource(Map<String, dynamic>.from(tag.extras!));
    }
    return entry;
  }

  int _lastPlayRequestId = 0;

  Future<void> playSong(Map<String, dynamic> song) async {
    if (song['videoId'] == null) return;

    final int requestId = DateTime.now().millisecondsSinceEpoch;
    _lastPlayRequestId = requestId;

    _cancelLoadingTimeout();
    _retryPending = false;
    _loadingRetryCount = 0;
    _lastFailedVideoId = null;
    _switching = true;
    _progressBarLocked = true;
    _bufferingResume = null;
    _bufferingResumeId = null;
    _resetProgressBar();

    try {
      final source = await _getAudioSource(song);
      if (_lastPlayRequestId != requestId) return;

      _setQueue([source], 0);
      _buttonState.value = ButtonState.loading;
      notifyListeners();

      await _player.pause();
      await _player.stop();
      if (_lastPlayRequestId != requestId) return;
      await _player.clearAudioSources();
      if (_lastPlayRequestId != requestId) return;

      await _player.setAudioSource(source);
      if (_lastPlayRequestId != requestId) return;

      await _player.play();
      if (_lastPlayRequestId != requestId) return;

      _switching = false;
      _progressBarLocked = false;
      _buttonState.value = ButtonState.playing;
      notifyListeners();
      _syncIndex(0);
      _addHistoryForCurrent();
    } catch (e) {
      _switching = false;
      _progressBarLocked = false;
      if (e is RestrictedStreamException) {
        if (song['videoId'] != null) {
          BlockedSongs.instance.block(song['videoId']);
        }
        _buttonState.value = ButtonState.paused;
        notifyListeners();
        return;
      }
      if (_lastPlayRequestId == requestId && song['videoId'] != null) {
        _retryPlayback(song['videoId']);
      }
    }
  }

  Future<void> playNext(Map<String, dynamic> mediaItem) async {
    final songMaps = await _resolveSongMaps(mediaItem);
    if (songMaps.isEmpty) return;
    await _insertSongsAfterCurrent(songMaps);
  }

  Future<List<Map<String, dynamic>>> _resolveSongMaps(
      Map<String, dynamic> mediaItem) async {
    if (mediaItem['videoId'] != null) {
      return [Map<String, dynamic>.from(mediaItem)];
    } else if (mediaItem['songs'] != null) {
      return (mediaItem['songs'] as List)
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    } else if (mediaItem['playlistId'] != null) {
      final List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      return songs.map((s) => Map<String, dynamic>.from(s)).toList();
    }
    return [];
  }

  Future<void> playAll(List songs, {int index = 0}) async {
    if (songs.isEmpty) return;

    autoFetching = true;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      final queue = <IndexedAudioSource>[];
      for (final song in songMaps) {
        try {
          queue.add(await _getAudioSource(song));
        } catch (_) {}
      }

      autoFetching = false;
      if (queue.isEmpty) {
        _buttonState.value = ButtonState.paused;
        notifyListeners();
        return;
      }

      final start = index.clamp(0, queue.length - 1);
      _setQueue(queue, start);
      await _switchTo(start);
    } catch (e) {
      autoFetching = false;
      _buttonState.value = ButtonState.paused;
      notifyListeners();
    }
  }

  Future<void> preloadSongs(List songs) async {
    for (int i = 0; i < songs.length && i < 5; i++) {
      final s = Map<String, dynamic>.from(songs[i]);
      try {
        final source = await _getAudioSource(s);
        if (source is YouTubeAudioSource) {
          await source.preload();
        }
      } catch (e) {
      }
    }
  }

  void clearCache() {
    _sourceCache.clear();
  }

  Future<void> addToQueue(Map<String, dynamic> mediaItem) async {
    final songMaps = await _resolveSongMaps(mediaItem);
    if (songMaps.isEmpty) return;
    await _appendSongs(songMaps);
  }

  Future<void> startRelated(Map<String, dynamic> song,
      {bool radio = false, bool shuffle = false, bool isArtist = false}) async {
    final songMaps = <Map<String, dynamic>>[];
    if (!isArtist) {
      songMaps.add(Map<String, dynamic>.from(song));
    }
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        videoId: song['videoId'],
        playlistId: song['playlistRadioId'],
        radio: radio,
        shuffle: shuffle);
    if (songs.isNotEmpty) songs.removeAt(0);
    songMaps.addAll(songs.map((s) => Map<String, dynamic>.from(s)).toList());

    final queue = <IndexedAudioSource>[];
    for (final s in songMaps) {
      try {
        queue.add(await _getAudioSource(s));
      } catch (_) {}
    }
    if (queue.isEmpty) return;

    _setQueue(queue, 0);
    await _switchTo(0);
  }

  Future<void> startPlaylistSongs(Map endpoint) async {
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        playlistId: endpoint['playlistId'], params: endpoint['params']);
    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    if (songMaps.isEmpty) return;

    final queue = <IndexedAudioSource>[];
    for (final s in songMaps) {
      try {
        queue.add(await _getAudioSource(s));
      } catch (_) {}
    }
    if (queue.isEmpty) return;

    _setQueue(queue, 0);
    await _switchTo(0);
  }

  Future<void> stop() async {
    _cancelLoadingTimeout();
    _retryPending = false;
    _loadingRetryCount = 0;
    _lastFailedVideoId = null;
    await _player.stop();
    await _player.clearAudioSources();
    _songList = [];
    _shuffleOrder = [];
    _currentIndex.value = null;
    _currentSongNotifier.value = null;
    _sequenceSubject.add([]);
    _indexSubject.add(null);
    notifyListeners();
  }

  Future<void> _appendSongs(List<Map<String, dynamic>> songMaps) async {
    if (songMaps.isEmpty) return;
    final newSources = await Future.wait(
        songMaps.map((song) => _getAudioSource(song)));
    final oldLen = _songList.length;
    _songList.addAll(newSources);
    if (_shuffleModeEnabled && _shuffleOrder.length == oldLen && oldLen > 0) {
      _shuffleOrder.addAll(
          [for (var i = oldLen; i < _songList.length; i++) i]);
    }
    _emit();
  }

  Future<void> _insertSongsAfterCurrent(
      List<Map<String, dynamic>> songMaps) async {
    if (songMaps.isEmpty) return;
    final newSources = await Future.wait(
        songMaps.map((song) => _getAudioSource(song)));
    final oldLen = _songList.length;
    final current = _currentIndex.value;
    final insertAt =
        (current == null) ? oldLen : (current + 1).clamp(0, oldLen);
    final k = newSources.length;
    _songList.insertAll(insertAt, newSources);
    if (_shuffleModeEnabled && _shuffleOrder.length == oldLen && oldLen > 0) {
      for (var i = 0; i < _shuffleOrder.length; i++) {
        if (_shuffleOrder[i] >= insertAt) _shuffleOrder[i] += k;
      }
      final curInv = _shuffleOrder.indexOf(current ?? 0);
      final at = curInv < 0 ? 0 : curInv + 1;
      _shuffleOrder.insertAll(
          at, [for (var i = 0; i < k; i++) insertAt + i]);
    }
    _emit();
  }

  void setTimer(Duration duration) {
    int seconds = duration.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      _timerDuration.value = Duration(seconds: seconds);
      if (seconds == 0) {
        cancelTimer();
        _player.pause();
      }
      notifyListeners();
    });
  }

  void cancelTimer() {
    _timerDuration.value = null;
    _timer?.cancel();
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    try {
      await _player.setSpeed(speed);
    } catch (_) {}
    await GetIt.I<EqualizerService>().applyEqualizer();
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      await _player.setPitch(pitch);
    } catch (_) {}
    await GetIt.I<EqualizerService>().applyEqualizer();
    notifyListeners();
  }

  void _setQueue(List<IndexedAudioSource> queue, int index) {
    _songList = List.of(queue);
    if (_shuffleModeEnabled) {
      _enableShuffle();
    }
    _syncIndex(index);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _songList.length) return;
    if (newIndex < 0 || newIndex >= _songList.length) return;
    if (oldIndex == newIndex) return;

    final item = _songList.removeAt(oldIndex);
    _songList.insert(newIndex, item);

    final cur = _currentIndex.value;
    if (cur != null) {
      if (cur == oldIndex) {
        _currentIndex.value = newIndex;
      } else if (oldIndex < cur && newIndex >= cur) {
        _currentIndex.value = cur - 1;
      } else if (oldIndex > cur && newIndex <= cur) {
        _currentIndex.value = cur + 1;
      }
    }

    if (_shuffleModeEnabled) {
      _enableShuffle();
    }
    _emit();
  }

  // ---- Navigation (Metrolist: order is the permutation, not the queue) ----

  Future<void> next() => _next(afterCompletion: false);

  Future<void> previous() => _previous();

  Future<void> playAt(int displayIndex) async {
    if (displayIndex < 0) return;
    final eff = _effectiveIndices;
    if (displayIndex >= eff.length) return;
    await _switchTo(eff[displayIndex]);
  }

  Future<void> _next({bool afterCompletion = false}) async {
    if (_songList.isEmpty || _currentIndex.value == null) return;
    final eff = _effectiveIndices;
    if (eff.isEmpty) return;
    final invPos = eff.indexOf(_currentIndex.value!);
    if (invPos < 0) return;
    final nextPos = _nextPlayablePos(eff, invPos,
        wrap: _loopMode.value == LoopMode.all);
    if (nextPos == null) {
      if (afterCompletion) {
        await _player.seek(Duration.zero);
        await _player.pause();
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
      return;
    }
    await _switchTo(eff[nextPos]);
  }

  Future<void> _previous() async {
    if (_songList.isEmpty || _currentIndex.value == null) return;
    final eff = _effectiveIndices;
    if (eff.isEmpty) return;
    final invPos = eff.indexOf(_currentIndex.value!);
    if (invPos < 0) return;
    final prevPos = _prevPlayablePos(eff, invPos,
        wrap: _loopMode.value == LoopMode.all);
    if (prevPos == null) return;
    await _switchTo(eff[prevPos]);
  }

  bool _isBlockedIndex(int index) {
    if (index < 0 || index >= _songList.length) return false;
    final t = _songList[index].tag;
    return t is MediaItem && BlockedSongs.instance.contains(t.id);
  }

  /// First unblocked display position strictly after [from] (in the effective
  /// order), or null if none exists.
  int? _nextPlayablePos(List<int> eff, int from, {required bool wrap}) {
    for (var i = 1; i < eff.length; i++) {
      final p = wrap ? (from + i) % eff.length : from + i;
      if (!wrap && p >= eff.length) break;
      if (!_isBlockedIndex(eff[p])) return p;
    }
    return null;
  }

  /// First unblocked display position strictly before [from] (in the effective
  /// order), or null if none exists.
  int? _prevPlayablePos(List<int> eff, int from, {required bool wrap}) {
    for (var i = 1; i < eff.length; i++) {
      final p = wrap ? (from - i) % eff.length : from - i;
      if (!wrap && p < 0) break;
      if (!_isBlockedIndex(eff[p])) return p;
    }
    return null;
  }

  Future<void> _switchTo(int index) async {
    if (_songList.isEmpty || index < 0 || index >= _songList.length) return;
    final tag = _songList[index].tag;
    final id = tag is MediaItem ? tag.id : null;
    if (id != null && BlockedSongs.instance.contains(id)) {
      await _skipRestricted(id);
      return;
    }
    final seq = ++_switchSeq;
    // Instant, visible switch: the UI moves immediately and only the latest
    // request wins. Stale loads abandon themselves before touching the player.
    _syncIndex(index);
    _retryPending = false;
    _switching = true;
    _progressBarLocked = true;
    _bufferingResume = null;
    _bufferingResumeId = null;
    _resetProgressBar();
    _buttonState.value = ButtonState.loading;
    notifyListeners();
    unawaited(_doSwitch(index, seq));
  }

  Future<void> _doSwitch(int index, int seq) async {
    try {
      final source = await _sourceFor(index);
      if (seq != _switchSeq) return;
      await _player.stop();
      if (seq != _switchSeq) return;
      await _player.clearAudioSources();
      if (seq != _switchSeq) return;
      await _player.setAudioSource(source);
      if (seq != _switchSeq) return;
      await _player.play();
      if (seq != _switchSeq) return;
      _switching = false;
      _progressBarLocked = false;
      _buttonState.value = ButtonState.playing;
      notifyListeners();
      _lastCompletionSongId = _songList[index].tag?.id;
      _lastCompletionTime = DateTime.now();
      _addHistoryForCurrent();
    } catch (e) {
      if (seq != _switchSeq) return;
      _switching = false;
      _progressBarLocked = false;
      final tag = _songList[index].tag;
      final id = tag is MediaItem ? tag.id : null;
      if (e is RestrictedStreamException) {
        await _skipRestricted(id ?? '');
        return;
      }
      if (id != null) {
        _retryPlayback(id);
      } else {
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
    }
  }

  Future<void> _skipRestricted(String videoId) async {
    _cancelLoadingTimeout();
    _retryPending = false;
    _loadingRetryCount = 0;
    _lastFailedVideoId = null;

    if (videoId.isNotEmpty) {
      BlockedSongs.instance.block(videoId);
    }

    // Remove the blocked song by id, never the currently playing song.
    int target = -1;
    for (var i = 0; i < _songList.length; i++) {
      final t = _songList[i].tag;
      if (t is MediaItem && t.id == videoId) {
        target = i;
        break;
      }
    }
    if (target < 0) {
      _buttonState.value = ButtonState.paused;
      notifyListeners();
      return;
    }

    _songList.removeAt(target);
    int shufflePos = -1;
    if (_shuffleModeEnabled &&
        _shuffleOrder.length == _songList.length + 1) {
      shufflePos = _shuffleOrder.indexOf(target);
      if (shufflePos >= 0) _shuffleOrder.removeAt(shufflePos);
      _shuffleOrder = [
        for (final i in _shuffleOrder) i > target ? i - 1 : i,
      ];
    }
    _sourceCache.remove(videoId);
    InnertubePlayer.instance.removeFromCache(videoId);

    if (_songList.isEmpty) {
      _currentIndex.value = null;
      _buttonState.value = ButtonState.paused;
      _emit();
      return;
    }

    // The song that followed the blocked one is the next to play.
    int? next;
    if (_shuffleModeEnabled &&
        _shuffleOrder.length == _songList.length) {
      if (shufflePos >= 0 && shufflePos < _shuffleOrder.length) {
        next = _shuffleOrder[shufflePos];
      }
    } else if (target < _songList.length) {
      next = target;
    }

    if (next == null) {
      if (_loopMode.value == LoopMode.all) {
        await _switchTo(0);
      } else {
        _currentIndex.value = null;
        _buttonState.value = ButtonState.paused;
        _emit();
      }
      return;
    }

    await _switchTo(next);
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      _player.pause();
      return;
    }

    final state = _player.processingState;

    if (state == ProcessingState.idle) {
      final song = _currentSongNotifier.value;
      if (song != null && song.extras != null) {
        await playSong(song.extras!);
      }
      return;
    }

    if (state == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (state == ProcessingState.loading || state == ProcessingState.buffering) {
      await _player.play();
      return;
    }

    await _player.play();
  }

  /// User-initiated seek (bar drag, +10s/-10s, lyrics). During the seek the
  /// play/pause button must NOT flip to loading, and seek buffering must not be
  /// treated as a mid-song hiccup (which would try to restore the old position).
  Future<void> seekTo(Duration position) async {
    _userSeeking = true;
    try {
      await _player.seek(position);
    } catch (_) {
      _userSeeking = false;
    }
  }
}

enum ButtonState { loading, paused, playing }

enum LoopState { off, all, one }

class ProgressBarState {
  Duration current;
  Duration buffered;
  Duration total;
  ProgressBarState(
      {this.current = Duration.zero,
      this.buffered = Duration.zero,
      this.total = Duration.zero});
}
