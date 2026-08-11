import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:Coda/services/media_player.dart';
import 'package:Coda/utils/adaptive_widgets/buttons.dart';
import 'package:Coda/utils/song_thumbnail.dart';

class BottomPlayer extends StatefulWidget {
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> {
  Color? backgroundColor;
  int? _dragMs;

  void updateBackgroundColor(ImageProvider image) async {
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      maximumColorCount: 20,
    );
    if (mounted) {
      if (palette.dominantColor != null &&
          backgroundColor != palette.dominantColor!.color) {
        setState(() {
          backgroundColor = palette.dominantColor!.color;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    return StreamBuilder(
        stream: mediaPlayer.currentTrackStream,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final currentSong = data?.currentItem;
          if (currentSong == null) return const SizedBox();

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, minHeight: 105, maxHeight: 105),
            child: GestureDetector(
              onTap: () => context.push('/player'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: (backgroundColor ?? const Color(0xFF202020)).withAlpha(255),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SongThumbnail(
                                    song: currentSong.extras!,
                                    dp: MediaQuery.of(context).devicePixelRatio,
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.fill,
                                    onImageReady: updateBackgroundColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentSong.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (currentSong.artist != null ||
                                          currentSong.extras!['subtitle'] != null)
                                        Text(
                                          currentSong.artist ??
                                              currentSong.extras!['subtitle'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AdaptiveIconButton(
                                  onPressed: () {
                                    GetIt.I<MediaPlayer>().previous();
                                  },
                                  icon: const Icon(
                                    Icons.skip_previous,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable:
                                      GetIt.I<MediaPlayer>().buttonState,
                                  builder: (context, buttonState, _) {
                                    return AdaptiveIconButton(
                                      onPressed: () {
                                        GetIt.I<MediaPlayer>().togglePlay();
                                      },
                                      icon: buttonState == ButtonState.loading
                                       ? const SizedBox(
                                               width: 28,
                                               height: 28,
                                               child: LoadingIndicatorM3E(),
                                             )
                                          : Icon(
                                              buttonState == ButtonState.playing
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              size: 28,
                                              color: Colors.white,
                                            ),
                                    );
                                  },
                                ),
                                AdaptiveIconButton(
                                  onPressed: () {
                                    GetIt.I<MediaPlayer>().next();
                                  },
                                  icon: const Icon(
                                    Icons.skip_next,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder(
                            valueListenable: mediaPlayer.progressBarState,
                            builder: (context, ProgressBarState value, child) {
                              final totalMs = value.total.inMilliseconds;
                              final currentMs = value.current.inMilliseconds;
                              return Padding(
                                padding: const EdgeInsets.only(
                                    left: 10, right: 10, bottom: 6),
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withOpacity(0.1),
                                  ),
                                  child: Slider(
                                    value: totalMs > 0
                                        ? (_dragMs ?? currentMs)
                                            .toDouble()
                                            .clamp(0.0, totalMs.toDouble())
                                        : 0,
                                    max: totalMs > 0 ? totalMs.toDouble() : 1,
                                    onChanged: (v) {
                                      setState(() => _dragMs = v.round());
                                    },
                                    onChangeEnd: (v) {
                                      mediaPlayer.seekTo(
                                          Duration(milliseconds: v.round()));
                                      setState(() => _dragMs = null);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            });
  }
}
