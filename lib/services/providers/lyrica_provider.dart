import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/lyrics_model.dart';

const String _baseUrl = 'https://test-0k.onrender.com';
const Duration _timeout = Duration(seconds: 40);

Future<Lyrics?> getLyricaLyrics({
  required String title,
  required String artist,
  bool timestamps = true,
}) async {
  try {
    final uri = Uri.parse('$_baseUrl/lyrics/').replace(queryParameters: {
      'artist': artist,
      'song': title,
      'timestamps': timestamps.toString(),
      'fast': 'true',
    });

    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'CodaMusic/1.0',
    }).timeout(_timeout);

    if (response.statusCode != 200) return null;

    final body = json.decode(utf8.decode(response.bodyBytes));
    if (body['status'] != 'success') {
      return null;
    }

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }

    final lyricsSynced = data['lyrics'] as String?;
    final lyricsPlain = data['lyrics'] as String? ?? '';

    final isLrc = lyricsSynced != null &&
        lyricsSynced.contains(RegExp(r'\[\d+:\d+[\.:]\d+\]'));
    final plain = isLrc ? '' : lyricsPlain;

    return Lyrics(
      artist: data['artist'] as String? ?? artist,
      title: data['title'] as String? ?? title,
      lyricsPlain: plain,
      lyricsSynced: isLrc ? lyricsSynced : null,
      id: '',
      provider: LyricsProvider.lyrica,
      album: data['album'] as String?,
      duration: data['duration']?.toString(),
    );
  } catch (e) {
    return null;
  }
}
