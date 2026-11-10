import 'dart:math';
import 'package:flutter/material.dart';

class SparklesCanvas extends StatefulWidget {
  final int count;
  final Widget child;

  const SparklesCanvas({
    super.key,
    this.count = 35,
    required this.child,
  });

  @override
  State<SparklesCanvas> createState() => _SparklesCanvasState();
}

class _SparklesCanvasState extends State<SparklesCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < widget.count; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: 1.0 + _random.nextDouble() * 2.5,
          speed: 0.05 + _random.nextDouble() * 0.1,
          opacity: 0.2 + _random.nextDouble() * 0.7,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _SparklesPainter(_particles, _controller.value),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _SparklesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _SparklesPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (final p in particles) {
      final currentY = (p.y - progress * p.speed) % 1.0;
      final offset = Offset(p.x * size.width, currentY * size.height);
      paint.color = Colors.white.withValues(alpha: p.opacity * (0.3 + 0.7 * sin(progress * 2 * pi + p.x * 10).abs()));
      canvas.drawCircle(offset, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter oldDelegate) => true;
}

