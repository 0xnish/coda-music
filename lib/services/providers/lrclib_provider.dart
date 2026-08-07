import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../models/lyrics_model.dart';

class _Track {
  final int id;
  final String trackName;
  final String artistName;
  final int durationSec;
  final String? plainLyrics;
  final String? syncedLyrics;
  double _score = 0.0;

  _Track.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        trackName = json['trackName'] as String? ?? '',
        artistName = json['artistName'] as String? ?? '',
        durationSec = ((json['duration'] as num?)?.toDouble() ?? 0).round(),
        plainLyrics = json['plainLyrics'] as String?,
        syncedLyrics = json['syncedLyrics'] as String?;
}

const String _baseUrl = 'https://lrclib.net/api';
const Duration _timeout = Duration(seconds: 6);

final List<RegExp> _titleCleanupPatterns = [
  RegExp(
      r'\s*\(.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\)',
      caseSensitive: false),
  RegExp(
      r'\s*\[.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\]',
      caseSensitive: false),
  RegExp(r'\s*【.*?】'),
  RegExp(r'\s*\|.*$'),
  RegExp(r'\s*-\s*(official|video|audio|lyrics|lyric|visualizer).*$',
      caseSensitive: false),
  RegExp(r'\s*\(feat\..*?\)', caseSensitive: false),
  RegExp(r'\s*\(ft\..*?\)', caseSensitive: false),
  RegExp(r'\s*feat\..*$', caseSensitive: false),
  RegExp(r'\s*ft\..*$', caseSensitive: false),
];

final List<String> _artistSeparators = [
  ' & ', ' and ', ', ', ' x ', ' X ',
  ' feat. ', ' feat ', ' ft. ', ' ft ',
  ' featuring ', ' with ',
];

String _cleanTitle(String title) {
  var cleaned = title.trim();
  for (final pattern in _titleCleanupPatterns) {
    cleaned = cleaned.replaceAll(pattern, '');
  }
  return cleaned.trim();
}

String _cleanArtist(String artist) {
  var cleaned = artist.trim();
  for (final sep in _artistSeparators) {
    final idx = cleaned.toLowerCase().indexOf(sep.toLowerCase());
    if (idx != -1) {
      cleaned = cleaned.substring(0, idx);
      break;
    }
  }
  return cleaned.trim();
}

double _stringSimilarity(String a, String b) {
  final s1 = a.trim().toLowerCase();
  final s2 = b.trim().toLowerCase();
  if (s1 == s2) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;
  if (s1.contains(s2) || s2.contains(s1)) return 0.8;
  final maxLen = max(s1.length, s2.length);
  return 1.0 - (_levenshtein(s1, s2) / maxLen);
}

int _levenshtein(String a, String b) {
  final la = a.length, lb = b.length;
  final matrix = List.generate(la + 1, (_) => List.filled(lb + 1, 0));
  for (var i = 0; i <= la; i++) matrix[i][0] = i;
  for (var j = 0; j <= lb; j++) matrix[0][j] = j;
  for (var i = 1; i <= la; i++) {
    for (var j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      matrix[i][j] = [
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost,
      ].reduce(min);
    }
  }
  return matrix[la][lb];
}

_Track? _bestMatchingRelaxed(List<_Track> tracks, int durationSec) {
  if (tracks.isEmpty) return null;
  if (durationSec <= 0) {
    return tracks.firstWhere((t) => t.syncedLyrics != null,
        orElse: () => tracks.first);
  }
  final sorted = List<_Track>.from(tracks)
    ..sort((a, b) =>
        (a.durationSec - durationSec).abs()
            .compareTo((b.durationSec - durationSec).abs()));
  final synced = sorted.where((t) => t.syncedLyrics != null).toList();
  if (synced.isNotEmpty && (synced.first.durationSec - durationSec).abs() <= 5) {
    return synced.first;
  }
  if ((sorted.first.durationSec - durationSec).abs() <= 5) return sorted.first;
  return null;
}

_Track? _findBestMatch(List<_Track> tracks, String trackName, String artistName) {
  if (tracks.isEmpty) return null;

  final hasArtist = artistName.isNotEmpty;

  for (final track in tracks) {
    final titleSim = _stringSimilarity(trackName, track.trackName);
    final artistSim = _stringSimilarity(artistName, track.artistName);
    track._score = (titleSim + artistSim) / 2.0;
    if (track.syncedLyrics != null) track._score += 0.1;
  }

  tracks.sort((a, b) => b._score.compareTo(a._score));
  final best = tracks.first;

  final titleSim = _stringSimilarity(trackName, best.trackName);
  final artistSim = _stringSimilarity(artistName, best.artistName);
  final finalScore = (titleSim + artistSim) / 2.0;

  if (finalScore > 0.6) return best;
  if (!hasArtist && finalScore > 0.35) return best;
  return null;
}

Future<List<_Track>> _queryWithParams({
  String? trackName,
  String? artistName,
  String? albumName,
  String? query,
}) async {
  try {
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      if (query != null) 'q': query,
      if (trackName != null && trackName.isNotEmpty) 'track_name': trackName,
      if (artistName != null && artistName.isNotEmpty) 'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    });
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'CodaMusic/1.0',
    }).timeout(_timeout);
    if (response.statusCode != 200) return [];
    final list = json.decode(utf8.decode(response.bodyBytes)) as List;
    return list
        .map((e) => _Track.fromJson(e as Map<String, dynamic>))
        .where((t) => t.syncedLyrics != null || t.plainLyrics != null)
        .toList();
  } catch (e) {
    return [];
  }
}

Future<List<_Track>> _queryLyrics({
  required String artist,
  required String title,
  String? album,
}) async {
  final cleanedTitle = _cleanTitle(title);
  final cleanedArtist = _cleanArtist(artist);

  final results = await Future.wait([
    _queryWithParams(
      trackName: cleanedTitle,
      artistName: cleanedArtist,
      albumName: album,
    ),
    _queryWithParams(trackName: cleanedTitle),
    _queryWithParams(query: '$cleanedArtist $cleanedTitle'),
    _queryWithParams(query: cleanedTitle),
    if (cleanedTitle != title.trim())
      _queryWithParams(
        trackName: title.trim(),
        artistName: artist.trim(),
      ),
  ]);

  final seen = <int>{};
  final merged = <_Track>[];
  for (final batch in results) {
    for (final track in batch) {
      if (seen.add(track.id)) merged.add(track);
    }
  }
  return merged;
}

Future<Lyrics?> getLrclibLyrics({
  required String title,
  required String artist,
  String? album,
  int? duration,
}) async {
  try {
    final tracks = await _queryLyrics(artist: artist, title: title, album: album);
    if (tracks.isEmpty) {
      return null;
    }

    final cleanedTitle = _cleanTitle(title);
    final cleanedArtist = _cleanArtist(artist);

    _Track? match;
    if (duration == null || duration <= 0) {
      match = _findBestMatch(tracks, cleanedTitle, cleanedArtist);
    } else {
      match = _bestMatchingRelaxed(tracks, duration);
      if (match == null) {
        match = _findBestMatch(tracks, cleanedTitle, cleanedArtist);
      }
    }

    if (match == null) {
      return null;
    }

    final lyricsText = match.syncedLyrics ?? match.plainLyrics;
    if (lyricsText == null || lyricsText.isEmpty) {
      return null;
    }

    return Lyrics(
      artist: match.artistName,
      title: match.trackName,
      lyricsPlain: match.syncedLyrics != null ? '' : lyricsText,
      lyricsSynced: match.syncedLyrics,
      id: match.id.toString(),
      provider: LyricsProvider.lrclib,
      album: album,
      duration: match.durationSec.toString(),
    );
  } catch (e) {
    return null;
  }
}
