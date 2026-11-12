import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';

/// The DueMate mark: a "D" with a small "due" dot, on the brand colour.
///
/// Geometry is on Android's 108×108 adaptive-icon grid, so the same numbers
/// are used by `android/app/src/main/res/drawable/ic_launcher_foreground.xml`.
/// Keep the two in sync.
class AppLogo extends StatelessWidget {
  final double size;

  /// Draw the brand square behind the mark. Off = just the mark, e.g. on a
  /// coloured surface.
  final bool withBackground;

  const AppLogo({super.key, this.size = 48, this.withBackground = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DueMate',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: AppLogoPainter(withBackground: withBackground),
      ),
    );
  }
}

class AppLogoPainter extends CustomPainter {
  final bool withBackground;
  final Color background;
  final Color mark;
  final Color accent;

  /// Draw the full 108-unit canvas (for launcher PNGs) instead of cropping to
  /// the visible 72-unit area used inside the app.
  final bool fullBleed;

  const AppLogoPainter({
    this.withBackground = true,
    this.background = AppTheme.brand,
    this.mark = Colors.white,
    this.accent = AppTheme.brandAccent,
    this.fullBleed = false,
  });

  /// "D": outer contour minus the counter (even-odd).
  static Path letterPath() => Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(32, 34)
    ..lineTo(52, 34)
    ..arcToPoint(const Offset(52, 74), radius: const Radius.circular(20))
    ..lineTo(32, 74)
    ..close()
    ..moveTo(42, 44)
    ..lineTo(52, 44)
    ..arcToPoint(const Offset(52, 64), radius: const Radius.circular(10))
    ..lineTo(42, 64)
    ..close();

  static const Offset dotCenter = Offset(72, 34);
  static const double dotRadius = 5;

  @override
  void paint(Canvas canvas, Size size) {
    // Inside the app we show the 72-unit visible region (18..90), which is
    // what launchers show after masking.
    final viewport = fullBleed ? const Rect.fromLTWH(0, 0, 108, 108) : const Rect.fromLTWH(18, 18, 72, 72);
    final scale = size.width / viewport.width;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-viewport.left, -viewport.top);

    if (withBackground) {
      final bg = Paint()..color = background;
      if (fullBleed) {
        canvas.drawRect(viewport, bg);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(viewport, const Radius.circular(18)), bg);
      }
    }
    canvas.drawPath(letterPath(), Paint()..color = mark..isAntiAlias = true);
    canvas.drawCircle(dotCenter, dotRadius, Paint()..color = accent..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppLogoPainter old) =>
      old.withBackground != withBackground ||
      old.background != background ||
      old.mark != mark ||
      old.accent != accent ||
      old.fullBleed != fullBleed;
}
