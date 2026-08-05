import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:Coda/core/utils/service_locator.dart';
import 'package:Coda/utils/internet_guard.dart';
import 'package:Coda/utils/playlist_thumbnail.dart';


import '../../../../generated/l10n.dart';
import '../../../../services/import_service.dart';
import '../../../../services/library.dart';
import '../../../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../../../utils/bottom_modals.dart';
import '../../../../themes/text_styles.dart';
import 'cubit/library_cubit.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryCubit(sl<LibraryService>())..loadLibrary(),
      child: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          return InternetGuard(
            child: Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).Saved, style: appBarTitleStyle()),
                centerTitle: true,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () {
                      Modals.showImportplaylistModal(context);
                    },
                    icon: const Icon(
                      Icons.file_download_outlined,
                      size: 25,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Modals.showCreateplaylistModal(context);
                    },
                    icon: const Icon(
                      Icons.add,
                      size: 25,
                    ),
                  ),
                ],
              ),
              body: switch (state) {
                LibraryLoading() => const Center(child: LoadingIndicatorM3E()),
                LibraryError(:final message) => Center(child: Text(message)),
                LibraryLoaded(
                  :final playlists,
                  :final favouritesCount,
                  :final downloadsCount,
                  :final historyCount
                ) =>
                  _LibraryBody(
                    playlists: playlists,
                    favouritesCount: favouritesCount,
                    downloadsCount: downloadsCount,
                    historyCount: historyCount,
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody(
      {required this.playlists,
      this.favouritesCount = 0,
      this.downloadsCount = 0,
      this.historyCount = 0});

  final Map playlists;
  final int favouritesCount;
  final int downloadsCount;
  final int historyCount;

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody> {
  late final AnimatedScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> gridItems = [];

    gridItems.add({
      'title': S.of(context).Favourites,
      'subtitle': S.of(context).nSongs(widget.favouritesCount),
      'icon': AdaptiveIcons.heart_fill,
      'onTap': () => context.push('/saved/favourites_page'),
    });

    gridItems.add({
      'title': S.of(context).Downloads,
      'subtitle': S.of(context).nSongs(widget.downloadsCount),
      'icon': AdaptiveIcons.download,
      'onTap': () => context.push('/saved/downloads_page'),
    });

    gridItems.add({
      'title': S.of(context).History,
      'subtitle': S.of(context).nSongs(widget.historyCount),
      'icon': Icons.history,
      'onTap': () => context.push('/saved/history_page'),
    });

    final sortedPlaylists = SplayTreeMap.from(widget.playlists);
    for (var entry in sortedPlaylists.entries) {
      if (entry.value == null) continue;
      final key = entry.key;
      final item = entry.value;

      if (item['isFolder'] == true) continue;

      gridItems.add({
        'title': item['title'],
        'subtitle': (item['songs'] != null || item['isPredefined'] == true)
            ? (item['isPredefined'] == true
                ? item['subtitle']
                : S.of(context).nSongs(item['songs'].length))
            : '',
        'playlist_item': item,
        'playlist_key': key,
        'onTap': () {
          if (item['isPredefined'] == true) {
            context.push(
              '/browse',
              extra: {
                'endpoint': item['endpoint'].cast<String, dynamic>(),
              },
            );
          } else {
            context.push(
              '/saved/playlist_details',
              extra: {
                'playlistkey': key,
              },
            );
          }
        },
        'onSecondaryTap': () {
           if (item['videoId'] == null && item['playlistId'] != null) {
              Modals.showPlaylistBottomModal(context, item);
           } else if (item['isPredefined'] == false) {
              Modals.showPlaylistBottomModal(
                context,
                {...item, 'playlistId': key},
              );
           }
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: gridItems.length,
          itemBuilder: (context, index) {
            final item = gridItems[index];
            return _LibraryGridCard(item: item);
          },
        );
      },
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _LibraryGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final playlistKey = item['playlist_key'];
    final isPlaylist = playlistKey != null;

    Widget card = AdaptiveInkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item['onTap'],
      onSecondaryTap: item['onSecondaryTap'], 
      onLongPress: item['onSecondaryTap'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildImage(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (item['subtitle'] != null && item['subtitle'].toString().isNotEmpty)
             Text(
              item['subtitle'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
        ],
      ),
    );

    if (!isPlaylist) return card;

    return ValueListenableBuilder<String?>(
      valueListenable: ImportService.importingKey,
      builder: (_, importingKey, child) {
        if (importingKey == null || importingKey != playlistKey) return child!;

        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: LoadingIndicatorM3E(),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: ImportService.importingCurrent,
                      builder: (_, current, __) {
                        return ValueListenableBuilder<int>(
                          valueListenable: ImportService.importingTotal,
                          builder: (_, total, __) {
                            return Text(
                              total > 0 ? 'Importing $current / $total' : 'Importing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      child: card,
    );
  }

  Widget _buildImage(BuildContext context) {
    if (item['icon'] != null) {
      return Icon(
        item['icon'],
        size: 40,
        color: Theme.of(context).iconTheme.color,
      );
    }
    
    final playlistItem = item['playlist_item'];
    if (playlistItem != null) {
       if (playlistItem['isPredefined'] == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: playlistItem['thumbnails']
                .first['url']
                .replaceAll('w540-h225', 'w512-h512'),
            fit: BoxFit.cover,
          ),
        );
      }

      if (playlistItem['songs'] != null && playlistItem['songs'].isNotEmpty) {
        return PlaylistThumbnail(
          playslist: playlistItem['songs'],
          size: 200,
          radius: 12,
        );
      }
    }

    return const Icon(CupertinoIcons.music_note_list, size: 40);
  }
}
