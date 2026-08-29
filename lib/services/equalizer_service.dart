import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_media_kit/mediakit_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';

import 'settings_manager.dart';

/// Applies a 10-band equalizer to coda's underlying media_kit (libmpv) player.
///
/// # How it works
///
/// mpv drives audio processing through its `af` (audio filter) property.
/// media_kit's pitch/speed feature also owns `af`: every time the rate or
/// pitch changes it rewrites:
///
///     af = scaletempo:scale=<rate / pitch>
///
/// so an equalizer can not just overwrite `af` with its own string — it must
/// *compose* with that same `scaletempo` term, otherwise the two features
/// erase each other. This service always rebuilds the full chain from the
/// player's *live* `state.rate` / `state.pitch`, so both stay in sync.
///
/// # Staying applied across songs & restarts
///
/// mpv reinitializes its audio filter chain whenever media_kit opens another
/// track (or a new player is created), silently dropping whatever `af` was
/// set. To survive that the service:
///
///  * **observes mpv's `af` property**. The observer fires on *every* change
///    (including our own writes), so it never blindly re-applies — it first
///    inspects the value mpv reports and only re-asserts the chain when the
///    equalizer is actually missing / present-but-disabled. This both heals
///    silent drops and avoids a self-triggering write loop.
///  * coda forces one re-assertion per freshly-loaded track via
///    [applyEqualizer] with `force: true` on the player's `ready` event.
///  * media_kit's rate/pitch streams are watched as a light-weight backstop.
///
/// # Filter syntax
///
/// `equalizer` is not a native mpv filter; mpv resolves unknown filter names
/// to FFmpeg's lavfi `equalizer`. Its parameters are `frequency`, `width_type`,
/// `width` and `gain` (aliases `f`, `t`, `w`, `g`), so omitting the width
/// (e.g. `equalizer=500:2`) produces an invalid lavfi graph that playback
/// silently rejects. Every band is written explicitly:
///
///     equalizer=f=<freq>:t=q:w=1:g=<gain>
///
/// `t=q:w=1` selects a Q-factor of 1.0, a sensible bandwidth for a 10-band
/// graphic equalizer.
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

  /// The `MediaKitPlayer` the eq is currently hooked to.
  MediaKitPlayer? _hookedPlayer;

  /// The native handle we observed `af` on (for cleanup on re-hook/dispose).
  NativePlayer? _observedNative;

  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<double>? _pitchSubscription;

  /// The `af` chain last confirmed written. Only meaningful for the player
  /// this service is currently hooked to — it is cleared whenever the hooked
  /// player changes so a fresh player never gets skipped by dedupe.
  String _appliedAf = '';

  /// Latest-wins write serialization: while a write is in flight we only
  /// remember that another one is wanted; the trailing pass applies the
  /// newest desired chain instead of queueing stale intermediate states.
  bool _writeInProgress = false;
  bool _writeQueued = false;

  /// Force the next write even if [desired] matches [_appliedAf]. Used on
  /// track-ready events because the target player may have been recreated
  /// (mpv state must not be assumed from our memory of a previous player).
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

  /// The `scaletempo:scale` term media_kit itself would write, derived from
  /// the player's live rate/pitch so pitch/speed keep working under the EQ.
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

  /// Builds the full `af` chain for the given band gains.
  ///
  /// Non-zero bands become explicit lavfi `equalizer` entries; the chain
  /// always ends with the `scaletempo` term that media_kit relies on for
  /// pitch/speed control.
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

  /// Hooks the current media_kit player so the EQ can never silently drop.
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

    // A different player has (possibly) arrived — anything we remembered
    // about the previous one is meaningless now.
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
          // Chain rebuilt by mpv while EQ is off — if stale eq filters are
          // somehow present, clean them up; otherwise do nothing.
          if (value.contains(_equalizerMarker)) {
            return _scheduleWrite(force: true);
          }
          return;
        }
        final wantEqualizer = settings.equalizerEnabled &&
            _hasActiveBands(settings.equalizerBandsGain);
        final hasEqualizer = value.contains(_equalizerMarker);
        if (wantEqualizer != hasEqualizer) {
          debugPrint(
            'Equalizer: mpv chain lost eq (want=$wantEqualizer, has=$hasEqualizer), re-asserting',
          );
          return _scheduleWrite(force: true);
        }
      });
    } catch (e) {
      debugPrint('Equalizer: could not observe af: $e');
    }
  }

  Future<void> _unobserve(NativePlayer native) async {
    try {
      await native.unobserveProperty('af');
    } catch (_) {
      // Not observed (anymore) — fine.
    }
  }

  /// Serializes `af` writes: only the newest desired state is ever written.
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

    // Skip only when we positively know this exact chain is in *this* player.
    if (!force && desired == _appliedAf) return;

    try {
      await native.setProperty('af', desired);
      _appliedAf = desired;
      await _verify(native, desired);
    } catch (e) {
      // The native player was recreated/torn down — drop the stale
      // reference so the next pass resolves a fresh one.
      debugPrint('Equalizer: could not apply "$desired": $e');
      _appliedAf = '';
      _hookedPlayer = null;
    }
  }

  /// Confirms mpv actually keeps the chain we wrote (diagnostic only —
  /// mpv's canonical representation is re-serialized differently).
  Future<void> _verify(NativePlayer native, String desired) async {
    try {
      final got = await native.getProperty('af');
      final settings = _settings();
      final wantEq =
          settings.equalizerEnabled && _hasActiveBands(settings.equalizerBandsGain);
      final hasEq = got.contains(_equalizerMarker);
      if (wantEq != hasEq) {
        debugPrint('Equalizer: verification mismatch (wantEq=$wantEq, got: $got)');
      }
    } catch (e) {
      debugPrint('Equalizer: verify failed: $e');
    }
  }

  /// Main entry point. [force] must be true for track-ready events so the
  /// chain is re-asserted even if we already "remember" applying it.
  Future<void> applyEqualizer({bool force = false}) async {
    if (!Platform.isWindows) return;
    await _scheduleWrite(force: force);
  }

  /// Debounced variant used while dragging sliders.
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