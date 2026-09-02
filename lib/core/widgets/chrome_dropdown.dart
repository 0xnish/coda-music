import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scroll_animator/scroll_animator.dart';

class ChromeDropdownItem<T> {
  const ChromeDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

class ChromeDropdown<T> extends StatefulWidget {
  const ChromeDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Select',
    this.width = 200,
    this.height = 40,
    this.itemHeight = 34,
    this.menuMaxHeight = 280,
    this.enableSearch = false,
    this.loading = false,
    this.selectionIcon,
    this.textStyle,
  });

  final T? value;
  final List<ChromeDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  final String hint;

  final double width;
  final double height;

  final double itemHeight;

  final double menuMaxHeight;

  final bool enableSearch;

  final bool loading;

  final IconData? selectionIcon;

  final TextStyle? textStyle;

  @override
  State<ChromeDropdown<T>> createState() => _ChromeDropdownState<T>();
}

class _ChromeDropdownState<T> extends State<ChromeDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _buttonKey = GlobalKey();
  bool _menuOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _selectedLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return widget.hint;
  }

  Future<void> _openMenu() async {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _menuOpen = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: widget.hint,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) {
        final overlayRender =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        final rect = box.localToGlobal(Offset.zero, ancestor: overlayRender);
        final searchFieldHeight = widget.enableSearch ? 54.0 : 0.0;
        final itemAreaHeight = math.min(
          widget.items.length * widget.itemHeight,
          widget.menuMaxHeight,
        );
        final menuHeight = searchFieldHeight + 8 + itemAreaHeight;
        return LayoutBuilder(
          builder: (context, constraints) {
            final below = rect.dy + widget.height + 8;
            final top = below + menuHeight > constraints.maxHeight
                ? math.max(8.0, rect.dy - menuHeight - 8)
                : below;
            return Stack(
              children: [
                Positioned(
                  left: rect.dx,
                  top: top,
                  child: _ChromeDropdownMenu<T>(
                    items: widget.items,
                    value: widget.value,
                    onSelected: widget.onChanged,
                    enableSearch: widget.enableSearch,
                    searchController: _searchController,
                    width: widget.width,
                    itemHeight: widget.itemHeight,
                    maxHeight: widget.menuMaxHeight,
                    selectionIcon: widget.selectionIcon,
                    textStyle: widget.textStyle,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) {
      _searchController.clear();
      setState(() => _menuOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = widget.textStyle ?? const TextStyle(fontSize: 14);
    final hasValue = widget.value != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: _buttonKey,
        onTap: _openMenu,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.onSurface.withValues(alpha: _menuOpen ? 0.35 : 0.18),
            ),
            color: cs.onSurface.withValues(alpha: _menuOpen ? 0.14 : 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selectionIcon != null) ...[
                SizedBox(
                  width: 18,
                  height: 16,
                  child: Icon(
                    widget.selectionIcon!,
                    size: 16,
                    color: hasValue
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle.copyWith(
                    color: hasValue
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 22,
                height: 22,
                child: widget.loading
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LoadingIndicatorM3E(color: cs.onSurface),
                      )
                    : Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurface
                            .withValues(alpha: _menuOpen ? 0.95 : 0.85),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChromeDropdownMenu<T> extends StatefulWidget {
  const _ChromeDropdownMenu({
    required this.items,
    required this.value,
    required this.onSelected,
    required this.enableSearch,
    required this.searchController,
    required this.width,
    required this.itemHeight,
    required this.maxHeight,
    required this.selectionIcon,
    required this.textStyle,
  });

  final List<ChromeDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?> onSelected;
  final bool enableSearch;
  final TextEditingController searchController;
  final double width;
  final double itemHeight;
  final double maxHeight;
  final IconData? selectionIcon;
  final TextStyle? textStyle;

  @override
  State<_ChromeDropdownMenu<T>> createState() => _ChromeDropdownMenuState<T>();
}

class _ChromeDropdownMenuState<T> extends State<_ChromeDropdownMenu<T>> {
  late final AnimatedScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
    if (widget.enableSearch) {
      widget.searchController.addListener(_onSearchChanged);
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.enableSearch) {
      widget.searchController.removeListener(_onSearchChanged);
    }
    _scrollController.dispose();
    super.dispose();
  }

  List<ChromeDropdownItem<T>> get _visibleItems {
    if (!widget.enableSearch) return widget.items;
    final q = widget.searchController.text.toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => i.label.toLowerCase().contains(q))
        .toList();
  }

  void _select(ChromeDropdownItem<T> item) {
    Navigator.of(context).pop();
    widget.onSelected(item.value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _visibleItems;
    final baseStyle = widget.textStyle ?? const TextStyle(fontSize: 14);
    return Material(
      color: cs.surfaceContainerHighest,
      elevation: 6,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.enableSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: TextField(
                  controller: widget.searchController,
                  autofocus: true,
                  style: baseStyle.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: baseStyle.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      size: 18,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: cs.onSurface.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: items.isEmpty
                  ? SizedBox(
                      width: widget.width,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No options',
                          style: baseStyle.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  : ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ChromeDropdownMenuItem(
                            label: item.label,
                            selected: item.value == widget.value,
                            onTap: () => _select(item),
                            height: widget.itemHeight,
                            selectionIcon: widget.selectionIcon,
                            textStyle: baseStyle,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeDropdownMenuItem extends StatelessWidget {
  const _ChromeDropdownMenuItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.selectionIcon,
    required this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final IconData? selectionIcon;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: selected
              ? cs.onSurface.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Row(
            children: [
              if (selectionIcon != null) ...[
                SizedBox(
                  width: 18,
                  height: 16,
                  child: selected
                      ? Icon(selectionIcon, size: 16, color: cs.onSurface)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: textStyle.copyWith(
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.7),
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
