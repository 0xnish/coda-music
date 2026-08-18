import 'package:http/http.dart';

class SpotifyEmbedScraper {
  final String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  Future<Map<String, Object>> getPlaylistTracks(String playlistId) async {
    final url = Uri.parse(
        'https://open.spotify.com/embed/playlist/$playlistId');

    try {
      final response = await get(url, headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html',
      });

      if (response.statusCode != 200) {
        return {'tracks': <Map>[], 'playlistName': 'Imported Playlist'};
      }

      return _parseEmbedPage(response.body, isAlbum: false);
    } catch (_) {
      return {'tracks': <Map>[], 'playlistName': 'Imported Playlist'};
    }
  }

  Future<Map<String, Object>> getAlbumTracks(String albumId) async {
    final url = Uri.parse(
        'https://open.spotify.com/embed/album/$albumId');

    try {
      final response = await get(url, headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html',
      });

      if (response.statusCode != 200) {
        return {'tracks': <Map>[], 'albumName': 'Imported Album'};
      }

      return _parseEmbedPage(response.body, isAlbum: true);
    } catch (_) {
      return {'tracks': <Map>[], 'albumName': 'Imported Album'};
    }
  }

  Map<String, Object> _parseEmbedPage(String html, {required bool isAlbum}) {
    final List<Map<String, dynamic>> tracks = [];
    String playlistName = isAlbum ? 'Imported Album' : 'Imported Playlist';

    try {
      final namePattern = RegExp(r'"title"\s*:\s*"([^"]+)"');
      final nameMatches = namePattern.allMatches(html);
      if (nameMatches.isNotEmpty) {
        playlistName = nameMatches.first.group(1) ?? playlistName;
        if (playlistName.contains(' - Spotify')) {
          playlistName = playlistName.replaceAll(' - Spotify', '');
        }
      }
    } catch (_) {}

    try {
      final trackPattern = RegExp(
          r'"title"\s*:\s*"([^"]+)"\s*,\s*"subtitle"\s*:\s*"([^"]+)"');
      final matches = trackPattern.allMatches(html);

      for (final match in matches) {
        final title = match.group(1) ?? '';
        final artist = match.group(2) ?? '';

        if (title == playlistName || title.isEmpty) continue;

        tracks.add({
          'name': title,
          'artists': artist,
          'title': '$title $artist',
        });
      }
    } catch (_) {}

    return {
      'tracks': tracks,
      if (isAlbum) 'albumName': playlistName,
      if (!isAlbum) 'playlistName': playlistName,
    };
  }

  String? extractId(String url) {
    if (url.contains('/playlist/')) {
      final id = url.split('/playlist/')[1].split('?')[0].split('/')[0];
      return id;
    } else if (url.contains('/album/')) {
      final id = url.split('/album/')[1].split('?')[0].split('/')[0];
      return id;
    }
    return null;
  }

  bool isAlbumUrl(String url) => url.contains('/album/');
  bool isPlaylistUrl(String url) => url.contains('/playlist/');
  bool isSpotifyUrl(String url) => url.contains('spotify.com');
}
