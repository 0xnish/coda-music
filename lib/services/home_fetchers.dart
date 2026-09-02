import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:Coda/ytmusic/helpers.dart' show nav, getContinuationString;
import 'package:Coda/ytmusic/mixins/browsing.dart'
    show handleChips, handleOuterContents, playlistIdTrimmer;
import 'package:Coda/ytmusic/mixins/search.dart' show getSearchParams;
import 'package:Coda/ytmusic/mixins/utils.dart';

const _ytmBase = 'https://music.youtube.com';
const _ytmApiPath = '/youtubei/v1/';
const _ytmKey = '?alt=json&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

Future<Map> _apiRequest(
  String endpoint,
  Map<String, dynamic> body,
  Map<String, String> headers,
  Map<String, dynamic> ctx, {
  String visitorData = '',
  String additionalParams = '',
}) async {
  try {
    body = {...body, ...ctx};
    final h = Map<String, String>.from(headers);
    if (visitorData.isNotEmpty) h['X-Goog-Visitor-Id'] = visitorData;
    final uri =
        Uri.parse('$_ytmBase$_ytmApiPath$endpoint$_ytmKey$additionalParams');
    final resp =
        await http.post(uri, headers: h, body: jsonEncode(body));
    if (resp.statusCode == 200) return json.decode(resp.body) as Map;
    return {};
  } catch (_) {
    return {};
  }
}

Future<Map<String, dynamic>> _browse(
  Map<String, String> headers,
  Map<String, dynamic> ctx, {
  String visitorData = '',
  Map<String, dynamic>? body,
  int limit = 2,
  String additionalParams = '',
}) async {
  if (additionalParams.isNotEmpty) {
    return _browseContinuation(headers, ctx,
        visitorData: visitorData,
        body: body,
        limit: limit,
        additionalParams: additionalParams);
  }
  body ??= {'browseId': 'FEmusic_home'};
  var response =
      await _apiRequest('browse', body, headers, ctx, visitorData: visitorData);

  Map<String, dynamic> result = {};
  Map<String, dynamic>? contents = response['contents'];
  Map<String, dynamic>? header = response['header'] ??
      nav(response, [
        'contents',
        'twoColumnBrowseResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
        0
      ]);

  if (header != null) {
    result['header'] = handlePageHeader(
      header['musicDetailHeaderRenderer'] ??
          header['musicImmersiveHeaderRenderer'] ??
          header['musicResponsiveHeaderRenderer'] ??
          header['musicVisualHeaderRenderer'] ??
          header['musicHeaderRenderer'] ??
          header['musicEditablePlaylistDetailHeaderRenderer']?['header']
              ?['musicResponsiveHeaderRenderer'] ??
          header['musicEditablePlaylistDetailHeaderRenderer']?['header'],
      editHeader: header['musicEditablePlaylistDetailHeaderRenderer']
          ?['editHeader']?['musicPlaylistEditHeaderRenderer'],
    );
  }

  if (contents != null) {
    Map? tabRenderer = nav(contents,
        ['singleColumnBrowseResultsRenderer', 'tabs', 0, 'tabRenderer']);
    Map? sectionListRenderer =
        nav(tabRenderer, ['content', 'sectionListRenderer']) ??
            nav(contents, [
              'twoColumnBrowseResultsRenderer',
              'secondaryContents',
              'sectionListRenderer'
            ]);
    List? chips =
        nav(sectionListRenderer, ['header', 'chipCloudRenderer', 'chips']);
    if (chips != null) result['chips'] = handleChips(chips);

    String? cont = nav(sectionListRenderer, [
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]) ??
        nav(sectionListRenderer, [
          'contents',
          0,
          'musicShelfRenderer',
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]);

    String? contParams;
    if (cont != null) {
      contParams = getContinuationString(cont);
      result['continuation'] = contParams;
    } else {
      result['continuation'] = null;
    }

    List finalContents = nav(sectionListRenderer, ['contents']);
    result['sections'] =
        handleOuterContents(finalContents, thumbnails: result['header']?['thumbnails']);
    (result['sections'] as List).removeWhere((el) => el['contents'].isEmpty);

    if (limit > 1 && contParams != null) {
      limit--;
      var data = await _browseContinuation(headers, ctx,
          visitorData: visitorData,
          body: body,
          limit: limit,
          additionalParams: contParams);
      if (data['sections'] != null) {
        if (data['addToLast'] == true) {
          result['sections']
              .last['contents']
              .addAll(data['sections'].first['contents']);
        } else {
          result['sections']
              .addAll(data['sections'].cast<Map<String, dynamic>>());
        }
      }
      result['continuation'] = data['continuation'];
    }
  } else {
    result['sections'] = List<Map<String, dynamic>>.empty();
  }
  return result;
}

Future<Map<String, dynamic>> _browseContinuation(
  Map<String, String> headers,
  Map<String, dynamic> ctx, {
  String visitorData = '',
  Map<String, dynamic>? body,
  int limit = 1,
  String additionalParams = '',
}) async {
  body ??= {'browseId': 'FEmusic_home'};
  var response = await _apiRequest('browse', body, headers, ctx,
      visitorData: visitorData, additionalParams: additionalParams);
  Map<String, dynamic> result = {'sections': []};

  List? contents = nav(response, [
        'continuationContents',
        'sectionListContinuation',
        'contents'
      ]) ??
      nav(response, [
        'continuationContents',
        'musicShelfContinuation',
        'contents'
      ]);

  if (contents == null) return {};

  if (nav(response, [
        'continuationContents',
        'musicShelfContinuation',
        'contents'
      ]) !=
      null) {
    result['sections'].add({'contents': handleContents(contents)});
    result['addToLast'] = true;
  } else {
    result['sections'] = handleOuterContents(contents);
  }

  String? continuations = nav(response, [
        'continuationContents',
        'sectionListContinuation',
        'continuations',
        0,
        'nextContinuationData',
        'continuation'
      ]) ??
      nav(response, [
        'continuationContents',
        'musicShelfContinuation',
        'continuations',
        0,
        'nextContinuationData',
        'continuation'
      ]);

  result['continuation'] =
      continuations != null ? getContinuationString(continuations) : null;

  if (limit > 1 && result['continuation'] != null) {
    limit--;
    var data = await _browse(headers, ctx,
        visitorData: visitorData,
        body: body,
        limit: limit,
        additionalParams: result['continuation']);
    if (data['sections'] != null) result['sections'].addAll(data['sections']);
    result['continuation'] = data['continuation'];
  }

  return result;
}

Future<List<Map<String, dynamic>>> _getMoodAndGenres(
  Map<String, String> headers,
  Map<String, dynamic> ctx, {
  String visitorData = '',
}) async {
  try {
    var response = await _apiRequest(
        'browse', {'browseId': 'FEmusic_moods_and_genres'}, headers, ctx,
        visitorData: visitorData);
    List<Map<String, dynamic>> results = [];
    var tabContent = nav(response, [
      'contents',
      'singleColumnBrowseResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'sectionListRenderer',
      'contents',
    ]);
    if (tabContent == null) return results;
    List sections = tabContent is List ? tabContent : [tabContent];
    for (var section in sections) {
      if (section is! Map) continue;
      Map? gridRenderer = section['gridRenderer'];
      if (gridRenderer == null) continue;
      String? title = nav(gridRenderer,
          ['header', 'gridHeaderRenderer', 'title', 'runs', 0, 'text']);
      List? items = gridRenderer['items'];
      if (items == null) continue;
      for (var item in items) {
        if (item is! Map) continue;
        Map? btn = item['musicNavigationButtonRenderer'];
        if (btn == null) continue;
        String? itemTitle = nav(btn, ['buttonText', 'runs', 0, 'text']);
        Map? endpoint = nav(btn, ['clickCommand', 'browseEndpoint']);
        if (itemTitle != null && endpoint != null) {
          results.add(
              {'title': itemTitle, 'endpoint': endpoint, 'section': title});
        }
      }
    }
    return results;
  } catch (_) {
    return [];
  }
}

Future<List> _getNextSongList(
  Map<String, String> headers,
  Map<String, dynamic> ctx, {
  String visitorData = '',
  String? videoId,
}) async {
  try {
    if (videoId == null) return [];
    Map<String, dynamic> body = Map.from(ctx);
    body['enablePersistentPlaylistPanel'] = true;
    body['isAudioOnly'] = true;
    body['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';
    body['videoId'] = videoId;
    String playlistId = 'RDAMVM$videoId';
    body['watchEndpointMusicSupportedConfigs'] = {
      'watchEndpointMusicConfig': {
        'hasPersistentPlaylistPanel': true,
        'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV;',
      }
    };
    body['playlistId'] = playlistIdTrimmer(playlistId);

    final Map response =
        await _apiRequest('next', body, headers, ctx, visitorData: visitorData);
    dynamic contents = nav(response, [
      'contents',
      'singleColumnMusicWatchNextResultsRenderer',
      'tabbedRenderer',
      'watchNextTabbedResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'musicQueueRenderer',
      'content',
      'playlistPanelRenderer',
      'contents'
    ]);
    return handleContents(contents);
  } catch (_) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> _fetchRecommendations(
  Map<String, String> headers,
  Map<String, dynamic> ctx,
  String visitorData,
  List<Map<String, dynamic>> historySongs,
) async {
  try {
    if (historySongs.isEmpty) return [];
    historySongs.sort((a, b) =>
        ((b['plays'] as int? ?? 0)).compareTo((a['plays'] as int? ?? 0)));
    final topSongs = historySongs.take(3).toList();

    final relatedResults = await Future.wait(
      topSongs.map((song) => _getNextSongList(headers, ctx,
          visitorData: visitorData, videoId: song['videoId'])),
    );

    final seen = <String>{};
    final recommendations = <Map<String, dynamic>>[];
    for (final result in relatedResults) {
      for (final song in result) {
        final id = song['videoId'] as String?;
        final title =
            (song['title'] as String? ?? '').toLowerCase().trim();
        final artist = ((song['artists'] as List?)?.firstOrNull is Map
                ? (song['artists'] as List).first['name'] as String?
                : null)
                ?.toLowerCase()
                .trim() ??
            '';
        final titleKey = '$title|$artist';
        if (id != null && seen.add(id) && seen.add(titleKey)) {
          recommendations.add(Map<String, dynamic>.from(song));
        }
        if (recommendations.length >= 20) break;
      }
      if (recommendations.length >= 20) break;
    }
    return recommendations;
  } catch (_) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> _fetchTrending(
  Map<String, String> headers,
  Map<String, dynamic> ctx,
  String visitorData,
) async {
  try {
    final result = await _browse(headers, ctx,
        visitorData: visitorData,
        body: {'browseId': 'FEmusic_charts'},
        limit: 1);
    final sections = result['sections'] as List?;
    final allSongs = <String, Map<String, dynamic>>{};
    if (sections != null && sections.isNotEmpty) {
      for (final section in sections) {
        final contents = section['contents'] as List?;
        if (contents != null && contents.isNotEmpty) {
          for (final s in contents) {
            final song = Map<String, dynamic>.from(s);
            final id = song['videoId'] as String?;
            if (id != null && !allSongs.containsKey(id)) {
              song['aspectRatio'] = 1.0;
              allSongs[id] = song;
            }
          }
        }
      }
    }
    if (allSongs.length < 20) {
      try {
        final data = Map.of(ctx);
        final params = getSearchParams('songs', null, ignoreSpelling: true);
        if (params != null) data['params'] = params;
        data['query'] = 'trending songs india';
        final response = await _apiRequest(
            'search', data, headers, ctx,
            visitorData: visitorData);
        if (response.isNotEmpty) {
          List contents = nav(response, [
                'contents',
                'tabbedSearchResultsRenderer',
                'tabs',
                0,
                'tabRenderer',
                'content',
                'sectionListRenderer',
                'contents'
              ]) ??
              [];
          for (Map content in contents) {
            Map? musicShelfRenderer = content['musicShelfRenderer'];
            Map? musicCardShelfRenderer = content['musicCardShelfRenderer'];
            List? sourceContents;
            if (musicShelfRenderer != null) {
              sourceContents = nav(musicShelfRenderer, ['contents']);
            } else if (musicCardShelfRenderer != null) {
              sourceContents = nav(musicCardShelfRenderer, ['contents']);
            }
            if (sourceContents != null) {
              for (final s in handleContents(sourceContents)) {
                final song = Map<String, dynamic>.from(s);
                final id = song['videoId'] as String?;
                if (id != null && !allSongs.containsKey(id)) {
                  song['aspectRatio'] = 1.0;
                  allSongs[id] = song;
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    return allSongs.values.toList();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>> fetchHomeData(
    Map<String, dynamic> params) async {
  final headers = Map<String, String>.from(params['headers'] as Map);
  final ctx = Map<String, dynamic>.from(params['context'] as Map);
  final visitorData = params['visitorData'] as String? ?? '';
  final historySongs = (params['historySongs'] as List)
      .map((s) => Map<String, dynamic>.from(s as Map))
      .toList();

  final results = await Future.wait([
    _browse(headers, ctx, visitorData: visitorData),
    _fetchRecommendations(headers, ctx, visitorData, historySongs),
    _getMoodAndGenres(headers, ctx, visitorData: visitorData),
    _fetchTrending(headers, ctx, visitorData),
  ]);

  return {
    'feed': results[0],
    'recommendations': results[1],
    'moodAndGenres': results[2],
    'trending': results[3],
    'charts': <Map<String, dynamic>>[],
  };
}
