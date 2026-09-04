import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:scroll_animator/scroll_animator.dart';
import '../../services/media_player.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/enhanced_image.dart';
import '../../utils/bottom_modals.dart';

class TrendingSection extends StatefulWidget {
  final List items;
  const TrendingSection({required this.items, super.key});

  @override
  State<TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<TrendingSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox();
    final cardHeight = 150.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.trending_up, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Trending',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const Spacer(),
              AdaptiveOutlinedButton(
                onPressed: () {
                  if (widget.items.isNotEmpty) {
                    GetIt.I<MediaPlayer>()
                        .playSong(Map.from(widget.items[0]));
                  }
                },
                child: const Icon(Icons.play_arrow, size: 18),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight + 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 0.5),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final width = cardHeight * (item['aspectRatio'] ?? 1);
              final thumbnails = item['thumbnails'] as List? ?? [];
              final thumbUrl = thumbnails.isNotEmpty
                  ? getEnhancedImage(thumbnails.first['url'],
                      dp: MediaQuery.of(context).devicePixelRatio, width: width)
                  : '';
              final subtitle = item['subtitle'] ?? '';
              return Adaptivecard(
                elevation: 0,
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: AdaptiveInkWell(
                  padding: const EdgeInsets.all(4),
                  onTap: () async {
                    if (item['endpoint'] != null && item['videoId'] == null) {
                      context.push('/browse',
                          extra: {'endpoint': item['endpoint']});
                    } else {
                      await GetIt.I<MediaPlayer>()
                          .playSong(Map.from(item));
                    }
                  },
                  onSecondaryTap: () {
                    if (item['videoId'] != null) {
                      Modals.showSongBottomModal(context, item);
                    }
                  },
                  onLongPress: () {
                    if (item['videoId'] != null) {
                      Modals.showSongBottomModal(context, item);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    children: [
                      Ink(
                        width: width,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          image: thumbUrl.isNotEmpty
                              ? DecorationImage(
                                  fit: BoxFit.cover,
                                  image: CachedNetworkImageProvider(thumbUrl),
                                )
                              : null,
                        ),
                        child: thumbUrl.isEmpty
                            ? const Center(
                                child: Icon(Icons.music_note,
                                    size: 28, color: Colors.white38))
                            : null,
                      ),
                      Expanded(
                        child: SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['title']?.toString() ?? '',
                                maxLines: 2,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 11, height: 1.2),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              if (subtitle != null && subtitle.toString().isNotEmpty)
                                Text(
                                  subtitle.toString(),
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.withOpacity(0.9)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DailyDiscoverCarousel extends StatefulWidget {
  final List items;
  const DailyDiscoverCarousel({required this.items, super.key});

  @override
  State<DailyDiscoverCarousel> createState() => _DailyDiscoverCarouselState();
}

class _DailyDiscoverCarouselState extends State<DailyDiscoverCarousel> {
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
    if (widget.items.isEmpty) return const SizedBox();
    const cardWidth = 260.0;
    const cardHeight = 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Discover',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Based on your history',
                    style: TextStyle(color: Colors.grey.withAlpha(200), fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight + 16,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final thumbnails = item['thumbnails'] as List? ?? [];
              final thumbUrl = thumbnails.isNotEmpty
                  ? getEnhancedImage(thumbnails.first['url'], dp: MediaQuery.of(context).devicePixelRatio, width: cardWidth)
                  : '';
              final artists = item['artists'] as List? ?? [];
              final artistName = artists.isNotEmpty ? artists[0]['name'] ?? '' : '';
              return SizedBox(
                width: cardWidth,
                child: AdaptiveInkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (item['videoId'] != null) {
                      await GetIt.I<MediaPlayer>().playSong(Map.from(item));
                    } else if (item['endpoint'] != null) {
                      context.push('/browse', extra: {'endpoint': item['endpoint']});
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey.withOpacity(0.15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumbUrl.isNotEmpty)
                                CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover)
                              else
                                Container(color: Colors.grey.withOpacity(0.2), child: const Center(child: Icon(Icons.music_note, size: 48, color: Colors.white38))),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text(artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MoodAndGenresGrid extends StatefulWidget {
  final List items;
  const MoodAndGenresGrid({required this.items, super.key});

  @override
  State<MoodAndGenresGrid> createState() => _MoodAndGenresGridState();
}

class _MoodAndGenresGridState extends State<MoodAndGenresGrid> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 5 : screenWidth > 600 ? 4 : 3;
    const rows = 3;
    final perPage = crossAxisCount * rows;
    final pageCount = (widget.items.length / perPage).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.explore, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Mood & Genres',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              AdaptiveIconButton(
                icon: Icon(AdaptiveIcons.chevron_left),
                onPressed: () => _goToPage(_currentPage - 1),
              ),
              AdaptiveIconButton(
                icon: Icon(AdaptiveIcons.chevron_right),
                onPressed: () => _goToPage(_currentPage + 1),
              ),
            ],
          ),
        ),
        SizedBox(
          height: rows * (screenWidth / crossAxisCount / 4.5) + (rows - 1) * 4,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * perPage;
              final end = (start + perPage).clamp(0, widget.items.length);
              final pageItems = widget.items.sublist(start, end);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 4.5,
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) {
                    final item = pageItems[index];
                    return _MoodGenreButton(
                      title: item['title'] ?? '',
                      onTap: () {
                        if (item['endpoint'] != null) {
                          context.go('/chip', extra: item);
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoodGenreButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MoodGenreButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdaptiveInkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF3A3A3F)
              : const Color(0xFFF0F0F4),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class MultiRowHorizontalGrid extends StatefulWidget {
  final List items;
  final int rowCount;
  const MultiRowHorizontalGrid({required this.items, this.rowCount = 4, super.key});

  @override
  State<MultiRowHorizontalGrid> createState() => _MultiRowHorizontalGridState();
}

class _MultiRowHorizontalGridState extends State<MultiRowHorizontalGrid> {
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
    if (widget.items.isEmpty) return const SizedBox();
    const itemHeight = 48.0;
    const itemWidth = 200.0;

    return SizedBox(
      height: itemHeight * widget.rowCount + 8 * (widget.rowCount - 1),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: (widget.items.length / widget.rowCount).ceil(),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, pageIndex) {
          final start = pageIndex * widget.rowCount;
          final end = (start + widget.rowCount).clamp(0, widget.items.length);
          final pageItems = widget.items.sublist(start, end);
          return SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(pageItems.length, (i) {
                final item = pageItems[i];
                final thumbnails = item['thumbnails'] as List? ?? [];
                final thumbUrl = thumbnails.isNotEmpty
                    ? getEnhancedImage(thumbnails.first['url'], dp: MediaQuery.of(context).devicePixelRatio, width: 44)
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdaptiveInkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      if (item['videoId'] != null) {
                        await GetIt.I<MediaPlayer>().playSong(Map.from(item));
                      } else if (item['endpoint'] != null) {
                        context.push('/browse', extra: {'endpoint': item['endpoint']});
                      }
                    },
                    onLongPress: () {
                      if (item['videoId'] != null) Modals.showSongBottomModal(context, item);
                    },
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: thumbUrl.isNotEmpty
                                ? CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover)
                                : Container(color: Colors.grey.withOpacity(0.2), child: const Icon(Icons.music_note, size: 20, color: Colors.white38)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text((item['artists'] as List?)?.first?['name'] ?? item['subtitle'] ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
