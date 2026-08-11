import 'dart:math';
import 'package:flutter/material.dart';

class SquigglyProgressBar extends StatefulWidget {
  final Duration progress;
  final Duration total;
  final Duration buffered;
  final ValueChanged<Duration>? onSeek;
  final Color baseColor;
  final Color progressColor;
  final Color thumbColor;
  final Color bufferedColor;
  final double strokeWidth;
  final double thumbRadius;
  final bool showTimeLabels;
  final TextStyle? timeLabelTextStyle;

  const SquigglyProgressBar({
    super.key,
    required this.progress,
    required this.total,
    this.buffered = Duration.zero,
    this.onSeek,
    this.baseColor = const Color(0x4DFFFFFF),
    this.progressColor = Colors.white,
    this.thumbColor = Colors.white,
    this.bufferedColor = const Color(0x80FFFFFF),
    this.strokeWidth = 3.0,
    this.thumbRadius = 6.0,
    this.showTimeLabels = true,
    this.timeLabelTextStyle,
  });

  @override
  State<SquigglyProgressBar> createState() => _SquigglyProgressBarState();
}

class _SquigglyProgressBarState extends State<SquigglyProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  double _fractionFor(Duration value) {
    if (widget.total.inMilliseconds <= 0) return 0.0;
    return (value.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0);
  }

  double get _fraction => _fractionFor(widget.progress);

  double get _bufferedFraction =>
      widget.total.inMilliseconds > 0
          ? (widget.buffered.inMilliseconds / widget.total.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;

  double get _displayFraction => _dragFraction ?? _fraction;

  Duration get _displayDuration => Duration(
      milliseconds: (_displayFraction * widget.total.inMilliseconds).round());

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seekToFraction(double fraction) {
    if (widget.onSeek == null || widget.total.inMilliseconds <= 0) return;
    final ms = (fraction.clamp(0.0, 1.0) * widget.total.inMilliseconds).round();
    widget.onSeek!(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.timeLabelTextStyle ??
        const TextStyle(color: Colors.white, fontSize: 12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            setState(() {
              _dragFraction = (details.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          onTapUp: (details) {
            final fraction = (details.localPosition.dx / w).clamp(0.0, 1.0);
            setState(() => _dragFraction = null);
            _seekToFraction(fraction);
          },
          onTapCancel: () {
            setState(() => _dragFraction = null);
          },
          onHorizontalDragStart: (details) {
            setState(() {
              _dragFraction = (details.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragFraction = (details.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) {
            final target = _dragFraction;
            setState(() => _dragFraction = null);
            if (target != null) _seekToFraction(target);
          },
          onHorizontalDragCancel: () {
            setState(() => _dragFraction = null);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(w, 30),
                      painter: _SquigglyPainter(
                        fraction: _displayFraction,
                        bufferedFraction: _bufferedFraction,
                        animValue: _waveController.value,
                        baseColor: widget.baseColor,
                        progressColor: widget.progressColor,
                        bufferedColor: widget.bufferedColor,
                        strokeWidth: widget.strokeWidth,
                        thumbRadius: widget.thumbRadius,
                        thumbColor: widget.thumbColor,
                      ),
                    );
                  },
                ),
              ),
              if (widget.showTimeLabels)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_displayDuration), style: labelStyle),
                      Text(_fmt(widget.total), style: labelStyle),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SquigglyPainter extends CustomPainter {
  final double fraction;
  final double bufferedFraction;
  final double animValue;
  final Color baseColor;
  final Color progressColor;
  final Color bufferedColor;
  final double strokeWidth;
  final double thumbRadius;
  final Color thumbColor;

  _SquigglyPainter({
    required this.fraction,
    required this.bufferedFraction,
    required this.animValue,
    required this.baseColor,
    required this.progressColor,
    required this.bufferedColor,
    required this.strokeWidth,
    required this.thumbRadius,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final mid = h / 2;
    final amplitude = h * 0.15;
    final waveLength = 60.0;
    final phase = animValue * 2 * pi;

    final progressX = size.width * fraction;
    final bufferedX = size.width * bufferedFraction;

    final basePath = Path();
    final progressPath = Path();
    final bufferedPath = Path();

    for (double x = 0; x <= size.width; x += 0.5) {
      final y = mid + amplitude * sin((x / waveLength) * 2 * pi + phase);

      if (x == 0) {
        basePath.moveTo(x, y);
        progressPath.moveTo(x, y);
        bufferedPath.moveTo(x, y);
      } else {
        basePath.lineTo(x, y);
        if (x <= progressX) {
          progressPath.lineTo(x, y);
        }
        if (x <= bufferedX) {
          bufferedPath.lineTo(x, y);
        }
      }
    }

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bufferedPaint = Paint()
      ..color = bufferedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(basePath, basePaint);
    if (bufferedFraction > 0) {
      canvas.drawPath(bufferedPath, bufferedPaint);
    }
    if (fraction > 0) {
      canvas.drawPath(progressPath, progressPaint);
    }

    final thumbX = progressX;
    final thumbY =
        mid + amplitude * sin((thumbX / waveLength) * 2 * pi + phase);

    final haloPaint = Paint()
      ..color = thumbColor.withValues(alpha: 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thumbRadius * 0.9);
    canvas.drawCircle(
        Offset(thumbX, thumbY), thumbRadius + 4, haloPaint);

    final ringPaint = Paint()
      ..color = thumbColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbRadius + 1.2, ringPaint);

    final thumbPaint = Paint()..color = thumbColor;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _SquigglyPainter old) =>
      fraction != old.fraction ||
      bufferedFraction != old.bufferedFraction ||
      animValue != old.animValue ||
      baseColor != old.baseColor ||
      progressColor != old.progressColor;
}
