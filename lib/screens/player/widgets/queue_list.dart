import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/services/media_player.dart';
import 'package:Coda/utils/song_thumbnail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class QueueList extends StatelessWidget {
  const QueueList({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();

    return ListenableBuilder(
      listenable: mediaPlayer,
      builder: (context, _) {
        return StreamBuilder(
          stream: mediaPlayer.currentTrackStream,
          builder: (context, snapshot) {
            final sequence = snapshot.data?.sequence ?? [];
            final currentIndex = snapshot.data?.currentIndex ?? 0;

            if (sequence.isEmpty) return const SizedBox();

            final currentItem = currentIndex >= 0 && currentIndex < sequence.length
                ? sequence[currentIndex]
                : null;

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withAlpha(70),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Column(
                    children: [
                      _NowPlayingCard(currentItem: currentItem),
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: ReorderableListView(
                            padding: EdgeInsets.zero,
                            onReorder: mediaPlayer.shuffleModeEnabled
                                ? null
                                : (oldIndex, newIndex) async {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    await mediaPlayer.reorderQueue(oldIndex, newIndex);
                                  },
                            children: [
                              for (int i = 0; i < sequence.length; i++)
                                QueueTile(
                                  key: ValueKey(sequence[i].tag?.id ?? '$i'),
                                  index: i,
                                  isCurrent: i == currentIndex,
                                  source: sequence[i],
                                ),
                              const SizedBox(height: 16, key: const ValueKey('bottom_spacer')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final IndexedAudioSource? currentItem;
  const _NowPlayingCard({this.currentItem});

  @override
  Widget build(BuildContext context) {
    if (currentItem == null) return const SizedBox(height: 8);
    final song = currentItem!.tag as MediaItem?;
    final double dp = MediaQuery.of(context).devicePixelRatio;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(18),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(80), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_arrow_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text('Now Playing',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50, height: 50,
                  child: song?.extras != null
                      ? SongThumbnail(song: song!.extras!, dp: dp, height: 50, width: 50, fit: BoxFit.cover)
                      : Icon(Icons.music_note, size: 28, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song?.title ?? 'Unknown',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(song?.artist ?? song?.album ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QueueTile extends StatefulWidget {
  final int index;
  final bool isCurrent;
  final IndexedAudioSource source;

  const QueueTile({
    super.key,
    required this.index,
    required this.isCurrent,
    required this.source,
  });

  @override
  State<QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<QueueTile> {
  void _showContextMenu() {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final MediaItem? song = widget.source.tag as MediaItem?;
    if (song == null) return;
    final extras = Map<String, dynamic>.from(song.extras!);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Play Next'),
              onTap: () {
                Navigator.pop(ctx);
                mediaPlayer.playNext(extras);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(ctx);
                mediaPlayer.addToQueue(extras);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaItem? song = widget.source.tag as MediaItem?;

    if (song == null) return const SizedBox();

    return GestureDetector(
      onLongPress: _showContextMenu,
      child: Container(
        decoration: widget.isCurrent
            ? BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
          title: Text(
            song.title,
            maxLines: 1,
            style: TextStyle(
              color: widget.isCurrent ? Theme.of(context).colorScheme.primary : null,
              fontWeight: widget.isCurrent ? FontWeight.bold : null,
            ),
          ),
          leading: ArtworkWidget(song: song, isCurrent: widget.isCurrent),
          subtitle: Text(
            song.artist ?? song.album ?? song.extras?['subtitle'] ?? '',
            maxLines: 1,
          ),
          onTap: () {
            GetIt.I<MediaPlayer>().playAt(widget.index);
          },
        ),
        ),
      ),
    );
  }
}

class ArtworkWidget extends StatelessWidget {
  final MediaItem song;
  final bool isCurrent;

  const ArtworkWidget({
    super.key,
    required this.song,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final double dp = MediaQuery.of(context).devicePixelRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SongThumbnail(
            song: song.extras!,
            dp: dp,
            height: 50,
            width: 50,
            fit: BoxFit.fill,
            errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 32),
          ),
          if (isCurrent)
            Container(
              height: 50,
              width: 50,
              color: Colors.black.withOpacity(0.6),
            ),
          if (isCurrent)
            const Positioned(
              width: 34,
              height: 34,
              left: 8,
              top: 8,
              child: Center(
                child: Icon(
                  Icons.music_note_outlined,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
