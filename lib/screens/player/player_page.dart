import 'dart:ui';
import 'package:Coda/core/widgets/squiggly_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:Coda/utils/song_thumbnail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'widgets/animated_gradient_bg.dart';

import '../../services/media_player.dart';
import '../../services/bottom_message.dart';
import '../../themes/dark.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/bottom_modals.dart';
import '../../utils/palette_cache.dart';
import '../../ytmusic/ytmusic.dart';
import 'widgets/lyrics_box.dart';
import 'widgets/queue_list.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.videoId});
  final String? videoId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  Color? color;
  List<Color> paletteColors = [];
  bool fetchedSong = false;
  bool _gradientPaused = false;
  bool _routeSettled = false;
  late MediaItem? currentSong;
  _PlayerPanel _panel = _PlayerPanel.queue;

  @override
  void initState() {
    super.initState();
    if (widget.videoId != null) {
      GetIt.I<YTMusic>().getSongDetails(widget.videoId!).then((song) {
        if (song != null) {
          GetIt.I<MediaPlayer>().playSong(song);
          setState(() {
            fetchedSong = true;
          });
        }
      });
    }
    currentSong = GetIt.I<MediaPlayer>().currentSongNotifier.value;
    paletteColors = PaletteCache.get(currentSong?.id ?? '') ?? [];
    GetIt.I<MediaPlayer>().currentSongNotifier.addListener(songListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final animation = route?.animation;
      if (animation == null) {
        _routeSettled = true;
      } else {
        animation.addStatusListener(_routeStatusListener);
      }
    });
  }

  void _routeStatusListener(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && !_routeSettled) {
      setState(() => _routeSettled = true);
    } else if (status == AnimationStatus.reverse && !_gradientPaused) {
      setState(() => _gradientPaused = true);
    }
  }

  @override
  void dispose() {
    GetIt.I<MediaPlayer>().currentSongNotifier.removeListener(songListener);
    super.dispose();
  }

  Widget _buildAlbumArtFace() {
    return GestureDetector(
      onTap: () => GetIt.I<MediaPlayer>().togglePlay(),
      child: currentSong == null
          ? Container(
              color: Colors.white.withValues(alpha: 0.08),
            )
          : SongThumbnail(
              song: currentSong!.extras!,
              fit: BoxFit.cover,
              onImageReady: updateBackgroundColor,
            ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  Widget _buildAlbumCard() => _cardShell(child: _buildAlbumArtFace());

  void songListener() {
    if (currentSong != GetIt.I<MediaPlayer>().currentSongNotifier.value) {
      if (mounted) {
        setState(() {
          currentSong = GetIt.I<MediaPlayer>().currentSongNotifier.value;
        });
      }
    }
  }

  void _showSpeedControl() {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SpeedControlSheet(mediaPlayer: mediaPlayer),
    );
  }

  Future<void> updateBackgroundColor(ImageProvider image) async {
    if (!_routeSettled) {
      await _waitUntilSettled();
    }
    if (!mounted) return;
    final palette = await PaletteGenerator.fromImageProvider(
      ResizeImage(image, width: 64, height: 64),
      maximumColorCount: 20,
    );
    if (!mounted) return;
    List<Color> extractedColors = [];

    if (palette.dominantColor != null) {
      extractedColors.add(palette.dominantColor!.color);
    }
    if (palette.vibrantColor != null) {
      extractedColors.add(palette.vibrantColor!.color);
    }
    if (palette.mutedColor != null) {
      extractedColors.add(palette.mutedColor!.color);
    }
    if (palette.darkVibrantColor != null) {
      extractedColors.add(palette.darkVibrantColor!.color);
    }
    if (palette.darkMutedColor != null) {
      extractedColors.add(palette.darkMutedColor!.color);
    }
    if (palette.lightVibrantColor != null) {
      extractedColors.add(palette.lightVibrantColor!.color);
    }

    if (extractedColors.isEmpty && palette.colors.isNotEmpty) {
      extractedColors = palette.colors.take(4).toList();
    }

    setState(() {
      color = palette.dominantColor?.color;
      paletteColors = extractedColors;
    });
    PaletteCache.put(currentSong?.id ?? '', extractedColors);
  }

  Future<void> _waitUntilSettled() async {
    while (mounted && !_routeSettled) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  MaterialColor primaryWhite = const MaterialColor(
    0xFFFFFFFF,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFFFFFFF),
      200: Color(0xFFFFFFFF),
      300: Color(0xFFFFFFFF),
      400: Color(0xFFFFFFFF),
      500: Color(0xFFFFFFFF),
      600: Color(0xFFFFFFFF),
      700: Color(0xFFFFFFFF),
      800: Color(0xFFFFFFFF),
      900: Color(0xFFFFFFFF),
    },
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: darkTheme(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryWhite,
          primary: primaryWhite,
          brightness: Brightness.dark,
        ),
      ),
      child: WillPopScope(
        onWillPop: () async {
          return true;
        },
        child: Scaffold(
          key: _key,
          backgroundColor: Colors.black,
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                context.pop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: _gradientPaused
                      ? const SizedBox.shrink()
                      : AnimatedGradientBackground(
                          paused: !_routeSettled,
                          colors: paletteColors.isNotEmpty
                              ? paletteColors
                              : [
                                  Colors.deepPurple.shade900,
                                  Colors.deepPurple.shade700,
                                  Colors.purple.shade800,
                                  Colors.indigo.shade900,
                                ],
                        ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 36,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.arrow_back,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isWide = constraints.maxWidth > 800;
                            if (isWide) {
                              return Stack(
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                              flex: 5, child: const SizedBox()),
                                          Expanded(
                                            flex: 6,
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _NavButtonPlayer(
                                                    icon: AdaptiveIcons.queue,
                                                    active: _panel ==
                                                        _PlayerPanel.queue,
                                                    onTap: () {
                                                      setState(() {
                                                        _panel =
                                                            _PlayerPanel.queue;
                                                      });
                                                    },
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _NavButtonPlayer(
                                                    icon: Icons.lyrics_outlined,
                                                    active: _panel ==
                                                        _PlayerPanel.lyrics,
                                                    onTap: () {
                                                      setState(() {
                                                        _panel =
                                                            _PlayerPanel.lyrics;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Center(
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth:
                                                              double.infinity),
                                                  padding: const EdgeInsets.all(
                                                      40.0),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Center(
                                                          child: AspectRatio(
                                                            aspectRatio: 1,
                                                            child:
                                                                _buildAlbumCard(),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildTitleAndControls(
                                                          context,
                                                          centered: false,
                                                          isWide: true),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 6,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(40.0),
                                                child: _BlurPanel(
                                                  child: IndexedStack(
                                                    index: _panel ==
                                                                _PlayerPanel
                                                                    .lyrics &&
                                                            currentSong != null
                                                        ? 0
                                                        : 1,
                                                    children: [
                                                      if (currentSong != null)
                                                        LyricsBox(
                                                          key: ValueKey(
                                                              currentSong!.id),
                                                          currentSong:
                                                              currentSong!,
                                                          size: Size(
                                                              constraints
                                                                      .maxWidth /
                                                                  2,
                                                              constraints
                                                                  .maxHeight),
                                                          onLyricsFound: (_) {},
                                                        )
                                                      else
                                                        const SizedBox.shrink(),
                                                      const QueueList(),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: _buildAlbumCard(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildTitleAndControls(context),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndControls(BuildContext context,
      {bool centered = false, bool isWide = false}) {
    MediaPlayer mediaPlayer = context.watch<MediaPlayer>();
    final bool hasSong = currentSong != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSong?.title ?? 'Title',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentSong?.artist ??
                        currentSong?.album ??
                        currentSong?.extras?['subtitle'] ??
                        '',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder(
              valueListenable: Hive.box('FAVOURITES').listenable(),
              builder: (context, value, child) {
                Map? item = value.get(currentSong?.extras?['videoId']);
                return AdaptiveIconButton(
                  icon: Icon(
                    item == null
                        ? AdaptiveIcons.heart
                        : AdaptiveIcons.heart_fill,
                    size: 24,
                    color: item == null
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.redAccent,
                  ),
                  onPressed: hasSong
                      ? () async {
                          if (item == null) {
                            await Hive.box('FAVOURITES').put(
                              currentSong!.extras!['videoId'],
                              {
                                ...currentSong!.extras!,
                                'createdAt':
                                    DateTime.now().millisecondsSinceEpoch
                              },
                            );
                          } else {
                            await value.delete(currentSong!.extras!['videoId']);
                          }
                        }
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      final link =
                          'https://music.youtube.com/watch?v=${currentSong?.id ?? ''}';
                      Clipboard.setData(ClipboardData(text: link));
                      BottomMessage.showText(context, 'Link copied');
                    }
                  : null,
              icon: Icon(
                Icons.link,
                size: 22,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            AdaptiveIconButton(
              onPressed: hasSong ? _showSpeedControl : null,
              icon: Icon(
                Icons.speed,
                size: 24,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => AdaptiveIconButton(
                onPressed: hasSong
                    ? () {
                        final RenderBox renderBox =
                            buttonContext.findRenderObject() as RenderBox;
                        final position = renderBox.localToGlobal(Offset.zero);
                        final size = renderBox.size;
                        Modals.showPlayerOptionsModal(
                          context,
                          mediaPlayer.currentSongNotifier.value!.extras!,
                          buttonPosition: position,
                          buttonSize: size,
                        );
                      }
                    : null,
                icon: Icon(
                  Icons.more_horiz,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        ValueListenableBuilder(
          valueListenable: mediaPlayer.progressBarState,
          builder: (context, ProgressBarState value, child) {
            return SquigglyProgressBar(
              progress: value.current,
              total: value.total,
              buffered: value.buffered,
              strokeWidth: 4,
              thumbRadius: 6,
              baseColor: Colors.white.withValues(alpha: 0.3),
              bufferedColor: Colors.white.withValues(alpha: 0.5),
              progressColor: Colors.white,
              thumbColor: Colors.white,
              timeLabelTextStyle: const TextStyle(color: Colors.white),
              onSeek: (value) => mediaPlayer.seekTo(value),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      mediaPlayer.setShuffleModeEnabled(
                          !mediaPlayer.shuffleModeEnabled);
                    }
                  : null,
              icon: Icon(
                Icons.shuffle,
                size: 24,
                color: mediaPlayer.shuffleModeEnabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      mediaPlayer.previous();
                    }
                  : null,
              icon: Icon(
                AdaptiveIcons.skip_previous,
                size: 32,
                color: Colors.white,
              ),
            ),
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      final position = mediaPlayer.player.position;
                      final target = position - const Duration(seconds: 10);
                      mediaPlayer.seekTo(
                        target < Duration.zero ? Duration.zero : target,
                      );
                    }
                  : null,
              icon: const Icon(
                Icons.keyboard_double_arrow_left,
                size: 32,
                color: Colors.white,
              ),
            ),
            Container(
              height: 64,
              width: 64,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(50)),
              child: ValueListenableBuilder(
                valueListenable: mediaPlayer.buttonState,
                builder: (context, ButtonState value, child) {
                  if (value == ButtonState.loading) {
                    return const Center(child: LoadingIndicatorM3E());
                  }
                  return IconButton(
                    onPressed: hasSong
                        ? () {
                            mediaPlayer.togglePlay();
                          }
                        : null,
                    icon: Icon(
                      value == ButtonState.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 32,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      final position = mediaPlayer.player.position;
                      final total = mediaPlayer.progressBarState.value.total;
                      final target = position + const Duration(seconds: 10);
                      mediaPlayer.seekTo(
                        total > Duration.zero && target > total
                            ? total
                            : target,
                      );
                    }
                  : null,
              icon: const Icon(
                Icons.keyboard_double_arrow_right,
                size: 32,
                color: Colors.white,
              ),
            ),
            AdaptiveIconButton(
              onPressed: hasSong
                  ? () {
                      mediaPlayer.next();
                    }
                  : null,
              icon: Icon(
                AdaptiveIcons.skip_next,
                size: 32,
                color: Colors.white,
              ),
            ),
            ValueListenableBuilder(
                valueListenable: mediaPlayer.loopMode,
                builder: (context, value, child) {
                  return AdaptiveIconButton(
                    onPressed: hasSong
                        ? () {
                            mediaPlayer.changeLoopMode();
                          }
                        : null,
                    icon: Icon(
                      value == LoopMode.off || value == LoopMode.all
                          ? AdaptiveIcons.repeat_all
                          : AdaptiveIcons.repeat_one,
                      size: 24,
                      color: value == LoopMode.off
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white,
                    ),
                  );
                }),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _NavButtonPlayer extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavButtonPlayer({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: active ? 1.0 : 0.6),
        ),
      ),
    );
  }
}

class _BlurPanel extends StatelessWidget {
  const _BlurPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withAlpha(70),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: child,
        ),
      ),
    );
  }
}

class SpeedControlSheet extends StatefulWidget {
  const SpeedControlSheet({super.key, required this.mediaPlayer});

  final MediaPlayer mediaPlayer;

  @override
  State<SpeedControlSheet> createState() => _SpeedControlSheetState();
}

class _SpeedControlSheetState extends State<SpeedControlSheet> {
  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  late double _speed = widget.mediaPlayer.playbackSpeed;
  late double _pitch = widget.mediaPlayer.pitch;

  bool get _isModified =>
      (_speed - 1.0).abs() > 0.001 || (_pitch - 1.0).abs() > 0.001;

  void _reset() {
    setState(() {
      _speed = 1.0;
      _pitch = 1.0;
    });
    widget.mediaPlayer.setPlaybackSpeed(1.0);
    widget.mediaPlayer.setPitch(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Playback speed",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _isModified ? _reset : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: _isModified ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt,
                          size: 16,
                          color: Colors.white
                              .withValues(alpha: _isModified ? 1.0 : 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Reset",
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: _isModified ? 1.0 : 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _presets
                  .map((preset) => GestureDetector(
                        onTap: () {
                          setState(() => _speed = preset);
                          widget.mediaPlayer.setPlaybackSpeed(preset);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: (_speed - preset).abs() < 0.001
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${preset}x',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                  alpha: (_speed - preset).abs() < 0.001
                                      ? 1.0
                                      : 0.7),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _speed.clamp(0.25, 2.0),
                    min: 0.25,
                    max: 2.0,
                    divisions: 35,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.2),
                    onChanged: (v) {
                      setState(() => _speed = v);
                      widget.mediaPlayer.setPlaybackSpeed(v);
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${_speed.toStringAsFixed(2)}x',
                    style: labelStyle,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _pitch.clamp(0.5, 2.0),
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.2),
                    onChanged: (v) {
                      setState(() => _pitch = v);
                      widget.mediaPlayer.setPitch(v);
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _pitch == 1.0 ? '1.0' : _pitch.toStringAsFixed(2),
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlayerPanel { queue, lyrics }
