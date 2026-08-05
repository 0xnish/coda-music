import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Coda/services/bottom_message.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late final AnimatedScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _SupportCard(
                        icon: Icons.account_balance_rounded,
                        title: 'UPI',
                        value: 'coder-nishanth@airtel',
                        onTap: () {
                          Clipboard.setData(
                            const ClipboardData(text: 'coder-nishanth@airtel'),
                          );
                          BottomMessage.showText(
                            context,
                            'UPI ID copied!',
                            duration: const Duration(seconds: 2),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                SizedBox(
                  width: 320,
                  child: _SupportCard(
                    icon: Icons.coffee_rounded,
                    title: 'Buy Me a Coffee',
                    value: 'Buy Me a Coffee',
                        onTap: () async {
                          final uri = Uri.parse('https://buymeacoffee.com/coder.nishanth');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text(
                  'Made with passion \u2022 Coda Music',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ],
      ),
      ),
    );
  }
}

class _SupportCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  State<_SupportCard> createState() => _SupportCardState();
}

class _SupportCardState extends State<_SupportCard>
    with TickerProviderStateMixin {
  bool _hovered = false;
  final List<_HeartParticle> _particles = [];
  late Ticker _particleTicker;

  @override
  void initState() {
    super.initState();
    _particleTicker = createTicker(_onParticleTick);
  }

  @override
  void dispose() {
    _particleTicker.dispose();
    super.dispose();
  }

  void _spawnHearts() {
    final rand = Random();
    const double w = 320;
    const double h = 90;
    for (int i = 0; i < 2; i++) {
      final edge = rand.nextInt(4);
      double x = 0, y = 0;
      switch (edge) {
        case 0:
          x = rand.nextDouble() * w;
          y = -rand.nextDouble() * 20 - 5;
        case 1:
          x = w + rand.nextDouble() * 20 + 5;
          y = rand.nextDouble() * h;
        case 2:
          x = rand.nextDouble() * w;
          y = h + rand.nextDouble() * 20 + 5;
        case 3:
          x = -rand.nextDouble() * 20 - 5;
          y = rand.nextDouble() * h;
      }
      _particles.add(_HeartParticle(
        x: x,
        y: y,
        size: 6 + rand.nextDouble() * 10,
        vx: (rand.nextDouble() - 0.5) * 1.5,
        vy: -(1.0 + rand.nextDouble() * 1.5),
        rotation: rand.nextDouble() * pi * 2,
        rotationSpeed: (rand.nextDouble() - 0.5) * 0.1,
        baseAlpha: 0.6 + rand.nextDouble() * 0.4,
      ));
    }
  }

  void _onParticleTick(Duration elapsed) {
    if (!mounted) return;
    setState(() {
      if (_hovered) _spawnHearts();
      _particles.removeWhere((p) => p.life >= 1.0);
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life += 0.016;
        p.rotation += p.rotationSpeed;
      }
      if (_particles.isEmpty && !_hovered) {
        _particleTicker.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        if (!_particleTicker.isActive) _particleTicker.start();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: double.infinity,
          transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: _hovered ? 0.7 : 0.55),
                  ),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _hovered ? 0.4 : 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: widget.icon == Icons.account_balance_rounded
                          ? const Center(
                              child: Text(
                                'UPI',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          : Icon(widget.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.value.isNotEmpty ? widget.value : widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: Colors.white.withValues(alpha: _hovered ? 0.75 : 0.55),
                    ),
                  ],
                ),
              ),
              if (_particles.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HeartsPainter(particles: _particles),
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

class _HeartParticle {
  double x;
  double y;
  double size;
  double vx;
  double vy;
  double life = 0;
  double rotation;
  double rotationSpeed;
  double baseAlpha;

  _HeartParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.vx,
    required this.vy,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.baseAlpha = 1.0,
  });
}

class _HeartsPainter extends CustomPainter {
  final List<_HeartParticle> particles;

  _HeartsPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final opacity = p.baseAlpha * (1.0 - p.life);
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.scale(p.size / 20.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawPath(_heartPath(20), paint);
      canvas.restore();
    }
  }

  Path _heartPath(double s) {
    return Path()
      ..moveTo(0, s * 0.35)
      ..cubicTo(-s * 0.45, 0, -s * 0.4, -s * 0.35, 0, -s * 0.25)
      ..cubicTo(s * 0.4, -s * 0.35, s * 0.45, 0, 0, s * 0.35)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter old) => true;
}


