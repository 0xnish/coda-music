import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/core/widgets/chrome_dropdown.dart';
import 'package:Coda/models/lyrics_model.dart';
import 'package:Coda/services/lyrics.dart';
import 'package:Coda/services/media_player.dart';
import 'package:Coda/services/providers/google_translate_provider.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';


class LyricsBox extends StatefulWidget {
  const LyricsBox({
    required this.currentSong,
    required this.size,
    this.onLyricsFound,
    super.key,
  });
  final MediaItem currentSong;
  final Size size;
  final Function(bool)? onLyricsFound;

  @override
  State<LyricsBox> createState() => _LyricsBoxState();
}

class _LyricsBoxState extends State<LyricsBox> {
  Future<Lyrics>? _fetchLyricsFuture;
  bool _lyricsLoaded = false;

  bool _translated = false;
  bool _translating = false;
  String _targetLanguage = _persistedTargetLanguage;
  Lyrics? _translatedLyrics;
  String? _translationRequestLang;

  /// Sentinel selection that shows the original (untranslated) lyrics.
  static const String _originalLanguage = 'Original';

  /// Last chosen target language, kept across player open/close so a reopened
  /// lyrics view can resume in the same language.
  static String _persistedTargetLanguage = _originalLanguage;

  // Translation target languages (from the free Google Translate backend).
  static const _languages = <String>[
    'English',
    'Hindi',
    'Tamil',
    'Telugu',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Punjabi',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Japanese',
    'Korean',
    'Arabic',
    'Chinese (Simplified)',
    'Urdu',
    'Marathi',
    'Gujarati',
    'Odia',
    'Nepali',
    'Sinhala',
    'Thai',
    'Vietnamese',
    'Indonesian',
    'Turkish',
    'Russian',
    'Italian',
    'Dutch',
    'Polish',
    'Swedish',
    'Greek',
    'Hebrew',
    'Persian',
    'Romanian',
    'Ukrainian',
    'Hungarian',
    'Czech',
    'Finnish',
    'Danish',
    'Norwegian',
    'Bulgarian',
    'Croatian',
    'Serbian',
    'Slovak',
    'Lithuanian',
    'Latvian',
    'Estonian',
    'Slovenian',
    'Icelandic',
    'Swahili',
    'Zulu',
    'Afrikaans',
    'Latin',
    'Welsh',
    'Irish',
    'Esperanto',
    'Kurdish',
  ];

  @override
  void initState() {
    super.initState();
    _initFetchLyrics();
    _initWakelock();
  }

  void _initFetchLyrics() {
    _fetchLyrics();
  }

  void _initWakelock() {
    GetIt.I<MediaPlayer>().buttonState.addListener(_updateWakelock);
  }

  void _updateWakelock() {
  }

  @override
  void didUpdateWidget(covariant LyricsBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSong.id != oldWidget.currentSong.id) {
      _translated = false;
      _translating = false;
      _translatedLyrics = null;
      _translationRequestLang = null;
      _targetLanguage = _persistedTargetLanguage;
      _initFetchLyrics();
    }
  }

  void _fetchLyrics() {
    if (context.mounted) {
      setState(() {
        _fetchLyricsFuture = GetIt.I<LyricsService>().getLyrics(
          title: widget.currentSong.title,
          artist: widget.currentSong.artist,
          album: widget.currentSong.album,
          duration: widget.currentSong.duration != null ? widget.currentSong.duration!.inSeconds.toString() : null,
          videoId: widget.currentSong.id,
        );
        _lyricsLoaded = false;
        _fetchLyricsFuture!.then((lyrics) {
          _lyricsLoaded =
              (lyrics.parsedLyrics?.lyrics.isNotEmpty ?? false) ||
                  lyrics.lyricsPlain.isNotEmpty;
          widget.onLyricsFound?.call(_lyricsLoaded);
          _updateWakelock();
          // Resume in the last chosen language (e.g. when the player screen
          // is reopened after the miniplayer).
          if (_targetLanguage != _originalLanguage) {
            _translationRequestLang = _targetLanguage;
            if (mounted) _loadTranslation(lyrics);
          }
        }).catchError((_) {
          _lyricsLoaded = false;
          widget.onLyricsFound?.call(false);
          _updateWakelock();
        });
      });
    }
  }

  Future<Lyrics> _translateLyrics(Lyrics lyrics) async {
    final translator = GetIt.I<GoogleTranslateTranslator>();
    final parsed = lyrics.parsedLyrics;
    if (parsed != null && parsed.lyrics.isNotEmpty) {
      // Translate from the app's parsed lines and rebuild the LRC so the
      // translated version has exactly the same lines/timestamps as the
      // original â€” the highlight stays in sync for every language.
      final texts = parsed.lyrics.map((l) => l.text).toList();
      final translatedTexts = await translator.translateLines(
        texts,
        language: _targetLanguage,
      );
      final sb = StringBuffer();
      for (var i = 0; i < parsed.lyrics.length; i++) {
        sb.writeln(
            '${_lrcTimestamp(parsed.lyrics[i].start)}${translatedTexts[i]}');
      }
      final translatedLrc = sb.toString().trim();
      return lyrics.copyWith(
        lyricsSynced: translatedLrc,
        parsedLyrics:
            ParsedLyrics(syncedLyrics: translatedLrc, duration: lyrics.duration ?? ''),
      );
    }
    final translatedPlain = await translator.translate(
      text: lyrics.lyricsPlain,
      language: _targetLanguage,
    );
    return lyrics.copyWith(lyricsPlain: translatedPlain);
  }

  /// Formats a [Duration] as an LRC `[mm:ss.cc] ` timestamp that round-trips
  /// through `ParsedLyrics`: 2-digit centiseconds for ms divisible by 10,
  /// otherwise 3-digit milliseconds.
  static String _lrcTimestamp(Duration d) {
    final ms = d.inMilliseconds % 1000;
    final sec = d.inSeconds % 60;
    final min = d.inMinutes;
    final two = (d.inMilliseconds % 10 == 0) ? (ms ~/ 10).toString().padLeft(2, '0') : ms.toString().padLeft(3, '0');
    return '[${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.$two] ';
  }

  /// Handles a language selection. Choosing "Original" reverts to the raw
  /// lyrics; any other choice starts (or re-runs) the translation.
  void _onLanguageSelected(String language, Lyrics lyrics) {
    _persistedTargetLanguage = language;
    if (language == _originalLanguage) {
      _translationRequestLang = null;
      setState(() {
        _targetLanguage = _originalLanguage;
        _translated = false;
        _translatedLyrics = null;
        _translating = false;
      });
      return;
    }
    setState(() {
      _targetLanguage = language;
      _translating = true;
    });
    _translationRequestLang = language;
    _loadTranslation(lyrics);
  }

  Future<void> _loadTranslation(Lyrics lyrics) async {
    final requested = _translationRequestLang;
    if (requested == null) return;
    setState(() {
      _translating = true;
    });
    try {
      final translated = await _translateLyrics(lyrics);
      if (!mounted) return;
      // Ignore stale results if the user toggled off or picked another
      // language while this request was in flight.
      if (_translationRequestLang != requested) return;
      setState(() {
        _translatedLyrics = translated;
        _translated = true;
        _translating = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (_translationRequestLang != requested) return;
      setState(() {
        _translating = false;
        _translated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation failed. Check network / try again.')),
      );
    }
  }

  @override
  void dispose() {
    GetIt.I<MediaPlayer>().buttonState.removeListener(_updateWakelock);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _fetchLyricsFuture != null
            ? FutureBuilder<Lyrics>(
                future: _fetchLyricsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data == null) {
                      return const Text('No Lyrics Found (Null)');
                    }
                    final lyrics = snapshot.data!;
                    final hasLyrics =
                        (lyrics.parsedLyrics?.lyrics.isNotEmpty ?? false) ||
                            lyrics.lyricsPlain.isNotEmpty;
                    return Column(
                      children: [
                        if (hasLyrics)
                          ChromeDropdown<String>(
                            value: _targetLanguage,
                            items: [
                              ChromeDropdownItem(
                                value: _originalLanguage,
                                label: _originalLanguage,
                              ),
                              ..._languages.map(
                                (l) => ChromeDropdownItem(
                                  value: l,
                                  label: l,
                                ),
                              ),
                            ],
                            onChanged: (lang) {
                              if (lang != null) _onLanguageSelected(lang, lyrics);
                            },
                            hint: 'Select language',
                            loading: _translating,
                            selectionIcon: Icons.music_note_outlined,
                            enableSearch: true,
                          ),
                        Expanded(
                          child: LoadedLyricsWidget(
                            lyrics: _translated ? (_translatedLyrics ?? lyrics) : lyrics,
                          ),
                        ),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text('No Lyrics Found');
                  }
                  return const ExpressiveLoadingIndicator();
                },
              )
            : const ExpressiveLoadingIndicator(),
      ),
    );
  }
}


class LoadedLyricsWidget extends StatelessWidget {
  final Lyrics lyrics;
  const LoadedLyricsWidget({
    super.key,
    required this.lyrics,
  });

  @override
  Widget build(BuildContext context) {
    if ((lyrics.parsedLyrics?.lyrics.isEmpty ?? true) &&
        lyrics.lyricsPlain.isNotEmpty)
      return PlainLyricsWidget(lyrics: lyrics);
    else if (lyrics.parsedLyrics?.lyrics.isNotEmpty ?? false)
      return SyncedLyricsWidget(lyrics: lyrics);
    else
      return const Center(child: Text("No Lyrics found!"));
  }
}

class PlainLyricsWidget extends StatelessWidget {
  final Lyrics lyrics;
  const PlainLyricsWidget({
    super.key,
    required this.lyrics,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: SelectableText(
          "\n${lyrics.lyricsPlain}\n",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final Lyrics lyrics;
  const SyncedLyricsWidget({
    required this.lyrics,
    super.key,
  });

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  StreamSubscription? _streamSubscription;
  StreamSubscription? _processingStateSub;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Duration duration = Duration.zero;
  int _currentLyricIndex = -1;
  bool _initialScrollDone = false;
  
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();

    try {
      _processingStateSub = GetIt.I<MediaPlayer>()
          .player
          .processingStateStream
          .listen((processingState) {
        if (!mounted) return;
        if (processingState == ProcessingState.loading) {
          setState(() {
            _currentLyricIndex = -1;
          });
        }
      });
    } catch (e) {
    }

    try {
      _streamSubscription =
          GetIt.I<MediaPlayer>().player.positionStream.listen((event) {
        if (!mounted) return;
        final player = GetIt.I<MediaPlayer>().player;
        if (player.processingState == ProcessingState.loading) return;
        duration = event;
        final newIndex = _findCurrentLyricIndex();

        if (!_initialScrollDone) {
          _currentLyricIndex = newIndex;
          // Only consider the initial scroll done when it can actually
          // happen (the list may not be attached on the first tick yet).
          if (_itemScrollController.isAttached && !_isUserScrolling) {
            _initialScrollDone = true;
          }
          _scrollToCurrentLyric(newIndex);
          return;
        }

        if (newIndex != _currentLyricIndex) {
          setState(() {
            _currentLyricIndex = newIndex;
          });
          _scrollToCurrentLyric(newIndex);
        }
      });
    } catch (e) {
    }

    // Park the lyrics centered (first line) right away, e.g. when the lyrics
    // finish loading before the first line has started playing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrentLyric(_currentLyricIndex);
    });
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lyrics, oldWidget.lyrics)) {
      // Lyrics changed (e.g. translation finished). Re-locate the current
      // line immediately instead of waiting for the next position tick.
      _currentLyricIndex = _findCurrentLyricIndex();
      _initialScrollDone = _currentLyricIndex >= 0;
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToCurrentLyric(_currentLyricIndex);
        });
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _processingStateSub?.cancel();
    super.dispose();
  }

  void _scrollToCurrentLyric(int index) {
    if (_isUserScrolling) return;
    if (index < 0) {
      _parkCentered();
      return;
    }
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        alignment: 0.30,
      );
    }
  }

  /// Parks the first lyric line in the vertical center before playback
  /// reaches it. Retries across frames until the list is attached, so
  /// fast-loading lyrics always land centered even if the first tick or
  /// post-frame happens before the list is laid out. Alignment 0.34 (above
  /// the raw midpoint) so the multi-line text block, not just the first
  /// line, sits centered; same reading comfort as the active line (0.30).
  int _parkRetries = 0;

  void _parkCentered() {
    if (!mounted || _isUserScrolling) return;
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: 0,
        alignment: 0.34,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
      _parkRetries = 0;
    } else if (_parkRetries < 30) {
      _parkRetries++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _parkCentered());
    }
  }

  void _resyncToCurrentLyric() {
    setState(() {
      _isUserScrolling = false;
    });
    _scrollToCurrentLyric(_currentLyricIndex);
  }

  void _checkIfNearCurrentLyric() {
    if (!_isUserScrolling) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visibleIndices = positions.map((p) => p.index).toList();
    if (visibleIndices.contains(_currentLyricIndex)) {
      setState(() {
        _isUserScrolling = false;
      });
    }
  }

  int _findCurrentLyricIndex() {
    if (widget.lyrics.parsedLyrics == null) return -1;

    final lines = widget.lyrics.parsedLyrics!.lyrics;
    if (lines.isEmpty) return -1;
    if (duration.inMilliseconds < lines.first.start.inMilliseconds) {
      return -1;
    }
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].start.inMilliseconds > duration.inMilliseconds) {
        return i - 1;
      }
    }
    return lines.length - 1;
  }

  bool isCurrentLyric(int index) {
    return index == _currentLyricIndex;
  }

  void _seekToLyric(int index) {
    if (widget.lyrics.parsedLyrics == null) return;
    final lyric = widget.lyrics.parsedLyrics!.lyrics[index];
    GetIt.I<MediaPlayer>().seekTo(lyric.start);
    setState(() {
      _currentLyricIndex = index;
    });
    _scrollToCurrentLyric(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.parsedLyrics == null) return const SizedBox();

    return Stack(
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
               if (notification.direction != ScrollDirection.idle) {
                if (!_isUserScrolling) {
                  setState(() {
                    _isUserScrolling = true;
                  });
                }
                _checkIfNearCurrentLyric();
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                itemCount: widget.lyrics.parsedLyrics!.lyrics.length,
                padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.height / 2.5),
                itemBuilder: (context, index) {
                  final isCurrent = isCurrentLyric(index);
                  final displayText = widget.lyrics.parsedLyrics!.lyrics[index].text;

                  final textStyle = AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isCurrent
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      height: 1.4,
                    ),
                    child: Text(
                      displayText,
                      textAlign: TextAlign.center,
                    ),
                  );

                  return GestureDetector(
                    onTap: () => _seekToLyric(index),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32),
                      child: textStyle,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_isUserScrolling,
            child: AnimatedOpacity(
              opacity: _isUserScrolling ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: GestureDetector(
                  onTap: _resyncToCurrentLyric,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, color: Colors.black87, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Resync',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
