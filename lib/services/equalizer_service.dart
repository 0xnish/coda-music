import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';

import 'media_player.dart';
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

  NativePlayer? _nativePlayer;
  Timer? _debounceTimer;
  bool _isApplyingEQ = false;
  String _lastAppliedAf = '';

  bool get isApplyingEQ => _isApplyingEQ;

  void _ensureNativePlayer() {
    if (_nativePlayer != null) return;

    try {
      final platform = JustAudioPlatform.instance;
      if (platform is JustAudioMediaKit) {
        final mkPlayer = platform.getFirstMediaKitPlayer();
        if (mkPlayer != null) {
          final mkp = mkPlayer.mediaKitPlayer;
          final nativeP = mkp.platform;
          if (nativeP is NativePlayer) {
            _nativePlayer = nativeP;
          }
        }
      }
    } catch (e) {
      debugPrint('Equalizer: failed to get NativePlayer: $e');
      _nativePlayer = null;
    }
  }

  void invalidateCache() {
    _lastAppliedAf = '';
    _invalidateNativePlayer();
  }

  void _invalidateNativePlayer() {
    _nativePlayer = null;
    _lastAppliedAf = '';
  }

  void applyEqualizerDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      applyEqualizer();
    });
  }

  Future<void> applyEqualizer() async {
    if (!Platform.isWindows) return;

    _isApplyingEQ = true;
    try {
      _ensureNativePlayer();
      if (_nativePlayer == null) return;

      final settings = GetIt.I<SettingsManager>();

      if (!settings.equalizerEnabled) {
        await _removeEqualizerFilter();
        return;
      }

      final gains = settings.equalizerBandsGain;
      if (gains.length != bandCount) return;

      await _applyFilterChain(gains);
    } finally {
      _isApplyingEQ = false;
    }
  }

  Future<void> _applyFilterChain(List<double> gains) async {
    final afValue = _buildAfValue(gains);
    if (afValue == _lastAppliedAf) return;
    _lastAppliedAf = afValue;

    debugPrint('Equalizer: setting af="$afValue"');
    try {
      await _nativePlayer!.setProperty('af', afValue);
    } catch (e) {
      debugPrint('Equalizer: setProperty failed, refreshing reference: $e');
      _invalidateNativePlayer();
      _ensureNativePlayer();
      if (_nativePlayer != null) {
        try {
          await _nativePlayer!.setProperty('af', afValue);
        } catch (e2) {
          debugPrint('Equalizer: retry failed: $e2');
        }
      }
    }
  }

  String _buildAfValue(List<double> gains) {
    final tempoScale = _tempoScale();

    final eqParts = <String>[];
    for (int i = 0; i < bandCount && i < gains.length; i++) {
      final freq = bandFrequencies[i];
      final gain = gains[i].clamp(minGain, maxGain);
      if (gain != 0) {
        eqParts.add(
          'equalizer=f=$freq:width_type=q:width=1:g=${gain.toStringAsFixed(2)}',
        );
      }
    }

    if (eqParts.isEmpty) {
      return 'scaletempo:scale=$tempoScale';
    }
    return 'lavfi=[${eqParts.join(',')}],scaletempo:scale=$tempoScale';
  }

  String _tempoScale() {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final rate = mediaPlayer.playbackSpeed;
    final pitch = mediaPlayer.pitch > 0 ? mediaPlayer.pitch : 1.0;
    return (rate / pitch).toStringAsFixed(8);
  }

  Future<void> _removeEqualizerFilter() async {
    final resetAf = 'scaletempo:scale=${_tempoScale()}';
    if (_lastAppliedAf == resetAf) return;
    _lastAppliedAf = resetAf;

    debugPrint('Equalizer: removing filter');
    try {
      await _nativePlayer!.setProperty('af', resetAf);
    } catch (e) {
      debugPrint('Equalizer: setProperty failed, refreshing reference: $e');
      _invalidateNativePlayer();
      _ensureNativePlayer();
      if (_nativePlayer != null) {
        try {
          await _nativePlayer!.setProperty('af', resetAf);
        } catch (e2) {
          debugPrint('Equalizer: retry failed: $e2');
        }
      }
    }
  }

  Future<void> updateBand(int index, double gain) async {
    final settings = GetIt.I<SettingsManager>();
    await settings.setEqualizerBandsGain(index, gain);
    applyEqualizerDebounced();
  }

  Future<void> toggle(bool enabled) async {
    final settings = GetIt.I<SettingsManager>();
    settings.equalizerEnabled = enabled;
    await applyEqualizer();
  }

  void onSongChanged() {
    _lastAppliedAf = '';
    applyEqualizer();
  }

  Future<void> applyPreset(String presetName) async {
    final gains = presets[presetName];
    if (gains == null) return;

    final settings = GetIt.I<SettingsManager>();
    settings.equalizerBandsGain = List<double>.from(gains);
    await applyEqualizer();
  }

  Future<void> reset() async {
    final settings = GetIt.I<SettingsManager>();
    settings.equalizerBandsGain = List<double>.filled(bandCount, 0.0);
    await applyEqualizer();
  }

}
