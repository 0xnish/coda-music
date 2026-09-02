import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedCodaTitle extends StatefulWidget {
  final double fontSize;
  final double letterSpacing;

  const AnimatedCodaTitle({
    super.key,
    this.fontSize = 15,
    this.letterSpacing = 1.2,
  });

  @override
  State<AnimatedCodaTitle> createState() => _AnimatedCodaTitleState();
}

class _AnimatedCodaTitleState extends State<AnimatedCodaTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const _text = 'CODA MUSIC';
  late final List<int> _letterIndices;
  late final List<Widget> _cachedWidgets;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _letterIndices = [];
    for (int i = 0; i < _text.length; i++) {
      if (_text[i] != ' ') {
        _letterIndices.add(i);
      }
    }
    _buildCache();
  }

  @override
  void didUpdateWidget(AnimatedCodaTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.letterSpacing != widget.letterSpacing) {
      _buildCache();
    }
  }

  void _buildCache() {
    final textStyle = GoogleFonts.poppins(
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ).copyWith(
      fontSize: widget.fontSize,
      letterSpacing: widget.letterSpacing,
    );
    _cachedWidgets = List.generate(_text.length, (index) {
      final char = _text[index];
      if (char == ' ') {
        return SizedBox(width: widget.fontSize * 0.35);
      }
      return Text(char, style: textStyle);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalLetters = _letterIndices.length;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_text.length, (index) {
            if (_text[index] == ' ') {
              return _cachedWidgets[index];
            }
            final offset = index / totalLetters;
            final value = (_controller.value - offset) % 1.0;
            final scale = 1.0 + 0.3 * (1.0 - (value * 2 - 1).abs());
            return Transform.scale(
              scale: scale,
              child: _cachedWidgets[index],
            );
          }),
        );
      },
    );
  }
}
