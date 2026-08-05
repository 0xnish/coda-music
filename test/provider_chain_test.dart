import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Simulates exactly what the app does: LRCLIB direct GET with null duration
void main() {
  test('Simulate app: LRCLIB direct GET with null duration (should be skipped)', () async {
    // Simulating duration being null (common case on first load)
    final song = <String, dynamic>{
      'title': 'Dai Dai',
      'artist': 'Shakira,Burna Boy',
      'album': 'Dai Dai',
      // 'duration' absent — null like in app
    };
    String? title = song['title'] as String?;
    String? artist = song['artist'] as String?;
    String? album = song['album'] as String?;
    String? duration = song['duration'] as String?;

    if (artist != null && album != null && duration != null && duration != 'null') {
      final uri = Uri.https('lrclib.net', 'api/get', {
        'track_name': title!,
        'artist_name': artist,
        'album_name': album,
        'duration': duration,
      });
      print('Direct GET URL: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      print('Direct GET status: ${response.statusCode}');
    } else {
      print('Direct GET skipped: artist=$artist album=$album duration=$duration');
    }
  
    // Now do search (what the app falls back to)
    final searchQ = [title, artist, album].where((s) => s != null && s.isNotEmpty).join(' ');
    print('Search query: "$searchQ"');
    
    final searchUri = Uri.https('lrclib.net', 'api/search', {
      'q': searchQ,
      'track_name': title!,
      'artist_name': artist!,
    });
    print('Search URL: $searchUri');
    
    try {
      final response = await http.get(searchUri).timeout(const Duration(seconds: 30));
      print('Search status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('Search results: ${data.length}');
        if (data.isNotEmpty) {
          for (var i = 0; i < data.length && i < 3; i++) {
            print('  Result $i: ${data[i]['trackName']} - ${data[i]['artistName']}');
            print('    plainLyrics len: ${(data[i]['plainLyrics'] ?? '').length}');
            print('    syncedLyrics len: ${(data[i]['syncedLyrics'] ?? '').length}');
          }
        }
      } else {
        print('Search body: ${response.body}');
      }
    } catch (e) {
      print('Search error: $e');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
