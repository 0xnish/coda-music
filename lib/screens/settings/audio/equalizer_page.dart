import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../../../generated/l10n.dart';
import '../../../services/equalizer_service.dart';
import '../../../services/settings_manager.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  late final EqualizerService _eqService;
  late final SettingsManager _settings;
  late final AnimatedScrollController _scrollController;
  late List<double> _gains;
  late bool _enabled;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
    _eqService = GetIt.I<EqualizerService>();
    _settings = GetIt.I<SettingsManager>();
    _gains = List<double>.from(_settings.equalizerBandsGain);
    _enabled = _settings.equalizerEnabled;

    if (_gains.length != EqualizerService.bandCount) {
      _gains = List<double>.filled(EqualizerService.bandCount, 0.0);
    }
    _selectedPreset = _findMatchingPreset();
  }

  String? _findMatchingPreset() {
    for (final entry in EqualizerService.presets.entries) {
      bool match = true;
      for (int i = 0; i < _gains.length; i++) {
        if ((_gains[i] - entry.value[i]).abs() > 0.01) {
          match = false;
          break;
        }
      }
      if (match) return entry.key;
    }
    return null;
  }

  Future<void> _onBandChanged(int index, double value) async {
    setState(() {
      _gains[index] = value;
      _selectedPreset = _findMatchingPreset();
    });
    await _eqService.updateBand(index, value);
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    await _eqService.toggle(value);
  }

  Future<void> _onPresetSelected(String presetName) async {
    final gains = EqualizerService.presets[presetName];
    if (gains == null) return;
    setState(() {
      _gains = List<double>.from(gains);
      _selectedPreset = presetName;
    });
    await _eqService.applyPreset(presetName);
  }

  Future<void> _onReset() async {
    setState(() {
      _gains = List<double>.filled(EqualizerService.bandCount, 0.0);
      _selectedPreset = 'Flat';
    });
    await _eqService.reset();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).Equalizer)),
        body: Center(
          child: Text(
            'Equalizer is only available on Windows',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).Equalizer),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              Card(
                child: SwitchListTile(
                  title: Text(
                    S.of(context).Enable_Equalizer,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.equalizer),
                  ),
                  value: _enabled,
                  onChanged: _onToggle,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presets',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: EqualizerService.presets.keys.map((name) {
                          final isSelected = _selectedPreset == name;
                          return ChoiceChip(
                            label: Text(
                              name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: _enabled
                                ? (_) => _onPresetSelected(name)
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bands',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(EqualizerService.bandCount, (i) {
                            return Expanded(
                              child: _BandSlider(
                                label: EqualizerService.bandLabels[i],
                                value: _gains[i],
                                min: EqualizerService.minGain,
                                max: EqualizerService.maxGain,
                                enabled: _enabled,
                                onChanged: (v) => _onBandChanged(i, v),
                              ),
                            );
                          }),
                        ),
                      ),
                      if (_selectedPreset != 'Flat') ...[
                        const SizedBox(height: 20),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _onReset,
                            child: const Text('Reset'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedValue = (value - min) / (max - min);
    final accentColor = theme.colorScheme.primary;

    return Column(
      children: [
        Text(
          value > 0 ? '+${value.toStringAsFixed(0)}' : value.toStringAsFixed(0),
          style: theme.textTheme.labelSmall?.copyWith(
            color: enabled
                ? accentColor.withValues(alpha: 0.3 + normalizedValue * 0.7)
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: enabled
                    ? accentColor.withValues(alpha: 0.3 + normalizedValue * 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                inactiveTrackColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.1),
                thumbColor: enabled
                    ? accentColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                overlayColor: accentColor.withValues(alpha: 0.1),
              ),
              child: Slider(
                min: min,
                max: max,
                value: value.clamp(min, max),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}