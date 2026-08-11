import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:Coda/ytmusic/modals/yt_config.dart';
import 'package:Coda/ytmusic/ytmusic.dart';

Future<void> main() async {
  final dir = Directory.systemTemp.createTempSync('coda_sug_test');
  Hive.init(dir.path);
  await Hive.openBox('SEARCH_HISTORY');
  await Hive.openBox('SETTINGS');

  final yt = YTMusic(
    config: YTConfig(visitorData: '', language: 'en', location: 'IN'),
  );

  for (final q in ['taylor', 'blinding lights']) {
    print('=== getSearchSuggestions("$q") ===');
    try {
      final sw = Stopwatch()..start();
      final s = await yt.getSearchSuggestions(q);
      sw.stop();
      print('RESULT COUNT: ${s.length} (took ${sw.elapsedMilliseconds}ms)');
      for (final x in s) {
        print('  type=${x['type']} query=${x['query']} title=${x['title']} videoId=${x['videoId']}');
      }
    } catch (e, st) {
      print('THREW: $e');
      print(st);
    }
  }
  exit(0);
}
