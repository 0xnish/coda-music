import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BlockedSongs extends ChangeNotifier {
  static BlockedSongs? _instance;
  static BlockedSongs get instance => _instance ??= BlockedSongs._();

  final Box _box = Hive.box('BLOCKED_SONGS');
  late final Set<String> _ids;
  late bool _enabled;

  BlockedSongs._() {
    _ids = (_box.get('IDS', defaultValue: <String>[]) as List)
        .map((e) => e.toString())
        .toSet();
    _enabled = _box.get('ENABLED', defaultValue: true);
  }

  Set<String> get ids => Set.unmodifiable(_ids);

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _box.put('ENABLED', value);
    notifyListeners();
  }

  bool contains(String? videoId) {
    if (!_enabled || videoId == null || videoId.isEmpty) return false;
    return _ids.contains(videoId);
  }

  bool isBlocked(String? videoId) {
    if (videoId == null || videoId.isEmpty) return false;
    return _ids.contains(videoId);
  }

  Future<void> block(String videoId) async {
    if (videoId.isEmpty || _ids.contains(videoId)) return;
    _ids.add(videoId);
    await _box.put('IDS', _ids.toList());
    notifyListeners();
  }

  Future<void> blockAll(Iterable<String> videoIds) async {
    var changed = false;
    for (final id in videoIds) {
      if (id.isNotEmpty && _ids.add(id)) changed = true;
    }
    if (changed) {
      await _box.put('IDS', _ids.toList());
      notifyListeners();
    }
  }

  Future<void> unblock(String videoId) async {
    if (!_ids.remove(videoId)) return;
    await _box.put('IDS', _ids.toList());
    notifyListeners();
  }

  Future<void> clear() async {
    if (_ids.isEmpty) return;
    _ids.clear();
    await _box.put('IDS', <String>[]);
    notifyListeners();
  }
}
