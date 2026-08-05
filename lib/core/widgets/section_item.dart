import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:Coda/ytmusic/ytmusic.dart';

import '../../generated/l10n.dart';
import '../../services/bottom_message.dart';
import '../../themes/text_styles.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/enhanced_image.dart';
import '../../utils/extensions.dart';
import '../../services/media_player.dart';
import '../../utils/bottom_modals.dart';
import 'metrolist_sections.dart';

IconData _sectionIcon(String? title) {
  if (title == null) return Icons.music_note;
  final t = title.toLowerCase();
  if (t.contains('quick') || t.contains('fast')) return Icons.speed;
  if (t.contains('trend')) return Icons.trending_up;
  if (t.contains('chart')) return Icons.bar_chart;
  if (t.contains('listen') || t.contains('again') || t.contains('keep')) return Icons.history;
  if (t.contains('mixed') || t.contains('shuffle')) return Icons.shuffle;
  if (t.contains('forgotten')) return Icons.restore;
  if (t.contains('similar') || t.contains('related')) return Icons.compare_arrows;
  if (t.contains('new release')) return Icons.new_releases;
  if (t.contains('album')) return Icons.album;
  if (t.contains('artist')) return Icons.person;
  if (t.contains('playlist')) return Icons.playlist_play;
  if (t.contains('podcast')) return Icons.podcasts;
  if (t.contains('discover') || t.contains('daily')) return Icons.explore;
  if (t.contains('recommend')) return Icons.recommend;
  if (t.contains('community') || t.contains('group')) return Icons.groups;
  if (t.contains('top') || t.contains('best')) return Icons.emoji_events;
  if (t.contains('focus') || t.contains('chill') || t.contains('mood')) return Icons.psychology;
  if (t.contains('workout') || t.contains('energy')) return Icons.fitness_center;
  if (t.contains('party')) return Icons.celebration;
  if (t.contains('sleep') || t.contains('relax')) return Icons.nightlight;
  if (t.contains('romance') || t.contains('love')) return Icons.favorite;
  if (t.contains('travel') || t.contains('commute')) return Icons.directions_car;
  return Icons.music_note;
}

class SectionItem extends StatefulWidget {
  const SectionItem({required this.section, this.isMore = false, super.key});
  final Map section;
  final bool isMore;

  @override
  State<SectionItem> createState() => _SectionItemState();
}

class _SectionItemState extends State<SectionItem> {
  final AnimatedScrollController horizontalScrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  late PageController horizontalPageController;
  bool loadingMore = false;
  bool _pageControllerInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageControllerInitialized) {
      horizontalPageController = PageController(
          viewportFraction: 350 / MediaQuery.sizeOf(context).width);
      _pageControllerInitialized = true;
    }
  }

  @override
  void dispose() {
    horizontalPageController.dispose();
    horizontalScrollController.dispose();
    super.dispose();
  }

  void loadMoreItems() {
    if (widget.section['continuation'] != null) {
      setState(() {
        loadingMore = true;
      });
      GetIt.I<YTMusic>()
          .getMoreItems(continuation: widget.section['continuation'])
          .then((value) {
        setState(() {
          widget.section['contents'].addAll(value['items']);
          widget.section['continuation'] = value['continuation'];
          loadingMore = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customType = widget.section['customType'];
    if (customType == 'speed_dial') {
      return Column(
        children: [
          SpeedDialGrid(items: widget.section['contents'] ?? []),
          const SizedBox(height: 12),
        ],
      );
    }
    if (customType == 'daily_discover') {
      return Column(
        children: [
          DailyDiscoverCarousel(items: widget.section['contents'] ?? []),
          const SizedBox(height: 12),
        ],
      );
    }
    if (customType == 'mood_and_genres') {
      return Column(
        children: [
          MoodAndGenresGrid(items: widget.section['contents'] ?? []),
          const SizedBox(height: 12),
        ],
      );
    }
    return widget.section['contents'].isEmpty
        ? const SizedBox()
        : Column(
            children: [
              if (widget.section['title'] != null)
                AdaptiveListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  title: widget.section['strapline'] == null
                      ? Text(widget.section['title'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20))
                      : Text(
                          widget.section['strapline'],
                          style: TextStyle(
                              color: Colors.grey.withAlpha(200), fontSize: 14),
                        ),
                  subtitle: widget.section['strapline'] != null
                      ? Text(widget.section['title'] ?? '',
                          style:
                              mediumTextStyle(context).copyWith(fontSize: 20))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.section['trailing'] != null)
                        AdaptiveOutlinedButton(
                          onPressed: () async {
                            if (widget.section['trailing']['playable'] ==
                                    false &&
                                widget.section['trailing']['endpoint'] !=
                                    null) {
                              context.push(
                                '/browse',
                                extra: {
                                  'endpoint': widget.section['trailing']
                                      ['endpoint'],
                                  'isMore': true,
                                },
                              );
                            } else {
                              BottomMessage.showText(context,
                                  S.of(context).Songs_Will_Start_Playing_Soon);
                              if (widget.section['trailing']['endpoint'] !=
                                  null) {
                                await GetIt.I<MediaPlayer>().startPlaylistSongs(
                                    widget.section['trailing']['endpoint']);
                              } else {
                                await GetIt.I<MediaPlayer>()
                                    .playAll(widget.section['contents']);
                              }
                            }
                          },
                          child: Text(widget.section['trailing']['text'],
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      if (widget.section['viewType'] != 'SINGLE_COLUMN')
                        AdaptiveIconButton(
                          icon: Icon(AdaptiveIcons.chevron_left),
                          onPressed: () {
                            if (widget.section['viewType'] == 'COLUMN' &&
                                !widget.isMore) {
                              horizontalPageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut);
                            } else {
                              horizontalScrollController.animateTo(
                                horizontalScrollController.offset -
                                    horizontalScrollController
                                        .position.extentInside,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      if (widget.section['viewType'] != 'SINGLE_COLUMN')
                        AdaptiveIconButton(
                          icon: Icon(AdaptiveIcons.chevron_right),
                          onPressed: () {
                            if (widget.section['viewType'] == 'COLUMN' &&
                                !widget.isMore) {
                              horizontalPageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut);
                            } else {
                              horizontalScrollController.animateTo(
                                horizontalScrollController.offset +
                                    horizontalScrollController
                                        .position.extentInside,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        )
                    ],
                  ),
                  leading: widget.section['thumbnails'] != null &&
                          widget.section['thumbnails']?.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            widget.section['thumbnails'].first['url'],
                          ),
                        )
                      : Icon(
                          _sectionIcon(widget.section['title']),
                          color: Colors.white54, size: 28,
                        ),
                ),
              if (widget.section['viewType'] == 'COLUMN' && !widget.isMore)
                SongList(
                  songs: widget.section['contents'],
                  controller: horizontalPageController,
                )
              else if (widget.section['viewType'] == 'SINGLE_COLUMN' ||
                  widget.isMore)
                SingleColumnList(songs: widget.section['contents'])
              else
                ItemList(
                  items: widget.section['contents'],
                  controller: horizontalScrollController,
                ),
              if (loadingMore) const LoadingIndicatorM3E(),
              if (widget.section['continuation'] != null && !loadingMore)
                AdaptiveButton(
                    onPressed: loadMoreItems, child: const Text("Load More"))
            ],
          );
  }
}

class SongList extends StatefulWidget {
  const SongList({required this.songs, required this.controller, super.key});
  final List songs;
  final PageController controller;

  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  late int num;
  late int pages;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    num = widget.songs.length <= 5 ? widget.songs.length : 4;
    pages = widget.songs.length ~/ num;
    pages = (pages * num) < widget.songs.length ? pages + 1 : pages;
    return ExpandablePageView.builder(
      controller: widget.controller,
      padEnds: false,
      itemCount: pages,
      itemBuilder: (context, index) {
        int start = index * num;
        int end = start + num;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: widget.songs
                .sublist(start, min(end, widget.songs.length))
                .map((pageSongs) {
              return SongTile(song: pageSongs);
            }).toList(),
          ),
        );
      },
    );
  }
}

class SingleColumnList extends StatelessWidget {
  const SingleColumnList({required this.songs, super.key});
  final List songs;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: songs.map((song) {
        return SongTile(song: song);
      }).toList(),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({required this.song, this.playlistId, this.onTap, super.key});
  final String? playlistId;
  final Map song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    List thumbnails = song['thumbnails'];
    double height =
        (song['aspectRatio'] != null ? 50 / song['aspectRatio'] : 50)
            .toDouble();
    return AdaptiveListTile(
         onTap: onTap ?? () async {
           if (song['chartUrl'] != null) {
             context.push('/chart_details',
                 extra: song['chartUrl']);
           } else if (song['endpoint'] != null && song['videoId'] == null) {
             context.push(
               '/browse',
               extra: {
                 'endpoint': song['endpoint'],
               },
             );
           } else if (song['isChart'] == true) {
             BottomMessage.showText(context, "Searching and playing ${song['title']}...");
             final query = "${song['title']} ${song['subtitle'] ?? ''}";
             try {
                 final result = await GetIt.I<YTMusic>().search(query, filter: 'songs');
                 if (result['sections'] != null && (result['sections'] as List).isNotEmpty) {
                    final section = result['sections'][0];
                    if (section['contents'] != null && (section['contents'] as List).isNotEmpty) {
                       final match = section['contents'][0];
                       await GetIt.I<MediaPlayer>().playSong(Map.from(match));
                    } else {
                        BottomMessage.showText(context, "Song not found");
                    }
                 }
             } catch (e) {
                 BottomMessage.showText(context, "Error playing song");
             }

          } else {
            await GetIt.I<MediaPlayer>().playSong(Map.from(song));

          }
        },
        onSecondaryTap: () {
          if (song['videoId'] != null) {
            Modals.showSongBottomModal(context, song);
          }
        },
        onLongPress: () {
          if (song['videoId'] != null) {
            Modals.showSongBottomModal(context, song);
          }
        },
        title: Text(song['title'] ?? "", maxLines: 1),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: CachedNetworkImage(
            imageUrl: thumbnails
                .where((el) => el['width'] >= 50)
                .toList()
                .first['url'],
            height: height,
            width: 50,
            fit: BoxFit.cover,
          ),
        ),
        subtitle: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (song['explicit'] == true)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.explicit,
                  size: 18,
                  color: Colors.grey.withOpacity(0.9),
                ),
              ),
            Expanded(
              child: Text(
                _buildSubtitle(song),
                maxLines: 1,
                style: TextStyle(color: Colors.grey.withOpacity(0.9)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: song['endpoint'] != null && song['videoId'] == null
            ? Icon(AdaptiveIcons.chevron_right)
            : null,
        description: (song['type'] == 'EPISODE' && song['description'] != null)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    ExpandableText(
                      song['description'].split('\n')?[0] ?? '',
                      expandText: S.of(context).Show_More,
                      collapseText: S.of(context).Show_Less,
                      maxLines: 3,
                      style: TextStyle(color: context.subtitleColor),
                    ),
                  ],
                ),
              )
            : null);
  }

  String _buildSubtitle(Map item) {
    List sub = [];
    if (sub.isEmpty && item['artists'] != null) {
      for (Map artist in item['artists']) {
        sub.add(artist['name']);
      }
    }
    if (sub.isEmpty && item['album'] != null) {
      sub.add(item['album']['name']);
    }
    String s = sub.join(' · ');
    return item['subtitle'] ?? s;
  }
}

class ItemList extends StatefulWidget {
  const ItemList({required this.items, this.controller, super.key});

  final List items;
  final AnimatedScrollController? controller;

  @override
  State<ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double height = constraints.maxWidth > 600 ? 200 : 150;

      return SizedBox(
        height: height + (Platform.isWindows ? 102 : 78),
        child: ListView.separated(
          controller: widget.controller,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            double width = height * (widget.items[index]?['aspectRatio'] ?? 1);
            String? subtitle = _buildSubtitle(widget.items[index]);
            return Adaptivecard(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              child: AdaptiveInkWell(
                padding: const EdgeInsets.all(12),
                onTap: () async {
                  if (widget.items[index]['chartUrl'] != null) {
                    context.push('/chart_details',
                        extra: widget.items[index]['chartUrl']);
                  } else if (widget.items[index]['endpoint'] != null &&
                      widget.items[index]['videoId'] == null) {
                    context.push(
                      '/browse',
                      extra: {
                        'endpoint': widget.items[index]['endpoint'],
                      },
                    );
                  } else {
                    await GetIt.I<MediaPlayer>()
                        .playSong(Map.from(widget.items[index]));
                  }
                },
                onSecondaryTap: () {
                  if (widget.items[index]['videoId'] != null) {
                    Modals.showSongBottomModal(context, widget.items[index]);
                  } else if (widget.items[index]['playlistId'] != null) {
                    Modals.showPlaylistBottomModal(
                        context, widget.items[index]);
                  }
                },
                onLongPress: () {
                  if (widget.items[index]['videoId'] != null) {
                    Modals.showSongBottomModal(context, widget.items[index]);
                  } else if (widget.items[index]['playlistId'] != null) {
                    Modals.showPlaylistBottomModal(
                        context, widget.items[index]);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Ink(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: widget.items[index]['type'] == 'ARTIST'
                            ? BorderRadius.circular(height / 2)
                            : BorderRadius.circular(8),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            getEnhancedImage(
                                widget.items[index]['thumbnails'].first['url'],
                                dp: MediaQuery.of(context).devicePixelRatio,
                                width: width),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AdaptiveListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 4),
                              title: Text(
                                widget.items[index]['title']
                                    .toString()
                                    .breakWord,
                                maxLines: 2,
                                style: const TextStyle(height: 1.3),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              subtitle: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (widget.items[index]['explicit'] == true)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: Icon(
                                        Icons.explicit,
                                        size: 14,
                                        color: Colors.grey.withOpacity(0.9),
                                      ),
                                    ),
                                  if (subtitle != null)
                                    Expanded(
                                      child: Text(subtitle,
                                          maxLines: 1,
                                          style: TextStyle(
                                              color:
                                                  Colors.grey.withOpacity(0.9),
                                              fontSize: 13,
                                              height: 1.2),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: widget.items.length,
        ),
      );
    });
  }

  String? _buildSubtitle(Map item) {
    List sub = [];
    if (item['subtitle'] != null) {
      sub.addAll(item['subtitle'].split('•'));
    } else if (item['description'] != null) {
      sub.addAll(item['description'].split(','));
    } else if (item['year'] != null) {
      sub.add(item['year']);
    }
    String s = sub.join(' • ').trim();
    return s.isEmpty ? null : s;
  }
}
