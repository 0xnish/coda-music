import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'innertube_player.dart';

class RestrictedStreamException implements Exception {
  final String message;
  RestrictedStreamException(this.message);
  @override
  String toString() => message;
}

class _CachedStream {
  final Uri url;
  final int totalBytes;
  final String mimeType;
  _CachedStream({required this.url, required this.totalBytes, required this.mimeType});
}

class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  final String quality;
  _CachedStream? _cachedStream;

  YouTubeAudioSource({
    required this.videoId,
    required this.quality,
    super.tag,
  });

  Future<void> preload() async {
    await _getStreamInfo();
  }

  bool get hasPreloaded => _cachedStream != null;

  Future<_CachedStream> _getStreamInfo() async {
    if (_cachedStream != null) return _cachedStream!;

    int attempts = 0;
    const int maxAttempts = 3;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        final result = await InnertubePlayer.instance.getStreamInfo(
          videoId,
          quality: quality,
        );

        if (result != null) {
          _cachedStream = _CachedStream(
            url: result.url,
            totalBytes: result.totalBytes > 0 ? result.totalBytes : 10 * 1024 * 1024,
            mimeType: result.mimeType,
          );
          return _cachedStream!;
        }
      } on RestrictedStreamException {
        rethrow;
      } catch (e) {
        debugPrint('AudioSource: attempt $attempts failed for $videoId: $e');
      }
      if (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    throw Exception('Failed to get audio stream for $videoId after $maxAttempts attempts.');
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    const int maxAttempts = 3;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (attempt > 0) {
          _cachedStream = null;
        }

        final streamInfo = await _getStreamInfo();

        start ??= 0;
        if (streamInfo.totalBytes > 0) {
          end ??= streamInfo.totalBytes;
          if (end > streamInfo.totalBytes) {
            end = streamInfo.totalBytes;
          }
        } else {
          end ??= start + 10 * 1024 * 1024;
        }
        if (end <= start) {
          end = start + 1;
        }

        final stream = await _downloadStream(streamInfo.url, start, end - 1);
        return StreamAudioResponse(
          sourceLength: streamInfo.totalBytes,
          contentLength: end - start,
          offset: start,
          stream: stream,
          contentType: streamInfo.mimeType,
        );
      } on RestrictedStreamException {
        rethrow;
      } catch (e) {
        debugPrint('AudioSource: request attempt ${attempt + 1} failed: $e');
        if (attempt == maxAttempts - 1) {
          throw Exception('Failed to load audio after $maxAttempts attempts: $e');
        }
        _cachedStream = null;
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }
    throw Exception('Failed to load audio: max retries exceeded');
  }
}

Future<String> createAudioStreamServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  server.listen((HttpRequest request) {
    handleAudioRequest(request);
  });

  final host = server.address.host;
  final port = server.port;
  final url = 'http://$host:$port/audio';

  return url;
}

Future<void> handleAudioRequest(HttpRequest request) async {
  final response = request.response;

  if (request.uri.path != '/audio') {
    response.statusCode = HttpStatus.notFound;
    response.write('404 Not Found');
    await response.close();
    return;
  }

  final queryParams = request.uri.queryParameters;
  final videoId = queryParams['id'];
  final quality = queryParams['quality'] ?? 'high';

  if (videoId == null || videoId.isEmpty) {
    response.statusCode = HttpStatus.badRequest;
    response.write('Missing required query parameter: id');
    await response.close();
    return;
  }

  try {
    final result = await InnertubePlayer.instance.getStreamInfo(
      videoId,
      quality: quality,
    );

    if (result == null) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('No audio stream available for video $videoId.');
      await response.close();
      return;
    }

    final totalLength = result.totalBytes;

    (int start, int end)? parseRange(String rangeHeader, int totalLength) {
      if (!rangeHeader.startsWith('bytes=')) return null;
      final parts = rangeHeader.substring(6).split('-');
      if (parts.length != 2) return null;
      final start = int.tryParse(parts[0]) ?? 0;
      final end = parts[1].isEmpty ? totalLength - 1 : int.tryParse(parts[1]);
      if (end == null || end >= totalLength || start >= totalLength || start > end) return null;
      return (start, end);
    }

    int start = 0;
    int end = totalLength > 0 ? totalLength - 1 : 10 * 1024 * 1024;
    bool isPartial = false;

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && totalLength > 0) {
      final range = parseRange(rangeHeader, totalLength);
      if (range != null) {
        start = range.$1;
        end = range.$2;
        isPartial = true;
      }
    }

    final stream = await _downloadStream(result.url, start, end);

    response.statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.contentType = ContentType.parse(result.mimeType);
    if (isPartial && totalLength > 0) {
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalLength');
    }
    response.bufferOutput = false;

    try {
      await for (final chunk in stream) {
        response.add(chunk);
      }
    } catch (streamError) {
      debugPrint('Stream chunk read error: $streamError');
    }

    await response.close();
  } catch (e) {
    try {
      response.statusCode = HttpStatus.internalServerError;
      response.write('Error: $e');
      await response.close();
    } catch (_) {
      debugPrint('Failed to write error response: $_');
    }
  }
}

final Map<String, ({String url, DateTime expiry})> _urlCache = {};

Future<AudioSource> getDirectUrlAudioSource(
    String videoId, String quality, dynamic tag) async {
  if (_urlCache.containsKey(videoId)) {
    final cached = _urlCache[videoId]!;
    if (DateTime.now().isBefore(cached.expiry)) {
      return AudioSource.uri(Uri.parse(cached.url), tag: tag);
    } else {
      _urlCache.remove(videoId);
    }
  }

  final result = await InnertubePlayer.instance.getStreamInfo(
    videoId,
    quality: quality,
  );

  if (result == null) {
    throw Exception('No audio stream available for video $videoId.');
  }

  _urlCache[videoId] = (
    url: result.url.toString(),
    expiry: DateTime.now().add(const Duration(hours: 1))
  );

  return AudioSource.uri(result.url, tag: tag);
}

Future<Stream<List<int>>> _downloadStream(Uri url, int start, int end) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.add(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    request.headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0');
    request.headers.add('Origin', 'https://music.youtube.com');
    request.headers.add('Referer', 'https://music.youtube.com/');
    final response = await request.close();
    if (response.statusCode == HttpStatus.forbidden) {
      client.close(force: true);
      throw RestrictedStreamException(
          'YouTube restricted this stream (HTTP 403)');
    }
    return response;
  } catch (e) {
    client.close(force: true);
    rethrow;
  }
}
