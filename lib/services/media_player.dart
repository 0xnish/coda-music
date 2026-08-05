import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/services/equalizer_service.dart';
import 'package:Coda/services/yt_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/add_history.dart';
import '../ytmusic/ytmusic.dart';
import 'settings_manager.dart';

class MediaPlayer extends ChangeNotifier {
  late final AudioPlayer _player;

  List<IndexedAudioSource> _songList = [];
  List<Map<String, dynamic>> _originalPlaylist = [];
  final Map<String, AudioSource> _sourceCache = {};
  final ValueNotifier<MediaItem?> _currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _currentIndex = ValueNotifier(null);
  final ValueNotifier<ButtonState> _buttonState =
      ValueNotifier(ButtonState.loading);
  Timer? _timer;
  final ValueNotifier<Duration?> _timerDuration = ValueNotifier(null);

  final ValueNotifier<LoopMode> _loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<ProgressBarState> _progressBarState =
      ValueNotifier(ProgressBarState());

  bool _shuffleModeEnabled = false;

  bool autoFetching = false;

  Timer? _loadingTimeoutTimer;
  int _loadingRetryCount = 0;
  static const Duration _loadingTimeout = Duration(seconds: 15);
  String? _lastFailedVideoId;


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

  Stream<
      ({
        List<IndexedAudioSource>? sequence,
        int? currentIndex,
        MediaItem? currentItem
      })> get currentTrackStream => Rx.combineLatest2<
          List<IndexedAudioSource>?,
          int?,
          ({
            List<IndexedAudioSource>? sequence,
            int? currentIndex,
            MediaItem? currentItem
          })>(
        _player.sequenceStream,
        _player.currentIndexStream,
        (sequence, currentIndex) {
          MediaItem? currentItem;
          if (sequence != null &&
              currentIndex != null &&
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
    _listenToChangesInPlaylist();
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    _listenToShuffle();
    _listenToAutofetch();
    _listenToPlayerErrors();

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

  void _handleLoadingTimeout(String videoId) async {
    _loadingRetryCount++;
    _lastFailedVideoId = videoId;

    debugPrint('Loading timeout: retrying playback for $videoId (attempt $_loadingRetryCount)');
    _sourceCache.remove(videoId);

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

    try {
      await _player.stop();
      await _player.clearAudioSources();

      final source = await _getAudioSource(songData);
      await _player.setAudioSource(source);
      await _player.play();

      _startLoadingTimeout(videoId);
    } catch (e) {
      debugPrint('Loading timeout retry failed: $e');
      _startLoadingTimeout(videoId);
    }
  }

  void _listenToChangesInPlaylist() {
    _player.sequenceStream.listen((playlist) {
      final List<IndexedAudioSource> newList =
          (playlist).cast<IndexedAudioSource>();

      if (listEquals(newList, _songList)) return;

      final bool shouldAdd = (_songList.isEmpty && newList.isNotEmpty);

      if (newList.isEmpty) {
        _currentSongNotifier.value = null;
        _currentIndex.value = null;
        _songList = [];
      } else {
        _songList = newList;

        _currentIndex.value ??= 0;
        _currentSongNotifier.value =
            (_songList.length > (_currentIndex.value ?? 0))
                ? _songList[_currentIndex.value ?? 0].tag
                : null;
      }

      if (shouldAdd == true && _currentSongNotifier.value != null) {
        addHistory(_currentSongNotifier.value!.extras!);
      }

      notifyListeners();
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((event) {
      final isPlaying = event.playing;
      final processingState = event.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        if (!GetIt.I<EqualizerService>().isApplyingEQ) {
          _buttonState.value = ButtonState.loading;
        }
        final currentVideoId = _currentSongNotifier.value?.id;
        if (currentVideoId != null && _lastFailedVideoId != currentVideoId) {
          _loadingRetryCount = 0;
          _lastFailedVideoId = null;
        }
        if (currentVideoId != null) {
          _startLoadingTimeout(currentVideoId);
        }
      } else if (processingState == ProcessingState.ready) {
        _cancelLoadingTimeout();
        _loadingRetryCount = 0;
        _lastFailedVideoId = null;
        _buttonState.value =
            isPlaying ? ButtonState.playing : ButtonState.paused;
        if (isPlaying) {
          GetIt.I<EqualizerService>().applyEqualizer();
        }
      } else if (processingState == ProcessingState.completed) {
        _cancelLoadingTimeout();
        _loadingRetryCount = 0;
        _lastFailedVideoId = null;
        _player.seek(Duration.zero);
        _player.pause();
        _buttonState.value = ButtonState.paused;
      } else {
        _cancelLoadingTimeout();
        _buttonState.value = ButtonState.paused;
      }
    });
  }

  void _listenToPlayerErrors() {
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Playback error: $e');
        if (_player.processingState != ProcessingState.buffering &&
            _player.processingState != ProcessingState.loading) {
          _buttonState.value = ButtonState.paused;
          notifyListeners();
        }
      },
    );
  }

  void _listenToCurrentPosition() {
    _player.positionStream.listen((position) {
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
      if (oldState.total != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: position ?? Duration.zero,
        );
      }
    });
  }

  void _listenToShuffle() {
  }

  void _listenToChangesInSong() {
    _player.currentIndexStream.listen((index) {
      if (_songList.isNotEmpty && _currentIndex.value != index) {
        _currentIndex.value = index;
        _currentSongNotifier.value =
            index != null && _songList.isNotEmpty && index < _songList.length
                ? _songList[index].tag
                : null;
        if (_songList.isNotEmpty && _currentIndex.value != null) {
          final MediaItem item = _songList[_currentIndex.value!].tag;
          addHistory(item.extras!);
        }
  
        notifyListeners();
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
    _player.setLoopMode(_loopMode.value);
  }

  Future<void> skipSilence(bool value) async {
    await _player.setSkipSilenceEnabled(value);
    GetIt.I<SettingsManager>().skipSilence = value;
  }

  Future<void> setShuffleModeEnabled(bool value) async {
    _shuffleModeEnabled = value;
    notifyListeners();
    try {
      if (value) {
        await _shuffleRemainingQueue();
      } else {
        await _restoreOriginalQueueOrder();
      }
    } catch (e) {
      debugPrint('Failed to toggle shuffle: $e');
    }
  }

  Future<AudioSource> _getAudioSource(Map<String, dynamic> song) async {
    final videoId = song['videoId'];
    if (videoId == null) {
      throw Exception('No videoId');
    }

    final cached = _sourceCache[videoId];
    if (cached != null) {
      return cached;
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

    final source = isDownloaded
        ? AudioSource.file(song['path'], tag: tag) as AudioSource
        : YouTubeAudioSource(
            videoId: videoId,
            quality:
                GetIt.I<SettingsManager>().streamingQuality.name.toLowerCase(),
            tag: tag,
          );

    _sourceCache[videoId] = source;

    return source;
  }

  int _lastPlayRequestId = 0;

  Future<void> playSong(Map<String, dynamic> song) async {
    if (song['videoId'] == null) return;

    final int requestId = DateTime.now().millisecondsSinceEpoch;
    _lastPlayRequestId = requestId;

    _cancelLoadingTimeout();
    _loadingRetryCount = 0;
    _lastFailedVideoId = null;

    _originalPlaylist = [song];

    MediaItem tempTag = MediaItem(
      id: song['videoId'],
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
    _currentSongNotifier.value = tempTag;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      await _player.pause();
      await _player.stop();
      if (_lastPlayRequestId != requestId) return;
      await _player.clearAudioSources();
      if (_lastPlayRequestId != requestId) return;
    } catch (e) {
      debugPrint('Failed to stop/clear player: $e');
    }

    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      final source = await _getAudioSource(song);
      if (_lastPlayRequestId != requestId)
        return;

      await _player.setAudioSource(source);
      if (_lastPlayRequestId != requestId) return;

      await _player.play();

    } catch (e) {
      debugPrint('playSong playback error for ${song['videoId']}: $e');
      if (_lastPlayRequestId == requestId) {
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
    }
  }


  Future<void> playNext(Map<String, dynamic> mediaItem) async {
    final currentSong = _currentSongNotifier.value;
    int insertIndexOrig = _originalPlaylist.length;
    if (currentSong != null) {
      final origIdx = _originalPlaylist.indexWhere((song) => song['videoId'] == currentSong.id);
      if (origIdx != -1) {
        insertIndexOrig = origIdx + 1;
      }
    }

    if (mediaItem['videoId'] != null) {
      _originalPlaylist.insert(insertIndexOrig, mediaItem);
      final audioSource = await _getAudioSource(mediaItem);

      final currentIndex = _player.currentIndex ?? -1;
      final sequenceLength = _player.sequence.length;
      final insertIndex = (currentIndex + 1).clamp(0, sequenceLength);

      if (sequenceLength > 0) {
        await _player.insertAudioSource(insertIndex, audioSource);
      } else {
        await _player.setAudioSource(audioSource);
      }


    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.insertAll(insertIndexOrig, songMaps);
      await _addSongListToQueue(songs, isNext: true);

    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.insertAll(insertIndexOrig, songMaps);
      await _addSongListToQueue(songs, isNext: true);

    }
  }

  Future<void> playAll(List songs, {int index = 0}) async {
    if (songs.isEmpty) return;

    autoFetching = true;
    _originalPlaylist = songs.map((s) => Map<String, dynamic>.from(s)).toList();

    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      await _player.clearAudioSources();

      final orderedSongs = <Map<String, dynamic>>[];
      orderedSongs.add(Map<String, dynamic>.from(songs[index]));
      for (int i = 0; i < songs.length; i++) {
        if (i != index) {
          orderedSongs.add(Map<String, dynamic>.from(songs[i]));
        }
      }

      if (_shuffleModeEnabled) {
        final first = orderedSongs.removeAt(0);
        orderedSongs.shuffle();
        orderedSongs.insert(0, first);
      }

      final sources = await Future.wait(orderedSongs.map((song) async {
        try {
          return await _getAudioSource(song);
        } catch (e) {
          return null;
        }
      }));

      final validSources = sources.whereType<AudioSource>().toList();

      if (validSources.isEmpty) {
        autoFetching = false;
        _buttonState.value = ButtonState.paused;
        notifyListeners();
        return;
      }

      await _player.setAudioSource(validSources.first);
      await _player.play();

      if (validSources.length > 1) {
        await _player.addAudioSources(validSources.sublist(1));
      }


      autoFetching = false;
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
    if (mediaItem['videoId'] != null) {
      _originalPlaylist.add(mediaItem);
      await _player.addAudioSource(await _getAudioSource(mediaItem));

    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.addAll(songMaps);
      await _addSongListToQueue(songs, isNext: false);


    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.addAll(songMaps);
      await _addSongListToQueue(songs, isNext: false);

    }
  }

  Future<void> startRelated(Map<String, dynamic> song,
      {bool radio = false, bool shuffle = false, bool isArtist = false}) async {
    _originalPlaylist = [];
    await _player.clearAudioSources();
    if (!isArtist) {
      await addToQueue(song);
    }
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        videoId: song['videoId'],
        playlistId: song['playlistRadioId'],
        radio: radio,
        shuffle: shuffle);
    if (songs.isNotEmpty) songs.removeAt(0);
    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    _originalPlaylist.addAll(songMaps);
    await _addSongListToQueue(songs, isNext: false);
    await _player.play();
  }

  Future<void> startPlaylistSongs(Map endpoint) async {
    _originalPlaylist = [];
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        playlistId: endpoint['playlistId'], params: endpoint['params']);

    if (songs.isNotEmpty && songs.first['videoId'] == null) {
    }

    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    _originalPlaylist.addAll(songMaps);

    final firstSource = await _getAudioSource(songMaps.first);
    await _player.setAudioSource(firstSource);
    await _player.play();

    if (songMaps.length > 1) {
      await _addSongListToQueue(songMaps.sublist(1));
    }
  }

  Future<void> stop() async {
    _cancelLoadingTimeout();
    _loadingRetryCount = 0;
    _lastFailedVideoId = null;
    await _player.stop();
    await _player.clearAudioSources();
    await _player.seek(Duration.zero, index: 0);
    _currentIndex.value = null;
    _currentSongNotifier.value = null;
    notifyListeners();
  }

  Future<void> _addSongListToQueue(List songs, {bool isNext = false}) async {
    if (songs.isEmpty) return;

    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    if (_shuffleModeEnabled) {
      songMaps.shuffle();
    }

    final newSources = await Future.wait(songMaps.map((song) async {
      return await _getAudioSource(song);
    }));

    final queueLength = _player.sequence.length;

    if (isNext) {
      final currentIndex = _player.currentIndex ?? -1;
      int insertIndex = (currentIndex + 1).clamp(0, queueLength);
      await _player.insertAudioSources(insertIndex, newSources);
    } else {
      await _player.addAudioSources(newSources);
    }
  }

  void _listenToAutofetch() {
    player.currentIndexStream.listen((index) async {
      if (index == null) return;
      if (player.sequence.length - index < 5 &&
          GetIt.I<SettingsManager>().autofetchSongs &&
          autoFetching == false) {
        autoFetching = true;
        List nextSongs = await GetIt.I<YTMusic>()
            .getNextSongList(videoId: player.sequence[index].tag.id);
        if (nextSongs.isNotEmpty) nextSongs.removeAt(0);
        final songMaps = nextSongs.map((s) => Map<String, dynamic>.from(s)).toList();
        _originalPlaylist.addAll(songMaps);
        await _addSongListToQueue(nextSongs);
        autoFetching = false;
      }
    });
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

  Future<AudioSource> _cloneSource(AudioSource source, Map<String, dynamic> song) async {
    if (source is UriAudioSource) {
      return AudioSource.uri(source.uri, tag: source.tag);
    }
    return await _getAudioSource(song);
  }

  Future<void> _shuffleRemainingQueue() async {
    try {
      final currentSong = _currentSongNotifier.value;
      if (currentSong == null) return;
      final currentIndex = _player.currentIndex;
      if (currentIndex == null) return;
      final currentPosition = _player.position;

      final allSources = List<IndexedAudioSource>.from(_player.sequence);
      if (allSources.isEmpty || currentIndex + 1 >= allSources.length) return;

      final beforeSources = allSources.sublist(0, currentIndex);
      final remainingSources = allSources.sublist(currentIndex + 1);

      final List<AudioSource> newBeforeSources = [];
      for (int i = 0; i < beforeSources.length; i++) {
        final src = beforeSources[i];
        final song = _originalPlaylist.firstWhere(
          (s) => s['videoId'] == (src.tag as MediaItem).id,
          orElse: () => <String, dynamic>{},
        );
        newBeforeSources.add(await _cloneSource(src, song));
      }

      final List<AudioSource> newRemainingSources = [];
      for (int i = 0; i < remainingSources.length; i++) {
        final src = remainingSources[i];
        final song = _originalPlaylist.firstWhere(
          (s) => s['videoId'] == (src.tag as MediaItem).id,
          orElse: () => <String, dynamic>{},
        );
        newRemainingSources.add(await _cloneSource(src, song));
      }

      newRemainingSources.shuffle();

      final currentSrc = allSources[currentIndex];
      final currentSongMap = _originalPlaylist.firstWhere(
        (s) => s['videoId'] == (currentSrc.tag as MediaItem).id,
        orElse: () => <String, dynamic>{},
      );
      final newCurrentSource = await _cloneSource(currentSrc, currentSongMap);

      final newSources = [...newBeforeSources, newCurrentSource, ...newRemainingSources];

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: newSources),
        initialIndex: currentIndex,
        initialPosition: currentPosition,
      );
    } catch (e) {
      debugPrint('Failed to shuffle queue: $e');
    }
  }

  Future<void> _restoreOriginalQueueOrder() async {
    try {
      final currentSong = _currentSongNotifier.value;
      if (currentSong == null) return;
      final currentPosition = _player.position;

      final allSources = List<IndexedAudioSource>.from(_player.sequence);

      final sourceMap = <String, IndexedAudioSource>{};
      for (var source in allSources) {
        final tag = source.tag;
        if (tag is MediaItem) {
          sourceMap[tag.id] = source;
        }
      }

      final usedSources = <IndexedAudioSource>{};
      final List<AudioSource> originalSources = [];
      for (var song in _originalPlaylist) {
        final videoId = song['videoId'];
        final source = sourceMap[videoId];
        if (source != null && !usedSources.contains(source)) {
          originalSources.add(await _cloneSource(source, song));
          usedSources.add(source);
        } else {
          final newSource = await _getAudioSource(song);
          originalSources.add(newSource);
        }
      }

      final origIndex = originalSources.indexWhere((source) {
        if (source is IndexedAudioSource) {
          final tag = source.tag;
          return tag is MediaItem && tag.id == currentSong.id;
        }
        return false;
      });
      if (origIndex == -1) return;

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: originalSources),
        initialIndex: origIndex,
        initialPosition: currentPosition,
      );
    } catch (e) {
      debugPrint('Failed to restore queue order: $e');
    }
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
