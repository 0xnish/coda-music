import 'dart:async';
import 'dart:collection';
import '../models/lyrics_model.dart';
import 'providers/lrclib_provider.dart';
import 'providers/lyrica_provider.dart';

class LyricsService {
  static const _maxCacheSize = 30;
  final _cache = LinkedHashMap<String, Lyrics>();

  static const _timeout = Duration(seconds: 15);

  Future<Lyrics> getLyrics({
    required String title,
    String? artist,
    String? album,
    String? duration,
    String? videoId,
  }) async {
    final key = videoId ?? '${title.toLowerCase()}|${(artist ?? '').toLowerCase()}';

    if (_cache.containsKey(key)) {
      final result = _cache[key]!;
      _cache.remove(key);
      _cache[key] = result;
      return result;
    }

    final result = await _fetchLyrics(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
    );

    _cache[key] = result;
    if (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    return result;
  }

  Future<Lyrics> _fetchLyrics({
    required String title,
    String? artist,
    String? album,
    String? duration,
  }) async {
    final useArtist = (artist != null && artist.isNotEmpty && artist != 'null') ? artist : '';
    final int? durationSec = duration != null && duration != 'null'
        ? int.tryParse(duration)
        : null;
    final useAlbum = (album != null && album.isNotEmpty && album != 'null') ? album : null;

    final results = await Future.wait([
      getLrclibLyrics(
        title: title,
        artist: useArtist,
        album: useAlbum,
        duration: durationSec,
      ),
      useArtist.isNotEmpty
          ? getLyricaLyrics(
              title: title,
              artist: useArtist,
              timestamps: true,
            )
          : Future<Lyrics?>.value(null),
    ]).timeout(_timeout);

    final lrclibResult = results[0];
    final lyricaResult = results[1];

    if (lrclibResult != null && lrclibResult.parsedLyrics != null) {
      return lrclibResult;
    }
    if (lyricaResult != null) {
      return lyricaResult;
    }
    if (lrclibResult != null) {
      return lrclibResult;
    }

    throw Exception('No lyrics found');
  }
}
