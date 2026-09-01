import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../../core/utils/service_locator.dart';
import '../../services/media_player.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/internet_guard.dart';
import 'cubit/search_cubit.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(sl())..init(query),
      child: _SearchPage(query: query),
    );
  }
}

class _SearchPage extends StatefulWidget {
  final String query;
  const _SearchPage({required this.query});
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  Timer? _placeholderTimer;
  int _placeholderIndex = 0;

  final List<String> _placeholders = [
    'Search for song...',
    'Search for artists...',
    'Search for albums...',
    'Search for playlists...',
    'Search for videos...',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_onFocusChange);
    _startPlaceholderAnimation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _placeholderTimer?.cancel();
    super.dispose();
  }

  void _startPlaceholderAnimation() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        if (mounted) {
          setState(() {
            _placeholderIndex =
                (_placeholderIndex + 1) % _placeholders.length;
          });
        }
      }
    });
  }

  void _onFocusChange() {
    if (mounted) {
      context.read<SearchCubit>().onFocusChange(_searchFocusNode.hasFocus);
    }
  }

  void _onSearchSubmit(String query) {
    _searchFocusNode.unfocus();
    context.read<SearchCubit>().submitSearch(query);
  }

  void _onHistoryTap(String query) {
    _searchController.text = query;
    _onSearchSubmit(query);
  }

  void _onSuggestionTap(String query) {
    _searchController.text = query;
    _onSearchSubmit(query);
  }

  @override
  Widget build(BuildContext context) {
    return InternetGuard(
      onInternetRestored: () {
        final s = context.read<SearchCubit>().state;
        if (s.query.isNotEmpty) {
          context.read<SearchCubit>().submitSearch(s.query);
        }
      },
      child: Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeholder: _placeholders[_placeholderIndex],
                  onSubmitted: _onSearchSubmit,
                  onChanged: (q) =>
                      context.read<SearchCubit>().updateQuery(q),
                ),
                _FilterChips(
                  selectedType:
                      context.watch<SearchCubit>().state.selectedType,
                  onSelected: (type) =>
                      context.read<SearchCubit>().setSearchType(type),
                ),
                Expanded(
                  child: BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, state) {
                      return _buildContent(state);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(SearchState state) {
    switch (state.uiState) {
      case SearchUIState.initial:
        return _EmptyState();
      case SearchUIState.history:
        return _HistoryList(
          history: state.searchHistory,
          onTap: _onHistoryTap,
          onClear: () => context.read<SearchCubit>().clearSearchHistory(),
        );
      case SearchUIState.suggestions:
        return _SuggestionsList(
          suggestionQueries: state.suggestionQueries,
          suggestionItems: state.suggestionItems,
          isLoading: state.isLoadingSuggestions,
          onQueryTap: _onSuggestionTap,
          onItemTap: _onSuggestionItemTap,
        );
      case SearchUIState.loading:
        return _ShimmerLoading();
      case SearchUIState.results:
        if (!state.hasResults) {
          return _NoResultsState(query: state.query);
        }
        return _ResultsList(
          state: state,
          onSongTap: _onSongTap,
          onAlbumTap: _onAlbumTap,
          onArtistTap: _onArtistTap,
          onPlaylistTap: _onPlaylistTap,
        );
      case SearchUIState.error:
        return _ErrorState(
          message: state.error ?? 'An error occurred',
          onRetry: () =>
              context.read<SearchCubit>().submitSearch(state.query),
        );
    }
  }

  void _onSuggestionItemTap(Map<String, dynamic> item) {
    if (item['videoId'] != null) {
      GetIt.I<MediaPlayer>().playSong(Map.from(item));
    } else if (item['endpoint'] != null) {
      context.push('/browse', extra: {'endpoint': item['endpoint']});
    }
  }

  void _onSongTap(Map<String, dynamic> item) async {
    if (item['videoId'] != null) {
      await GetIt.I<MediaPlayer>().playSong(Map.from(item));
    }
  }

  void _onAlbumTap(Map<String, dynamic> item) {
    if (item['endpoint'] != null) {
      context.push('/browse', extra: {'endpoint': item['endpoint']});
    }
  }

  void _onArtistTap(Map<String, dynamic> item) {
    if (item['endpoint'] != null) {
      context.push('/browse', extra: {'endpoint': item['endpoint']});
    }
  }

  void _onPlaylistTap(Map<String, dynamic> item) {
    if (item['videoId'] != null) {
      GetIt.I<MediaPlayer>().playSong(Map.from(item));
    } else if (item['endpoint'] != null) {
      context.push('/browse', extra: {'endpoint': item['endpoint']});
    }
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focusNode.hasFocus
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmitted,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: controller.text.isEmpty ? placeholder : null,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  focusNode.requestFocus();
                  onChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final SearchType selectedType;
  final ValueChanged<SearchType> onSelected;

  const _FilterChips({
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: SearchType.values.map((type) {
          final isSelected = type == selectedType;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onSelected(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  _typeLabel(type),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _typeLabel(SearchType type) {
    switch (type) {
      case SearchType.all: return 'All';
      case SearchType.songs: return 'Songs';
      case SearchType.albums: return 'Albums';
      case SearchType.artists: return 'Artists';
      case SearchType.playlists: return 'Playlists';
      case SearchType.videos: return 'Videos';
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('Everything you need',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
        ],
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  final List<String> history;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  const _HistoryList({required this.history, required this.onTap, required this.onClear});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
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
    if (widget.history.isEmpty) {
      return Center(child: Text('No search history', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text('Recent searches', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClear,
                child: Text('Clear all', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(child: ListView.builder(
          controller: _scrollController,
          itemCount: widget.history.length,
          itemBuilder: (context, index) {
            return AdaptiveListTile(
              onTap: () => widget.onTap(widget.history[index]),
              leading: Icon(Icons.history, size: 20, color: Colors.white.withValues(alpha: 0.4)),
              title: Text(widget.history[index], style: const TextStyle(color: Colors.white, fontSize: 14)),
            );
          },
        )),
      ],
    );
  }
}

class _SuggestionsList extends StatefulWidget {
  final List<String> suggestionQueries;
  final List<Map<String, dynamic>> suggestionItems;
  final bool isLoading;
  final ValueChanged<String> onQueryTap;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  const _SuggestionsList({
    required this.suggestionQueries, required this.suggestionItems,
    required this.isLoading, required this.onQueryTap, required this.onItemTap,
  });

  @override
  State<_SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
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
    return ListView(
      controller: _scrollController,
      children: [
      if (widget.isLoading) const Padding(padding: EdgeInsets.all(20), child: Center(child: LoadingIndicatorM3E())),
      ...widget.suggestionQueries.map((q) => AdaptiveListTile(
        onTap: () => widget.onQueryTap(q),
        leading: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.4)),
        title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14)),
      )),
      if (widget.suggestionItems.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Recommended', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        ...widget.suggestionItems.map((item) => AdaptiveListTile(
          onTap: () => widget.onItemTap(item),
          leading: (item['thumbnails'] != null && (item['thumbnails'] as List).isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(item['type'] == 'ARTIST' ? 20 : 4),
                  child: Image.network((item['thumbnails'] as List).first['url'], width: 40, height: 40, fit: BoxFit.cover),
                )
              : null,
          title: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: item['subtitle'] != null
              ? Text(item['subtitle'], maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))
              : null,
        )),
      ],
    ]);
  }
}

class _ShimmerLoading extends StatefulWidget {
  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _animation,
      builder: (context, child) => _ShimmerContent(animation: _animation),
    );
  }
}

class _ShimmerContent extends StatelessWidget {
  final Animation<double> animation;
  const _ShimmerContent({required this.animation});

  static const _widths = [
    [200.0, 140.0], [160.0, 100.0], [180.0, 120.0], [220.0, 80.0],
    [140.0, 160.0], [190.0, 130.0], [170.0, 110.0], [210.0, 90.0],
  ];

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white.withValues(alpha: 0.05);
    final shimmerColor = Colors.white.withValues(alpha: (animation.value + 1) * 0.04);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        final widths = _widths[index % _widths.length];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 12, width: widths[0], decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(height: 10, width: widths[1], decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4))),
            ])),
          ]),
        );
      },
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;
  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 16),
        Text('No results found', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('No results for "$query"', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14), textAlign: TextAlign.center),
      ]),
    ));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 16),
        Text('Something went wrong', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),
        AdaptiveButton(onPressed: onRetry, child: const Text('Try again')),
      ]),
    ));
  }
}

class _ResultsList extends StatefulWidget {
  final SearchState state;
  final ValueChanged<Map<String, dynamic>> onSongTap;
  final ValueChanged<Map<String, dynamic>> onAlbumTap;
  final ValueChanged<Map<String, dynamic>> onArtistTap;
  final ValueChanged<Map<String, dynamic>> onPlaylistTap;

  const _ResultsList({
    required this.state, required this.onSongTap, required this.onAlbumTap,
    required this.onArtistTap, required this.onPlaylistTap,
  });

  @override
  State<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends State<_ResultsList> {
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
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: _buildSections(),
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];
    switch (widget.state.selectedType) {
      case SearchType.all:
        _addSection(widgets, 'Artists', widget.state.artists, (item) => _ArtistResultTile(item: item, onTap: () => widget.onArtistTap(item)));
        _addSection(widgets, 'Songs', widget.state.songs, (item) => _SongResultTile(item: item, onTap: () => widget.onSongTap(item)));
        _addSection(widgets, 'Videos', widget.state.videos, (item) => _SongResultTile(item: item, onTap: () => widget.onSongTap(item)));
        _addSection(widgets, 'Albums', widget.state.albums, (item) => _AlbumResultTile(item: item, onTap: () => widget.onAlbumTap(item)));
        _addSection(widgets, 'Playlists', widget.state.playlists, (item) => _PlaylistResultTile(item: item, onTap: () => widget.onPlaylistTap(item)));
        break;
      case SearchType.songs:
        widgets.addAll(widget.state.songs.map((item) => _SongResultTile(item: item, onTap: () => widget.onSongTap(item))));
        break;
      case SearchType.albums:
        widgets.addAll(widget.state.albums.map((item) => _AlbumResultTile(item: item, onTap: () => widget.onAlbumTap(item))));
        break;
      case SearchType.artists:
        widgets.addAll(widget.state.artists.map((item) => _ArtistResultTile(item: item, onTap: () => widget.onArtistTap(item))));
        break;
      case SearchType.playlists:
        widgets.addAll(widget.state.playlists.map((item) => _PlaylistResultTile(item: item, onTap: () => widget.onPlaylistTap(item))));
        break;
      case SearchType.videos:
        widgets.addAll(widget.state.videos.map((item) => _SongResultTile(item: item, onTap: () => widget.onSongTap(item))));
        break;
    }
    return widgets;
  }

  void _addSection(List<Widget> widgets, String title, List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) tileBuilder) {
    if (items.isEmpty) return;
    widgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15, fontWeight: FontWeight.w600)),
    ));
    widgets.addAll(items.map(tileBuilder));
  }
}

class _SongResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _SongResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnails = item['thumbnails'] as List? ?? [];
    final url = thumbnails.isNotEmpty ? thumbnails.first['url'] as String? : null;
    final artists = (item['artists'] as List?)?.map((a) => a is Map ? (a['name'] ?? '') : '').join(' · ') ?? item['subtitle'] as String?;
    return AdaptiveListTile(
      onTap: onTap,
      leading: url != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover)) : null,
      title: Row(children: [
        if (item['explicit'] == true)
          Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.explicit, size: 16, color: Colors.grey.withValues(alpha: 0.7))),
        Expanded(child: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
      subtitle: artists != null ? Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)) : null,
      trailing: item['album'] != null ? Text((item['album'] as Map)['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)) : null,
    );
  }
}

class _AlbumResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _AlbumResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnails = item['thumbnails'] as List? ?? [];
    final url = thumbnails.isNotEmpty ? thumbnails.first['url'] as String? : null;
    final artists = (item['artists'] as List?)?.map((a) => a is Map ? (a['name'] ?? '') : '').join(' · ') ?? item['subtitle'] as String?;
    return AdaptiveListTile(
      onTap: onTap,
      leading: url != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover)) : null,
      title: Row(children: [
        if (item['explicit'] == true)
          Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.explicit, size: 16, color: Colors.grey.withValues(alpha: 0.7))),
        Expanded(child: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
      subtitle: artists != null ? Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)) : null,
    );
  }
}

class _ArtistResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ArtistResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnails = item['thumbnails'] as List? ?? [];
    final url = thumbnails.isNotEmpty ? thumbnails.first['url'] as String? : null;
    return AdaptiveListTile(
      onTap: onTap,
      leading: url != null ? ClipRRect(borderRadius: BorderRadius.circular(25), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover)) : null,
      title: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: item['category'] != null || item['subtitle'] != null
          ? Text(item['category'] as String? ?? item['subtitle'] as String? ?? '', maxLines: 1,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))
          : null,
      trailing: Icon(AdaptiveIcons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
    );
  }
}

class _PlaylistResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _PlaylistResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnails = item['thumbnails'] as List? ?? [];
    final url = thumbnails.isNotEmpty ? thumbnails.first['url'] as String? : null;
    final author = item['author'] as String? ?? item['subtitle'] as String?;
    return AdaptiveListTile(
      onTap: onTap,
      leading: url != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover)) : null,
      title: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Row(children: [
        if (author != null) Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        if (author != null && item['itemCount'] != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.circle, size: 3, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 4),
        ],
        if (item['itemCount'] != null) Text('${item['itemCount']} songs',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      ]),
      trailing: Icon(AdaptiveIcons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
    );
  }
}
