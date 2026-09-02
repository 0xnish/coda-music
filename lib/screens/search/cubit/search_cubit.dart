import 'package:bloc/bloc.dart';
import 'package:Coda/ytmusic/helpers.dart';
import 'package:Coda/ytmusic/ytmusic.dart';
import 'package:hive/hive.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final YTMusic _ytmusic;

  SearchCubit(this._ytmusic) : super(const SearchState());

  void init(String query) {
    final history = searchHistory();
    if (query.isNotEmpty) {
      emit(state.copyWith(query: query, searchHistory: history));
      submitSearch(query);
    } else {
      emit(state.copyWith(
        searchHistory: history,
        uiState: history.isNotEmpty ? SearchUIState.history : SearchUIState.initial,
      ));
    }
  }

  void loadSearchHistory() {
    emit(state.copyWith(searchHistory: searchHistory()));
  }

  void updateQuery(String query) {
    emit(state.copyWith(query: query, clearError: true));
    if (query.isEmpty) {
      emit(state.copyWith(uiState: SearchUIState.history));
    } else {
      _fetchSuggestions(query);
    }
  }

  void onFocusChange(bool hasFocus) {
    if (hasFocus && state.query.isEmpty) {
      loadSearchHistory();
      emit(state.copyWith(uiState: SearchUIState.history));
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;
    emit(state.copyWith(
      isLoadingSuggestions: true,
      uiState: SearchUIState.suggestions,
    ));
    try {
      final suggestions = await _ytmusic.getSearchSuggestions(query);
      final queries = suggestions
          .where((s) => s['type'] == 'TEXT')
          .map((s) => s['query'] as String)
          .toList();
      final items = suggestions.where((s) => s['type'] != 'TEXT').toList();
      emit(state.copyWith(
        suggestionQueries: queries,
        suggestionItems: items,
        isLoadingSuggestions: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingSuggestions: false));
    }
  }

  void setSearchType(SearchType type) {
    emit(state.copyWith(selectedType: type));
    if (state.query.isNotEmpty) {
      if (type == SearchType.all) {
        searchAll(state.query);
      } else {
        searchByType(state.query, type);
      }
    }
  }

  void submitSearch(String query) {
    if (query.trim().isEmpty) return;
    _saveSearchHistory(query);
    if (state.selectedType == SearchType.all) {
      searchAll(query);
    } else {
      searchByType(query, state.selectedType);
    }
  }

  Future<void> searchAll(String query) async {
    emit(state.copyWith(
      uiState: SearchUIState.loading,
      query: query,
      isLoading: true,
      selectedType: SearchType.all,
    ));
    try {
      final result = await _ytmusic.search(query);
      emit(state.copyWith(
        uiState: SearchUIState.results,
        summarySections: _extractSections(result),
        songs: const [],
        albums: const [],
        artists: const [],
        playlists: const [],
        videos: const [],
        isLoading: false,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        uiState: SearchUIState.error,
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> searchByType(String query, SearchType type) async {
    emit(state.copyWith(
      uiState: SearchUIState.loading,
      query: query,
      isLoading: true,
      selectedType: type,
    ));
    try {
      final filter = _typeToFilter(type);
      final result = await _ytmusic.search(query, filter: filter);
      final items = _extractContents(result);
      emit(state.copyWith(
        uiState: SearchUIState.results,
        songs: type == SearchType.songs ? items : state.songs,
        albums: type == SearchType.albums ? items : state.albums,
        artists: type == SearchType.artists ? items : state.artists,
        playlists: type == SearchType.playlists ? items : state.playlists,
        videos: type == SearchType.videos ? items : state.videos,
        isLoading: false,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        uiState: SearchUIState.error,
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  void clearSearchHistory() {
    Hive.box('SEARCH_HISTORY').clear();
    emit(state.copyWith(searchHistory: [], uiState: SearchUIState.initial));
  }

  void _saveSearchHistory(String query) {
    if (Hive.box('SETTINGS').get('SEARCH_HISTORY', defaultValue: true)) {
      final box = Hive.box('SEARCH_HISTORY');
      final lower = query.toLowerCase();
      for (final key in box.keys.toList()) {
        if ((box.get(key) as String).toLowerCase() == lower) {
          box.delete(key);
        }
      }
      box.put(searchHistoryKey(query, DateTime.now()), query);
    }
  }

  List<Map<String, dynamic>> _extractContents(Map<String, dynamic> result) {
    final sections = result['sections'] as List? ?? [];
    return sections
        .expand((s) => (s['contents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<Map<String, dynamic>> _extractSections(Map<String, dynamic> result) {
    final raw = result['sections'] as List? ?? [];
    final titledSections = <Map<String, dynamic>>[];
    final flatItems = <Map<String, dynamic>>[];

    for (final s in raw) {
      final map = Map<String, dynamic>.from(s as Map);
      final title = map['title'] as String?;
      final contents = (map['contents'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final t = title?.trim();
      if (t != null && t.isNotEmpty) {
        titledSections.add({'title': t, 'contents': contents});
      } else {
        flatItems.addAll(contents);
      }
    }

    final sections = <Map<String, dynamic>>[...titledSections, ..._groupItemsByType(flatItems)];

    final merged = <String, List<Map<String, dynamic>>>{};
    for (final sec in sections) {
      final title = sec['title'] as String;
      final contents = (sec['contents'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      merged.putIfAbsent(title, () => []).addAll(contents);
    }

    final resultSections = <Map<String, dynamic>>[
      for (final e in merged.entries)
        {'title': e.key, 'contents': e.value},
    ]..sort((a, b) => _sectionOrder(a['title'] as String)
        .compareTo(_sectionOrder(b['title'] as String)));
    return resultSections;
  }

  List<Map<String, dynamic>> _groupItemsByType(List<Map<String, dynamic>> items) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final key = _sectionNameFor(item['type']);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final order = [
      'Songs', 'Videos', 'Albums', 'Artists', 'Playlists',
      'Podcasts', 'Episodes', 'Profiles', 'Other results',
    ];
    return order
        .where(grouped.containsKey)
        .map((name) => {'title': name, 'contents': grouped[name]!})
        .toList();
  }

  int _sectionOrder(String title) {
    const order = [
      'Top result', 'Songs', 'Videos', 'Albums', 'Artists', 'Playlists',
      'Podcasts', 'Episodes', 'Profiles', 'Other results',
    ];
    final index = order.indexOf(title);
    return index == -1 ? order.length : index;
  }

  String _sectionNameFor(dynamic type) {
    switch (type) {
      case 'SONG': return 'Songs';
      case 'VIDEO': return 'Videos';
      case 'ALBUM': return 'Albums';
      case 'ARTIST': return 'Artists';
      case 'PROFILE': return 'Profiles';
      case 'PLAYLIST': return 'Playlists';
      case 'PODCAST': return 'Podcasts';
      case 'EPISODE': return 'Episodes';
      default: return 'Other results';
    }
  }

  String? _typeToFilter(SearchType type) {
    switch (type) {
      case SearchType.songs: return 'songs';
      case SearchType.albums: return 'albums';
      case SearchType.artists: return 'artists';
      case SearchType.playlists: return 'playlists';
      case SearchType.videos: return 'videos';
      case SearchType.all: return null;
    }
  }
}
