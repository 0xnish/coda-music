import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for Mistral chat-completions API used to translate lyrics.
///
/// NOTE: The API key is embedded for now (desktop app). A client-side key is
/// not truly secret; treat it accordingly and prefer a per-user key later.
class MistralTranslator {
  static const String baseUrl = 'https://api.mistral.ai/v1/chat/completions';
  static const String defaultKey = '9AMUwZefYAyQUbOD3b8poPHH1pyboOGQ';
  // ministral-3b is the fastest model available on this account; use
  // ministral-8b-latest for better quality at a small speed cost.
  static const String defaultModel = 'ministral-3b-latest';

  final String apiKey;
  final String model;

  /// In-memory cache keyed by (text, language, preserveTimestamps, model)
  /// so repeated translations of the same song return instantly.
  final Map<String, String> _cache = {};

  MistralTranslator({String? apiKey, this.model = defaultModel})
      : apiKey = apiKey ?? defaultKey;

  /// Maximum number of entries to keep; evicts oldest on overflow.
  static const int _maxCacheEntries = 300;

  String _cacheKey(String text, String language, bool preserveTimestamps) =>
      '$model\u0000$language\u0000$preserveTimestamps\u0000$text';

  void _cachePut(String key, String value) {
    if (_cache.length >= _maxCacheEntries && !_cache.containsKey(key)) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
    }
    _cache[key] = value;
  }

  void clearCache() => _cache.clear();

  /// Translates [text] into [language], preserving the original line order.
  /// When [preserveTimestamps] is true, LRC `[mm:ss.xx]` prefixes are kept.
  Future<String> translate({
    required String text,
    required String language,
    bool preserveTimestamps = false,
  }) async {
    if (text.trim().isEmpty) return text;

    final key = _cacheKey(text, language, preserveTimestamps);
    final cached = _cache[key];
    if (cached != null) return cached;

    final instruction = preserveTimestamps
        ? 'Translate the following song lyrics into $language. '
            'Keep every line in the same order and keep the leading [mm:ss.xx] '
            'timestamps exactly as they are. Output only the translated lyrics, '
            'line for line, with no extra commentary.'
        : 'Translate the following song lyrics into $language. '
            'Keep every line in the same order. Output only the translated '
            'lyrics, line for line, with no extra commentary.';

    final payload = {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a professional song lyric translator.\n$instruction'
        },
        {'role': 'user', 'content': text},
      ],
      'temperature': 0.3,
    };

    final resp = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      throw Exception('Mistral translation failed (${resp.statusCode}): ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Mistral returned no choices');
    }
    final content = (choices.first as Map)['message']?['content']?.toString() ?? '';
    final result = content.trim();
    _cachePut(key, result);
    return result;
  }

  /// Translates synced (LRC) lyrics line-by-line while preserving timestamps.
  Future<String> translateSyncedLyrics({
    required String syncedLyrics,
    required String language,
  }) {
    return translate(
      text: syncedLyrics,
      language: language,
      preserveTimestamps: true,
    );
  }
}
