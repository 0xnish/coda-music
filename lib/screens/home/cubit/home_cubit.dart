import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:Coda/ytmusic/ytmusic.dart';
import 'package:Coda/services/home_fetchers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meta/meta.dart';
part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final YTMusic _ytMusic;
  HomeCubit(this._ytMusic) : super(HomeLoading());

  Map<String, dynamic> _params() {
    final box = Hive.box('SONG_HISTORY');
    final historySongs = box.values
        .where((s) => s is Map && s['videoId'] != null)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    return {
      'headers': _ytMusic.headers,
      'context': _ytMusic.context,
      'visitorData': _ytMusic.config?.visitorData ?? '',
      'historySongs': historySongs,
    };
  }

  HomeSuccess _assembleHomeData(Map<String, dynamic> result) {
    final feed = result['feed'] as Map<String, dynamic>;
    final ytSections =
        List<Map<String, dynamic>>.from(feed['sections'] ?? []);
    final chips = feed['chips'] ?? [];
    final recommendations =
        result['recommendations'] as List<Map<String, dynamic>>;
    final moodAndGenresResult =
        result['moodAndGenres'] as List<Map<String, dynamic>>;
    final trending = result['trending'] as List<Map<String, dynamic>>;

    List<Map<String, dynamic>> sections = [];

    if (trending.isNotEmpty) {
      sections.add(_createTrendingSection(trending));
    }

    final quickPicksIdx = ytSections.indexWhere(
      (s) => s['title'] is String &&
          (s['title'] as String).toLowerCase().contains('quick'),
    );
    if (quickPicksIdx >= 0) {
      sections.add(ytSections.removeAt(quickPicksIdx));
    }

    final dailyDiscover = _createDailyDiscoverSection(recommendations);
    if (dailyDiscover != null) sections.add(dailyDiscover);

    final moodAndGenres =
        _createMoodAndGenresSection(moodAndGenresResult);
    if (moodAndGenres != null) sections.add(moodAndGenres);

    sections.add(_createChartsPreviewSection());
    sections.addAll(ytSections);

    return HomeSuccess(
      chips: chips,
      sections: sections,
      continuation: feed['continuation'],
      loadingMore: false,
    );
  }

  Future<void> fetch() async {
    emit(const HomeLoading());
    try {
      final result = await compute(fetchHomeData, _params());
      emit(_assembleHomeData(result));
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Map<String, dynamic>? _createDailyDiscoverSection(
      List<Map<String, dynamic>> recommendations) {
    if (recommendations.isEmpty) return null;
    return {
      'customType': 'daily_discover',
      'title': 'Daily Discover',
      'contents': recommendations.take(30).toList(),
    };
  }

  Map<String, dynamic>? _createMoodAndGenresSection(List items) {
    if (items.isEmpty) return null;
    final moodItems = items.where((item) {
      final title = (item['title'] as String?)?.toLowerCase() ?? '';
      return title.isNotEmpty && title != 'all';
    }).toList();
    if (moodItems.isEmpty) return null;
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < moodItems.length; i++) {
      result.add({
        'title': moodItems[i]['title'],
        'endpoint': moodItems[i]['endpoint'],
      });
    }
    return {
      'customType': 'mood_and_genres',
      'title': 'Mood & Genres',
      'contents': result,
    };
  }

  Map<String, dynamic> _createTrendingSection(List songs) {
    return {
      'customType': 'trending',
      'title': 'Trending',
      'contents': songs,
    };
  }

  Map<String, dynamic> _createChartsPreviewSection() {
    return {
      'customType': 'charts_preview',
      'title': 'Browse Charts',
      'contents': <Map<String, dynamic>>[],
    };
  }

  Future<void> refresh() async {
    try {
      final result = await compute(fetchHomeData, _params());
      emit(_assembleHomeData(result));
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Future<void> fetchNext() async {
    final current = state;
    if (current is! HomeSuccess) return;
    if (current.loadingMore || current.continuation == null) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final feed = await _ytMusic.browseContinuation(
          additionalParams: current.continuation!);
      emit(
        HomeSuccess(
          chips: current.chips,
          sections: [...current.sections, ...feed['sections']],
          continuation: feed['continuation'],
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }
}
