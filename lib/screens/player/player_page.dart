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
  late MediaItem? currentSong;
  bool _showLyrics = false;


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
    GetIt.I<MediaPlayer>().currentSongNotifier.addListener(songListener);
  }

  @override
  dispose() {
    GetIt.I<MediaPlayer>().currentSongNotifier.removeListener(songListener);
    super.dispose();
  }

  void songListener() {
    if (currentSong != GetIt.I<MediaPlayer>().currentSongNotifier.value) {
      if (mounted) {
        setState(() {
          currentSong = GetIt.I<MediaPlayer>().currentSongNotifier.value;
        });
      }
    }
  }

  Future<void> updateBackgroundColor(ImageProvider image) async {
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      maximumColorCount: 20,
    );
    if (mounted) {
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
      child: (widget.videoId != null && fetchedSong == false)
          ? const Center(
              child: LoadingIndicatorM3E(),
            )
          : WillPopScope(
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
                      child: AnimatedGradientBackground(
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
                                              Expanded(flex: 5, child: const SizedBox()),
                                              Expanded(
                                                flex: 6,
                                                child: Center(
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      _NavButtonPlayer(
                                                        icon: AdaptiveIcons.queue,
                                                        active: !_showLyrics,
                                                        onTap: () {
                                                          setState(() {
                                                            _showLyrics = false;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(width: 4),
                                                      _NavButtonPlayer(
                                                        icon: Icons.lyrics_outlined,
                                                        active: _showLyrics,
                                                        onTap: () {
                                                          setState(() {
                                                            _showLyrics = true;
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
                                                      constraints: const BoxConstraints(
                                                          maxWidth: double.infinity),
                                                      padding:
                                                          const EdgeInsets.all(40.0),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Expanded(
                                                            child: Center(
                                                              child: AspectRatio(
                                                                aspectRatio: 1,
                                                                child: Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                                12),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .black
                                                                            .withValues(
                                                                                alpha:
                                                                                    0.4),
                                                                        blurRadius:
                                                                            20,
                                                                        spreadRadius:
                                                                            5,
                                                                        offset:
                                                                            const Offset(
                                                                                0,
                                                                                10),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: GestureDetector(
                                                                    onTap: () {
                                                                      GetIt.I<MediaPlayer>().togglePlay();
                                                                    },
                                                                    child: ClipRRect(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  12),
                                                                      child:
                                                                          SongThumbnail(
                                                                        song: currentSong!
                                                                            .extras!,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        onImageReady:
                                                                            updateBackgroundColor,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          _buildTitleAndControls(
                                                              context,
                                                              centered: false),
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
                                                    child: _showLyrics
                                                        ? LyricsBox(
                                                            key: ValueKey(currentSong!.id),
                                                            currentSong: currentSong!,
                                                            size: Size(
                                                                constraints.maxWidth / 2,
                                                                constraints.maxHeight),
                                                            onLyricsFound: (_) {},
                                                          )
                                                        : const QueueList(),
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
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 20,
                                                    spreadRadius: 5,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  GetIt.I<MediaPlayer>().togglePlay();
                                                },
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: SongThumbnail(
                                                    song: currentSong!.extras!,
                                                    fit: BoxFit.cover,
                                                    onImageReady:
                                                        updateBackgroundColor,
                                                  ),
                                                ),
                                              ),
                                            ),
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

  Widget _buildTitleAndControls(BuildContext context, {bool centered = false}) {
    if (currentSong == null) return const SizedBox();
    MediaPlayer mediaPlayer = context.watch<MediaPlayer>();
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
                  onPressed: () async {
                    if (item == null) {
                      await Hive.box('FAVOURITES').put(
                        currentSong!.extras!['videoId'],
                        {
                          ...currentSong!.extras!,
                          'createdAt': DateTime.now().millisecondsSinceEpoch
                        },
                      );
                    } else {
                      await value.delete(currentSong!.extras!['videoId']);
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            AdaptiveIconButton(
              onPressed: () {
                final link = 'https://music.youtube.com/watch?v=${currentSong?.id ?? ''}';
                Clipboard.setData(ClipboardData(text: link));
                BottomMessage.showText(context, 'Link copied');
              },
              icon: Icon(
                Icons.link,
                size: 22,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => AdaptiveIconButton(
                onPressed: () {
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
                },
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
              onSeek: (value) => mediaPlayer.player.seek(value),
            );
          },
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AdaptiveIconButton(
              onPressed: () {
                mediaPlayer.setShuffleModeEnabled(!mediaPlayer.shuffleModeEnabled);
              },
              icon: Icon(
                Icons.shuffle,
                size: 24,
                color: mediaPlayer.shuffleModeEnabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            AdaptiveIconButton(
              onPressed: () {
                mediaPlayer.player.seekToPrevious();
              },
              icon: Icon(
                AdaptiveIcons.skip_previous,
                size: 32,
                color: Colors.white,
              ),
            ),
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50)),
              child: ValueListenableBuilder(
                valueListenable: mediaPlayer.buttonState,
                builder: (context, ButtonState value, child) {
                  if (value == ButtonState.loading) {
                    return const Center(
                        child: LoadingIndicatorM3E());
                  }
                  return IconButton(
                    onPressed: () {
                      mediaPlayer.togglePlay();
                    },
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
              onPressed: () {
                mediaPlayer.player.seekToNext();
              },
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
                    onPressed: () {
                      mediaPlayer.changeLoopMode();
                    },
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
