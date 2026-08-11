import 'dart:async';

import 'package:media_kit/media_kit.dart';

const dir = 'C:/Users/NISHAN~1/AppData/Local/Temp/opencode/ordertest';

String ids(Playlist p) => p.medias.map((m) => m.uri.split('f')[1].split('.')[0]).join(',');

Future<void> reorderTo(Player player, List<int> targetIds, String label) async {
  final byId = {
    for (final m in player.state.playlist.medias)
      int.parse(m.uri.split('f')[1].split('.')[0]): m
  };
  final target = [for (final id in targetIds) byId[id]!];
  for (int pos = 0; pos < target.length; pos++) {
    final desired = target[pos];
    final cur = player.state.playlist.medias;
    if (pos >= cur.length) break;
    if (identical(cur[pos], desired)) continue;
    int j = -1;
    for (int k = pos; k < cur.length; k++) {
      if (identical(cur[k], desired)) {
        j = k;
        break;
      }
    }
    if (j == -1 || j == pos) continue;
    await player.move(j, pos);
    await Future.delayed(const Duration(milliseconds: 80));
    final after = ids(player.state.playlist);
    print('  move($j -> $pos) => [$after]');
  }
  await Future.delayed(const Duration(milliseconds: 100));
  print('$label => dart-seq=[${ids(player.state.playlist)}] mpv-pos=${player.state.playlist.index}');
}

Future<int> actualAt(Player player, int i) async {
  await player.jump(i);
  await Future.delayed(const Duration(milliseconds: 700));
  final first = player.state.duration.inMilliseconds;
  await player.jump(i);
  await Future.delayed(const Duration(milliseconds: 700));
  final second = player.state.duration.inMilliseconds;
  final ms = second == 0 ? first : second;
  return (ms / 1000).round().clamp(1, 5);
}

Future<String> verifyActualOrder(Player player, String label) async {
  final dartSeq = ids(player.state.playlist);
  print('--- verify actual mpv playback order after: $label ---');
  print('  (media_kit re-synced index=${player.state.playlist.index})');
  final actualIds = <int>[];
  for (int i = 0; i < 5; i++) {
    final id = await actualAt(player, i);
    actualIds.add(id);
    print('  jump($i): duration=${player.state.duration.inMilliseconds}ms -> f$id (dart-seq says ${dartSeq.split(',')[i]})');
  }
  final ok = actualIds.join(',') == dartSeq;
  print('${ok ? 'OK   ' : 'DRIFT'} actual=[${actualIds.join(',')}] vs dart-seq=[$dartSeq]');
  return ok ? 'OK' : 'DRIFT';
}

Future<String> playThrough(Player player, String label) async {
  final expected = ids(player.state.playlist);
  print('--- play-through verification for: $label ---');
  await player.jump(0);
  await player.pause();
  await Future.delayed(const Duration(milliseconds: 150));
  print('  settled at index=${player.state.playlist.index} duration=${player.state.duration.inMilliseconds}ms');
  final samples = <String>[];
  var last = player.state.playlist.index;
  if (last >= 0) {
    samples.add('$last:${player.state.duration.inMilliseconds}');
  }
  await player.play();
  for (int t = 0; t < 300; t++) {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = player.state.playlist.index;
    final dur = player.state.duration.inMilliseconds;
    if (idx != last) {
      samples.add('$idx:$dur');
      last = idx;
    }
  }
  await player.pause();
  final byIdx = <int, int>{};
  for (final s in samples) {
    final parts = s.split(':');
    final idx = int.parse(parts[0]);
    final dur = int.parse(parts[1]);
    if (dur > 0) byIdx.putIfAbsent(idx, () => dur);
  }
  final actual = [for (int i = 0; i < 5; i++) (byIdx[i] ?? -1) ~/ 1000];
  final ok = actual.join(',') == expected;
  print('  trajectory: ${samples.join(' | ')}');
  print('  first-duration per index: $byIdx');
  print('  mapped ids: [${actual.join(',')}] expected=[$expected] ${ok ? 'OK' : 'DRIFT'}');
  return ok ? 'OK' : 'DRIFT';
}

Future<void> main() async {
  MediaKit.ensureInitialized();

  final player = Player();
  await player.open(Playlist([
    for (int i = 1; i <= 5; i++) Media('file:///$dir/f$i.wav'),
  ]));
  await Future.delayed(const Duration(milliseconds: 500));
  print('initial => dart-seq=[${ids(player.state.playlist)}]');
  print('expected durations: f1=1s f2=2s f3=3s f4=4s f5=5s');

  await reorderTo(player, [1, 3, 5, 2, 4], 'shuffle-remainder [1,3,5,2,4]');
  final r1 = await playThrough(player, 'shuffle-remainder [1,3,5,2,4]');

  await reorderTo(player, [1, 2, 3, 4, 5], 'restore-original [1,2,3,4,5]');
  final r2 = await playThrough(player, 'restore-original [1,2,3,4,5]');

  await player.dispose();
  print(r1 == 'OK' && r2 == 'OK' ? 'RESULT: ALL SYNCED' : 'RESULT: DRIFT DETECTED');
}
