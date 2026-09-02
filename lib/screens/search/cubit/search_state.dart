part of 'search_cubit.dart';

enum SearchUIState { initial, history, suggestions, loading, results, error }

enum SearchType { all, songs, albums, artists, playlists, videos }

class SearchState {
  final SearchUIState uiState;
  final String query;
  final SearchType selectedType;
  final List<String> searchHistory;
  final List<String> suggestionQueries;
  final List<Map<String, dynamic>> suggestionItems;
  final List<Map<String, dynamic>> songs;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> videos;
  final List<Map<String, dynamic>> summarySections;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final String? error;

  const SearchState({
    this.uiState = SearchUIState.initial,
    this.query = '',
    this.selectedType = SearchType.all,
    this.searchHistory = const [],
    this.suggestionQueries = const [],
    this.suggestionItems = const [],
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
    this.videos = const [],
    this.summarySections = const [],
    this.isLoading = false,
    this.isLoadingSuggestions = false,
    this.error,
  });

  bool get hasResults =>
      songs.isNotEmpty ||
      albums.isNotEmpty ||
      artists.isNotEmpty ||
      playlists.isNotEmpty ||
      videos.isNotEmpty ||
      summarySections.isNotEmpty;

  SearchState copyWith({
    SearchUIState? uiState,
    String? query,
    SearchType? selectedType,
    List<String>? searchHistory,
    List<String>? suggestionQueries,
    List<Map<String, dynamic>>? suggestionItems,
    List<Map<String, dynamic>>? songs,
    List<Map<String, dynamic>>? albums,
    List<Map<String, dynamic>>? artists,
    List<Map<String, dynamic>>? playlists,
    List<Map<String, dynamic>>? videos,
    List<Map<String, dynamic>>? summarySections,
    bool? isLoading,
    bool? isLoadingSuggestions,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      uiState: uiState ?? this.uiState,
      query: query ?? this.query,
      selectedType: selectedType ?? this.selectedType,
      searchHistory: searchHistory ?? this.searchHistory,
      suggestionQueries: suggestionQueries ?? this.suggestionQueries,
      suggestionItems: suggestionItems ?? this.suggestionItems,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      playlists: playlists ?? this.playlists,
      videos: videos ?? this.videos,
      summarySections: summarySections ?? this.summarySections,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
