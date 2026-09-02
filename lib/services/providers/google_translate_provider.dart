import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleTranslateTranslator {
  static const String baseUrl =
      'https://translate.googleapis.com/translate_a/single';

  static const Map<String, String> languages = <String, String>{
    'English': 'en',
    'Afrikaans': 'af',
    'Albanian': 'sq',
    'Amharic': 'am',
    'Arabic': 'ar',
    'Armenian': 'hy',
    'Azerbaijani': 'az',
    'Basque': 'eu',
    'Belarusian': 'be',
    'Bengali': 'bn',
    'Bosnian': 'bs',
    'Bulgarian': 'bg',
    'Burmese': 'my',
    'Catalan': 'ca',
    'Cebuano': 'ceb',
    'Chichewa': 'ny',
    'Chinese (Simplified)': 'zh-CN',
    'Chinese (Traditional)': 'zh-TW',
    'Corsican': 'co',
    'Croatian': 'hr',
    'Czech': 'cs',
    'Danish': 'da',
    'Dutch': 'nl',
    'Esperanto': 'eo',
    'Estonian': 'et',
    'Filipino': 'tl',
    'Finnish': 'fi',
    'French': 'fr',
    'Frisian': 'fy',
    'Galician': 'gl',
    'Georgian': 'ka',
    'German': 'de',
    'Greek': 'el',
    'Gujarati': 'gu',
    'Haitian Creole': 'ht',
    'Hausa': 'ha',
    'Hawaiian': 'haw',
    'Hebrew': 'he',
    'Hindi': 'hi',
    'Hmong': 'hmn',
    'Hungarian': 'hu',
    'Icelandic': 'is',
    'Igbo': 'ig',
    'Indonesian': 'id',
    'Irish': 'ga',
    'Italian': 'it',
    'Japanese': 'ja',
    'Javanese': 'jw',
    'Kannada': 'kn',
    'Kazakh': 'kk',
    'Khmer': 'km',
    'Korean': 'ko',
    'Kurdish': 'ku',
    'Kyrgyz': 'ky',
    'Lao': 'lo',
    'Latin': 'la',
    'Latvian': 'lv',
    'Lithuanian': 'lt',
    'Luxembourgish': 'lb',
    'Macedonian': 'mk',
    'Malagasy': 'mg',
    'Malay': 'ms',
    'Malayalam': 'ml',
    'Maltese': 'mt',
    'Maori': 'mi',
    'Marathi': 'mr',
    'Mongolian': 'mn',
    'Nepali': 'ne',
    'Norwegian': 'no',
    'Odia': 'or',
    'Pashto': 'ps',
    'Persian': 'fa',
    'Polish': 'pl',
    'Portuguese': 'pt',
    'Punjabi': 'pa',
    'Romanian': 'ro',
    'Russian': 'ru',
    'Samoan': 'sm',
    'Scots Gaelic': 'gd',
    'Serbian': 'sr',
    'Sesotho': 'st',
    'Shona': 'sn',
    'Sindhi': 'sd',
    'Sinhala': 'si',
    'Slovak': 'sk',
    'Slovenian': 'sl',
    'Somali': 'so',
    'Spanish': 'es',
    'Sundanese': 'su',
    'Swahili': 'sw',
    'Swedish': 'sv',
    'Tajik': 'tg',
    'Tamil': 'ta',
    'Telugu': 'te',
    'Thai': 'th',
    'Turkish': 'tr',
    'Ukrainian': 'uk',
    'Urdu': 'ur',
    'Uzbek': 'uz',
    'Vietnamese': 'vi',
    'Welsh': 'cy',
    'Xhosa': 'xh',
    'Yiddish': 'yi',
    'Yoruba': 'yo',
    'Zulu': 'zu',
  };

  final Map<String, String> _cache = {};
  static const int _maxCacheEntries = 300;

  String _cacheKey(String text, String languageCode) =>
      '$languageCode\u0000$text';

  void clearCache() => _cache.clear();

  Future<String> translate({
    required String text,
    required String language,
    bool preserveTimestamps = false,
  }) async {
    if (text.trim().isEmpty) return text;

    final languageCode = languages[language] ?? 'en';

    final key = _cacheKey(text, languageCode);
    final cached = _cache[key];
    if (cached != null) return cached;
    final result = await _translateRaw(text, languageCode);
    _cachePut(key, result);
    return result;
  }

  Future<List<String>> translateLines(
    List<String> lines, {
    required String language,
  }) async {
    if (lines.isEmpty) return lines;
    final languageCode = languages[language] ?? 'en';

    const maxConcurrent = 15;

    final resolved = List<String>.filled(lines.length, '');
    final pending = <int>[];

    for (var i = 0; i < lines.length; i++) {
      final content = lines[i].trim();
      if (content.isEmpty) {
        resolved[i] = content;
        continue;
      }
      final key = _cacheKey(content, languageCode);
      final cached = _cache[key];
      if (cached != null) {
        resolved[i] = cached;
      } else {
        pending.add(i);
      }
    }

    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= pending.length) return;
        final idx = pending[i];
        final content = lines[idx].trim();
        final key = _cacheKey(content, languageCode);
        var translated = await _translateRaw(content, languageCode);
        if (translated.trim().isEmpty) translated = content;
        _cachePut(key, translated);
        resolved[idx] = translated;
      }
    }

    final workers = <Future<void>>[
      for (var i = 0;
          i < (pending.length < maxConcurrent ? pending.length : maxConcurrent);
          i++)
        worker(),
    ];
    await Future.wait(workers);

    return resolved;
  }

  Future<String> _translateRaw(String text, String languageCode) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'client': 'gtx',
      'sl': 'auto',
      'tl': languageCode,
      'dt': 't',
      'q': text,
    });

    final resp = await http
        .get(uri, headers: const {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception(
          'Google Translate failed (${resp.statusCode}): ${resp.body}');
    }

    final data = json.decode(utf8.decode(resp.bodyBytes)) as List;
    final segments = data.isNotEmpty ? data.first as List : <dynamic>[];
    final buffer = StringBuffer();
    for (final segment in segments) {
      final piece = (segment as List).first?.toString() ?? '';
      buffer.write(piece);
    }
    return buffer.toString().trim();
  }

  void _cachePut(String key, String value) {
    if (_cache.length >= _maxCacheEntries && !_cache.containsKey(key)) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
    }
    _cache[key] = value;
  }
}
