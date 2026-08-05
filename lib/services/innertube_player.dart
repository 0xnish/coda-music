import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

class InnertubeClientConfig {
  final String clientName;
  final String clientVersion;
  final int clientId;
  final String userAgent;
  final Map<String, String>? osInfo;
  final Map<String, String>? deviceInfo;
  final bool includeUserAgentInContext;

  const InnertubeClientConfig({
    required this.clientName,
    required this.clientVersion,
    required this.clientId,
    required this.userAgent,
    this.osInfo,
    this.deviceInfo,
    this.includeUserAgentInContext = false,
  });

  Map<String, dynamic> toContext({
    required String hl,
    required String gl,
    String? visitorData,
  }) {
    final clientMap = <String, dynamic>{
      'clientName': clientName,
      'clientVersion': clientVersion,
      'hl': hl,
      'gl': gl,
      if (visitorData != null) 'visitorData': visitorData,
      if (includeUserAgentInContext) 'userAgent': userAgent,
    };
    if (osInfo != null) clientMap.addAll(osInfo!);
    if (deviceInfo != null) clientMap.addAll(deviceInfo!);
    return {
      'context': {
        'client': clientMap,
      }
    };
  }
}

class InnertubeStreamInfo {
  final Uri url;
  final int totalBytes;
  final String mimeType;
  final int bitrate;
  final String quality;
  final String clientName;

  const InnertubeStreamInfo({
    required this.url,
    required this.totalBytes,
    required this.mimeType,
    required this.bitrate,
    required this.quality,
    required this.clientName,
  });
}

class InnertubePlayer {
  InnertubePlayer._();
  static final InnertubePlayer instance = InnertubePlayer._();

  static const String _apiUrl =
      'https://music.youtube.com/youtubei/v1/player?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&prettyPrint=false';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';

  static const String _userAgentVR =
      'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

  static const String _userAgentTV =
      'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/25.lts.30.1034943-gold (unlike Gecko), Unknown_TV_Unknown_0/Unknown (Unknown, Unknown)';

  static const String _userAgentVisionOS =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';

  static final List<InnertubeClientConfig> _clientOrder = [
    const InnertubeClientConfig(
      clientName: 'ANDROID_VR',
      clientVersion: '1.65.10',
      clientId: 28,
      userAgent: _userAgentVR,
      osInfo: {'osName': 'Android', 'osVersion': '12L'},
      deviceInfo: {
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'androidSdkVersion': '32',
      },
      includeUserAgentInContext: true,
    ),
    const InnertubeClientConfig(
      clientName: 'VISIONOS',
      clientVersion: '0.1',
      clientId: 101,
      userAgent: _userAgentVisionOS,
      osInfo: {'osName': 'visionOS', 'osVersion': '1.3.21O771'},
      deviceInfo: {
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice14,1',
      },
    ),
    const InnertubeClientConfig(
      clientName: 'TVHTML5',
      clientVersion: '7.20260114.12.00',
      clientId: 7,
      userAgent: _userAgentTV,
      includeUserAgentInContext: true,
    ),
    const InnertubeClientConfig(
      clientName: 'WEB_REMIX',
      clientVersion: '1.20260114.03.00',
      clientId: 67,
      userAgent: _userAgent,
    ),
    const InnertubeClientConfig(
      clientName: 'IOS',
      clientVersion: '21.03.1',
      clientId: 5,
      userAgent:
          'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
      osInfo: {'osVersion': '18.2.22C152'},
    ),
  ];

  final Map<String, InnertubeStreamInfo> _cache = {};

  String? _visitorData;

  String get _hl =>
      Hive.box('SETTINGS').get('LANGUAGE', defaultValue: 'en-IN');
  String get _gl => Hive.box('SETTINGS').get('LOCATION', defaultValue: 'IN');

  Future<void> _ensureVisitorData() async {
    if (_visitorData != null) return;
    try {
      final response = await http.get(
        Uri.parse('https://music.youtube.com'),
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
      final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
      final match = reg.firstMatch(response.body);
      if (match != null) {
        final ytcfg = json.decode(match.group(1).toString());
        _visitorData = ytcfg['VISITOR_DATA']?.toString();
      }
    } catch (_) {}
  }

  Future<InnertubeStreamInfo?> getStreamInfo(
    String videoId, {
    String quality = 'high',
  }) async {
    if (_cache.containsKey(videoId)) {
      return _cache[videoId];
    }

    await _ensureVisitorData();

    for (final client in _clientOrder) {
      try {
        final result = await _fetchWithClient(client, videoId, quality);
        if (result != null) {
          _cache[videoId] = result;
          return result;
        }
      } catch (e) {
        debugPrint(
            'Innertube: ${client.clientName} failed for $videoId: $e');
      }
    }

    return null;
  }

  Future<InnertubeStreamInfo?> _fetchWithClient(
    InnertubeClientConfig client,
    String videoId,
    String quality,
  ) async {
    final body = {
      ...client.toContext(hl: _hl, gl: _gl, visitorData: _visitorData),
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    };

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': client.clientId.toString(),
      'X-YouTube-Client-Version': client.clientVersion,
      'X-Origin': 'https://music.youtube.com',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
      if (_visitorData != null) 'X-Goog-Visitor-Id': _visitorData!,
    };

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: headers,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint(
          'Innertube: ${client.clientName} HTTP ${response.statusCode}');
      return null;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final status =
        (data['playabilityStatus'] as Map?)?['status']?.toString();
    if (status != 'OK') {
      debugPrint(
          'Innertube: ${client.clientName} status=$status');
      return null;
    }

    final streamingData = data['streamingData'] as Map?;
    if (streamingData == null) return null;

    final adaptiveFormats = streamingData['adaptiveFormats'] as List?;
    if (adaptiveFormats == null || adaptiveFormats.isEmpty) return null;

    final audioFormats = <Map<String, dynamic>>[];
    for (final format in adaptiveFormats) {
      if (format is! Map) continue;
      final mimeType = format['mimeType']?.toString() ?? '';
      if (!mimeType.startsWith('audio/')) continue;

      final url = format['url']?.toString();
      if (url != null && url.isNotEmpty) {
        audioFormats.add(Map<String, dynamic>.from(format));
        continue;
      }

      final signatureCipher = format['signatureCipher']?.toString();
      if (signatureCipher != null && signatureCipher.isNotEmpty) {
        final decoded = Uri.decodeQueryComponent(signatureCipher);
        final params = Uri.splitQueryString(decoded);
        final cipherUrl = params['url'];
        if (cipherUrl != null && cipherUrl.isNotEmpty) {
          final sc = Map<String, dynamic>.from(format);
          sc['_resolvedUrl'] = cipherUrl;
          audioFormats.add(sc);
        }
      }
    }

    if (audioFormats.isEmpty) {
      debugPrint(
          'Innertube: ${client.clientName} no playable audio formats');
      return null;
    }

    audioFormats.sort((a, b) =>
        (a['bitrate'] as int? ?? 0).compareTo(b['bitrate'] as int? ?? 0));

    final selected =
        quality == 'high' ? audioFormats.last : audioFormats.first;

    final urlStr = selected['_resolvedUrl']?.toString() ??
        selected['url']?.toString();
    if (urlStr == null || urlStr.isEmpty) return null;

    final mimeType = selected['mimeType']?.toString() ?? 'audio/webm';
    final bitrate = selected['bitrate'] as int? ?? 128000;
    final contentLength =
        int.tryParse(selected['contentLength']?.toString() ?? '') ?? 0;

    debugPrint(
        'Innertube: OK ${client.clientName} for $videoId '
        '(audio=$mimeType, bps=$bitrate, len=$contentLength)');

    return InnertubeStreamInfo(
      url: Uri.parse(urlStr),
      totalBytes: contentLength,
      mimeType: mimeType,
      bitrate: bitrate,
      quality: quality,
      clientName: client.clientName,
    );
  }

  void removeFromCache(String videoId) => _cache.remove(videoId);
  void clearCache() => _cache.clear();
}
