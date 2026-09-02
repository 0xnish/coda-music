import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_media_kit/mediakit_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';

import 'settings_manager.dart';

class EqualizerService {
  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  static const List<String> bandLabels = [
    '31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K',
  ];

  static const double minGain = -12.0;
  static const double maxGain = 12.0;
  static const int bandCount = 10;

  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'Treble Boost': [0, 0, 0, 0, 0, 0, 2, 4, 5, 6],
    'Vocal': [-2, -1, 0, 3, 5, 5, 3, 1, 0, -2],
    'Rock': [5, 4, 2, 0, -1, 0, 2, 3, 4, 5],
    'Pop': [-1, 2, 4, 5, 4, 0, -1, -1, 2, 3],
    'Jazz': [3, 2, 0, 2, -2, -2, 0, 2, 3, 4],
    'Dance': [5, 6, 4, 0, 0, -3, -4, -4, 0, 0],
    'Classical': [4, 3, 2, 1, -1, -1, 0, 2, 3, 4],
    'Bass Reducer': [-5, -3, -1, 0, 0, 0, 0, 0, 0, 0],
    'Electronic': [5, 4, 1, 0, -2, 2, 0, 1, 4, 5],
  };

  static const String _equalizerMarker = 'equalizer';

  MediaKitPlayer? _hookedPlayer;

  NativePlayer? _observedNative;

  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<double>? _pitchSubscription;

  String _appliedAf = '';

  bool _writeInProgress = false;
  bool _writeQueued = false;

  bool _forceQueued = false;

  Timer? _debounce;

  Player? _currentPlayer() {
    final platform = JustAudioPlatform.instance;
    if (platform is! JustAudioMediaKit) return null;
    return platform.getFirstMediaKitPlayer()?.mediaKitPlayer;
  }

  static NativePlayer? _nativePlayer(Player player) {
    final platform = player.platform;
    return platform is NativePlayer ? platform : null;
  }

  static SettingsManager _settings() => GetIt.I<SettingsManager>();

  static bool _hasActiveBands(List<double> gains) =>
      gains.any((g) => g.abs() >= 0.05);

  static double _scaleFor(Player player) {
    try {
      final pitch = player.state.pitch;
      final rate = player.state.rate;
      if (pitch <= 0.0) return 1.0;
      return rate / pitch;
    } catch (_) {
      return 1.0;
    }
  }

  static String buildAfChain(List<double> gains, {double scale = 1.0}) {
    final parts = <String>[];
    for (int i = 0; i < bandCount && i < gains.length; i++) {
      final gain = gains[i];
      if (gain.abs() < 0.05) continue;
      final clamped = gain.clamp(minGain, maxGain);
      parts.add(
        'equalizer=f=${bandFrequencies[i]}:t=q:w=1:g=${clamped.toStringAsFixed(2)}',
      );
    }
    final scaletempo = 'scaletempo:scale=${scale.toStringAsFixed(8)}';
    return parts.isEmpty ? scaletempo : '${parts.join(',')},$scaletempo';
  }

  void _refreshHook() {
    final platform = JustAudioPlatform.instance;
    if (platform is! JustAudioMediaKit) return;
    final mkPlayer = platform.getFirstMediaKitPlayer();
    if (mkPlayer == null || identical(mkPlayer, _hookedPlayer)) return;

    final native = _nativePlayer(mkPlayer.mediaKitPlayer);
    if (native == null) return;

    final oldNative = _observedNative;
    _observedNative = native;
    _rateSubscription?.cancel();
    _pitchSubscription?.cancel();
    _rateSubscription = null;
    _pitchSubscription = null;
    if (oldNative != null) {
      unawaited(_unobserve(oldNative));
    }

    _appliedAf = '';
    _hookedPlayer = mkPlayer;

    final player = mkPlayer.mediaKitPlayer;
    _rateSubscription = player.stream.rate.listen((_) => _scheduleWrite());
    _pitchSubscription = player.stream.pitch.listen((_) => _scheduleWrite());
    unawaited(_observeAf(native));
  }

  Future<void> _observeAf(NativePlayer native) async {
    try {
      await native.observeProperty('af', (value) async {
        final settings = _settings();
        if (!settings.equalizerEnabled) {
          if (value.contains(_equalizerMarker)) {
            return _scheduleWrite(force: true);
          }
          return;
        }
        final wantEqualizer = settings.equalizerEnabled &&
            _hasActiveBands(settings.equalizerBandsGain);
        final hasEqualizer = value.contains(_equalizerMarker);
        if (wantEqualizer != hasEqualizer) {
          return _scheduleWrite(force: true);
        }
      });
    } catch (_) {
    }
  }

  Future<void> _unobserve(NativePlayer native) async {
    try {
      await native.unobserveProperty('af');
    } catch (_) {
    }
  }

  Future<void> _scheduleWrite({bool force = false}) async {
    if (force) _forceQueued = true;
    _writeQueued = true;
    if (_writeInProgress) return;
    _writeInProgress = true;
    try {
      while (_writeQueued) {
        _writeQueued = false;
        final bang = _forceQueued;
        _forceQueued = false;
        await _writeOnce(force: bang);
      }
    } finally {
      _writeInProgress = false;
    }
  }

  Future<void> _writeOnce({bool force = false}) async {
    _refreshHook();
    final Player? player = _currentPlayer();
    if (player == null) return;
    final native = _nativePlayer(player);
    if (native == null) return;

    final settings = _settings();
    final gains = settings.equalizerBandsGain;
    final scale = _scaleFor(player);
    final desired = settings.equalizerEnabled
        ? buildAfChain(gains, scale: scale)
        : buildAfChain(const [], scale: scale);

    if (!force && desired == _appliedAf) return;

    try {
      await native.setProperty('af', desired);
      _appliedAf = desired;
      await _verify(native, desired);
    } catch (e) {
      _appliedAf = '';
      _hookedPlayer = null;
    }
  }

  Future<void> _verify(NativePlayer native, String desired) async {
    try {
      await native.getProperty('af');
    } catch (_) {
    }
  }

  Future<void> applyEqualizer({bool force = false}) async {
    if (!Platform.isWindows) return;
    await _scheduleWrite(force: force);
  }

  void applyEqualizerDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _scheduleWrite);
  }

  Future<void> updateBand(int index, double gain) async {
    if (index < 0 || index >= bandCount) return;
    final settings = _settings();
    await settings.setEqualizerBandsGain(index, gain.clamp(minGain, maxGain));
    applyEqualizerDebounced();
  }

  Future<void> toggle(bool enabled) async {
    _settings().equalizerEnabled = enabled;
    await applyEqualizer(force: true);
  }

  Future<void> applyPreset(String presetName) async {
    final gains = presets[presetName];
    if (gains == null) return;
    _settings().equalizerBandsGain = List<double>.from(gains);
    await applyEqualizer(force: true);
  }

  Future<void> reset() async {
    _settings().equalizerBandsGain =
        List<double>.filled(bandCount, 0.0);
    await applyEqualizer(force: true);
  }

  void dispose() {
    _debounce?.cancel();
    _rateSubscription?.cancel();
    _pitchSubscription?.cancel();
    _rateSubscription = null;
    _pitchSubscription = null;
    final native = _observedNative;
    _observedNative = null;
    if (native != null) {
      unawaited(_unobserve(native));
    }
    _hookedPlayer = null;
  }
}
