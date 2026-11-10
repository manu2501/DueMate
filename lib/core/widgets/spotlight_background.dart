import 'dart:math';
import 'package:flutter/material.dart';

class SpotlightBackground extends StatefulWidget {
  final Widget child;
  final Color primaryGlow;
  final Color secondaryGlow;

  const SpotlightBackground({
    super.key,
    required this.child,
    this.primaryGlow = const Color(0xFF0D9488), // Teal
    this.secondaryGlow = const Color(0xFF6366F1), // Indigo
  });

  @override
  State<SpotlightBackground> createState() => _SpotlightBackgroundState();
}

class _SpotlightBackgroundState extends State<SpotlightBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Dark obsidian canvas
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
          ),
        ),

        // Animated ambient glow spots (Aceternity Aura)
        if (isDark)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final val = _controller.value;
              return CustomPaint(
                size: Size.infinite,
                painter: _SpotlightPainter(
                  progress: val,
                  primaryGlow: widget.primaryGlow,
                  secondaryGlow: widget.secondaryGlow,
                ),
              );
            },
          ),

        // Foreground content
        widget.child,
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final double progress;
  final Color primaryGlow;
  final Color secondaryGlow;

  _SpotlightPainter({
    required this.progress,
    required this.primaryGlow,
    required this.secondaryGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center1 = Offset(
      size.width * 0.2 + sin(progress * 2 * pi) * 40,
      size.height * 0.15 + cos(progress * 2 * pi) * 30,
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryGlow.withValues(alpha: 0.18),
          primaryGlow.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center1, radius: size.width * 0.75));

    canvas.drawCircle(center1, size.width * 0.75, paint1);

    final center2 = Offset(
      size.width * 0.85 - cos(progress * 2 * pi) * 40,
      size.height * 0.45 + sin(progress * 2 * pi) * 40,
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryGlow.withValues(alpha: 0.14),
          secondaryGlow.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center2, radius: size.width * 0.65));

    canvas.drawCircle(center2, size.width * 0.65, paint2);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => true;
}

