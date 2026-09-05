import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/animated_coda_title.dart';
import '../../generated/l10n.dart';
import '../../services/bottom_message.dart';
import '../../services/media_player.dart';
import '../../services/settings_manager.dart';
import '../../services/update_service/update_service.dart';
import '../../services/window_service.dart';
import 'widgets/bottom_player.dart';
import 'widgets/square_mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('AppShell'));
  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int get _selectedIndex => widget.navigationShell.currentIndex;

  void _onNavTap(int index) {
    widget.navigationShell.goBranch(index, initialLocation: true);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final focusNode = FocusManager.instance.primaryFocus;
    final hasPrimaryFocus = focusNode?.hasPrimaryFocus ?? true;
    if (!hasPrimaryFocus) return false;

    final ctrl = HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.controlLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.controlRight);
    final shift = HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    final mediaPlayer = GetIt.I<MediaPlayer>();

    if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      mediaPlayer.next();
      return true;
    }

    if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      mediaPlayer.previous();
      return true;
    }

    if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final newVol = (mediaPlayer.player.volume + 0.1).clamp(0.0, 1.0);
      mediaPlayer.player.setVolume(newVol);
      return true;
    }

    if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final newVol = (mediaPlayer.player.volume - 0.1).clamp(0.0, 1.0);
      mediaPlayer.player.setVolume(newVol);
      return true;
    }

    if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyS) {
      mediaPlayer.setShuffleModeEnabled(!mediaPlayer.shuffleModeEnabled);
      return true;
    }

    if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyR) {
      mediaPlayer.changeLoopMode();
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _checkForUpdatesInBackground();
    GetIt.I<SettingsManager>().addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _checkForUpdatesInBackground() async {
    final update = await UpdateService.checkForUpdate();
    if (mounted) {
      GetIt.I<SettingsManager>().hasUpdate = update != null;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    GetIt.I<SettingsManager>().removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.toString();
    final isSearch = currentPath == '/search';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Row(
            children: [
              Container(
            width: 60,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                const Spacer(),
                _SidebarBtn(
                  icon: Icons.music_note_rounded,
                  label: 'Music',
                  selected: _selectedIndex == 0 && !isSearch,
                  onTap: () => _onNavTap(0),
                ),
                const SizedBox(height: 4),
                _SidebarBtn(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  selected: isSearch,
                  onTap: () => context.go('/search'),
                ),
                const SizedBox(height: 4),
                _SidebarBtn(
                  icon: Icons.library_music_rounded,
                  label: S.of(context).Saved,
                  selected: _selectedIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
                const SizedBox(height: 4),
                _SidebarBtn(
                  icon: Icons.settings_rounded,
                  label: S.of(context).Settings,
                  selected: _selectedIndex == 2,
                  onTap: () => _onNavTap(2),
                ),
                const SizedBox(height: 4),
                _SidebarBtn(
                  icon: Icons.favorite_rounded,
                  label: 'Support',
                  selected: _selectedIndex == 3,
                  onTap: () => _onNavTap(3),
                ),
                const Spacer(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) {
                            const MethodChannel('flutter/window')
                                .invokeMethod('startWindowDragging');
                          },
                          onDoubleTap: () => WindowService.maximize(),
                        ),
                      ),
                      Center(
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const AnimatedCodaTitle(),
                            const Spacer(),
                            if (GetIt.I<SettingsManager>().hasUpdate) ...[
                              _HeaderUpdateButton(
                                onTap: () =>
                                    UpdateService.downloadUpdate(),
                              ),
                              const SizedBox(width: 32),
                            ],
                            const _MacOSTrafficLights(),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DropTarget(
                    onDragDone: (details) async {
                      final audioExtensions = [
                        '.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac', '.wma',
                      ];
                      for (final file in details.files) {
                        final ext = file.path.toLowerCase();
                        if (audioExtensions.any((e) => ext.endsWith(e))) {
                          await GetIt.I<MediaPlayer>().addToQueue({
                            'videoId': null,
                            'title': file.name,
                            'path': file.path,
                          });
                          if (context.mounted) {
                            BottomMessage.showText(
                              context,
                              '${file.name} added to queue',
                            );
                          }
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        widget.navigationShell,
                        if (currentPath == '/')
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: BottomPlayer(),
                          )
                        else if (currentPath == '/support')
                          const SizedBox.shrink()
                        else
                          const Positioned(
                            bottom: 12,
                            right: 12,
                            child: SquareMiniPlayer(),
                          ),
],
                    ),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ValueListenableBuilder<Widget?>(
              valueListenable: UpdateService.modalHost,
              builder: (context, modal, child) {
                if (modal == null) return const SizedBox.shrink();
                return Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: const ColoredBox(
                            color: Color(0x66000000),
                          ),
                        ),
                      ),
                      Center(child: modal),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

}

class _SidebarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _HeaderUpdateButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HeaderUpdateButton({required this.onTap});

  @override
  State<_HeaderUpdateButton> createState() => _HeaderUpdateButtonState();
}

class _HeaderUpdateButtonState extends State<_HeaderUpdateButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const greenFg = Color(0xFF86EFAC);
    const pinkFg = Color(0xFFF9A8D4);
    final fg = _hovered ? pinkFg : greenFg;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: fg,
              width: 1.2,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
            child: const Text('UPDATE'),
          ),
        ),
      ),
    );
  }
}

class _MacOSTrafficLights extends StatefulWidget {
  const _MacOSTrafficLights();

  @override
  State<_MacOSTrafficLights> createState() => _MacOSTrafficLightsState();
}

class _MacOSTrafficLightsState extends State<_MacOSTrafficLights> {
  bool _closeHovered = false;
  bool _minHovered = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficDot(
          baseColor: const Color(0xFFFFBD2E),
          hoverColor: const Color(0xFFE0A325),
          icon: Icons.remove,
          hovered: _minHovered,
          onEnter: () => setState(() => _minHovered = true),
          onExit: () => setState(() => _minHovered = false),
          onTap: () => WindowService.minimize(),
        ),
        const SizedBox(width: 10),
        _TrafficDot(
          baseColor: const Color(0xFFFF5F57),
          hoverColor: const Color(0xFFE0443E),
          icon: Icons.close,
          hovered: _closeHovered,
          onEnter: () => setState(() => _closeHovered = true),
          onExit: () => setState(() => _closeHovered = false),
          onTap: () => WindowService.close(),
        ),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  final Color baseColor;
  final Color hoverColor;
  final IconData icon;
  final bool hovered;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;

  const _TrafficDot({
    required this.baseColor,
    required this.hoverColor,
    required this.icon,
    required this.hovered,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: hovered ? hoverColor : baseColor,
            shape: BoxShape.circle,
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 12,
              color: hovered ? Colors.black87 : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
