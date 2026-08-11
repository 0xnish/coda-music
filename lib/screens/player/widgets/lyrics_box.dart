import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/models/lyrics_model.dart';
import 'package:Coda/services/lyrics.dart';
import 'package:Coda/services/media_player.dart';
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
        }).catchError((_) {
          _lyricsLoaded = false;
          widget.onLyricsFound?.call(false);
          _updateWakelock();
        });
      });
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
                    return LoadedLyricsWidget(lyrics: snapshot.data!);
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
          _initialScrollDone = true;
          _currentLyricIndex = newIndex;
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
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lyrics, oldWidget.lyrics)) {
      _currentLyricIndex = -1;
      _initialScrollDone = false;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _processingStateSub?.cancel();
    super.dispose();
  }

  void _scrollToCurrentLyric(int index) {
    if (index < 0) return;
    if (_itemScrollController.isAttached && !_isUserScrolling) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        alignment: 0.44,
      );
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
