import 'package:flutter/material.dart';

class PaletteCache {
  static final Map<String, List<Color>> _cache = {};

  static List<Color>? get(String key) {
    if (key.isEmpty) return null;
    return _cache[key];
  }

  static void put(String key, List<Color> colors) {
    if (key.isEmpty || colors.isEmpty) return;
    _cache[key] = List.of(colors);
  }
}
