import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:Coda/services/media_player.dart';
import 'package:Coda/utils/song_thumbnail.dart';

class SquareMiniPlayer extends StatefulWidget {
  const SquareMiniPlayer({super.key});

  @override
  State<SquareMiniPlayer> createState() => _SquareMiniPlayerState();
}

class _SquareMiniPlayerState extends State<SquareMiniPlayer> {
  int? _dragMs;

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    return StreamBuilder(
      stream: mediaPlayer.currentTrackStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final currentSong = data?.currentItem;
        if (currentSong == null) return const SizedBox.shrink();

        return Container(
          width: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202020),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.push('/player'),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SongThumbnail(
                        song: currentSong.extras!,
                        dp: MediaQuery.of(context).devicePixelRatio,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _IconBtn(
                        icon: Icons.skip_previous_rounded,
                        size: 24,
                        onTap: () => mediaPlayer.previous(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: mediaPlayer.buttonState,
                        builder: (context, buttonState, _) {
                          if (buttonState == ButtonState.loading) {
                            return const Padding(
                              padding: EdgeInsets.all(4),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: LoadingIndicatorM3E(),
                              ),
                            );
                          }
                          return _IconBtn(
                            icon: buttonState == ButtonState.playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: 36,
                            onTap: () {
                              mediaPlayer.player.playing
                                  ? mediaPlayer.player.pause()
                                  : mediaPlayer.player.play();
                            },
                          );
                        },
                      ),
                      _IconBtn(
                        icon: Icons.skip_next_rounded,
                        size: 24,
                        onTap: () => mediaPlayer.next(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: ValueListenableBuilder(
                    valueListenable: mediaPlayer.progressBarState,
                    builder: (context, ProgressBarState value, child) {
                      final totalMs = value.total.inMilliseconds;
                      final currentMs = value.current.inMilliseconds;
                      return SizedBox(
                        height: 24,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.2),
                            thumbColor: Colors.white,
                            overlayColor:
                                Colors.white.withValues(alpha: 0.1),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}


