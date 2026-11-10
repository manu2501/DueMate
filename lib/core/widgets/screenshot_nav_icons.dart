import 'package:flutter/material.dart';

/// Pixel-perfect vector icons matching the 4 bottom navigation dock icons in the design screenshot.
class ScreenshotNavIcon extends StatelessWidget {
  final int index; // 0: Dashboard/Card, 1: Directory/Flag, 2: Reports/Chat, 3: Notifications/Star-Badge
  final bool isSelected;
  final Color color;
  final double size;

  const ScreenshotNavIcon({
    super.key,
    required this.index,
    required this.isSelected,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScreenshotNavIconPainter(
          index: index,
          isSelected: isSelected,
          color: color,
        ),
      ),
    );
  }
}

class _ScreenshotNavIconPainter extends CustomPainter {
  final int index;
  final bool isSelected;
  final Color color;

  const _ScreenshotNavIconPainter({
    required this.index,
    required this.isSelected,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    switch (index) {
      case 0:
        // 1. Card / Document Icon (Rectangle with corner notch & optional layer)
        if (isSelected) {
          // Back card corner
          final backCard = Path()
            ..moveTo(8.5, 3.0)
            ..lineTo(19.0, 3.0)
            ..lineTo(19.0, 14.5);
          canvas.drawPath(backCard, strokePaint);

          // Front card
          final frontCard = RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.5, 5.0, 14.5, 16.0),
            const Radius.circular(3.5),
          );
          canvas.drawRRect(frontCard, strokePaint);

          // Inner notch / square
          final notch = Rect.fromLTWH(7.5, 14.0, 3.5, 3.0);
          canvas.drawRect(notch, strokePaint);
        } else {
          // Single outlined card with corner notch
          final card = RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.0, 3.0, 16.0, 18.0),
            const Radius.circular(3.5),
          );
          canvas.drawRRect(card, strokePaint);

          // Corner notch / horizontal bar inside
          final notch = Rect.fromLTWH(7.0, 14.5, 3.5, 3.0);
          canvas.drawRect(notch, strokePaint);
        }
        break;

      case 1:
        // 2. Pennant / Swallowtail Flag Icon on a pole
        // Vertical pole
        canvas.drawLine(
          const Offset(5.0, 2.5),
          const Offset(5.0, 21.5),
          strokePaint,
        );

        // Flag banner with swallowtail notch
        final flag = Path()
          ..moveTo(5.0, 4.0)
          ..lineTo(18.5, 4.0)
          ..lineTo(14.0, 8.75)
          ..lineTo(18.5, 13.5)
          ..lineTo(5.0, 13.5);

        if (isSelected) {
          // Fill subtle tint or stroke
          final fillPaint = Paint()
            ..color = color.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill;
          canvas.drawPath(flag, fillPaint);
        }
        canvas.drawPath(flag, strokePaint);
        break;

      case 2:
        // 3. Round Speech / Chat Bubble with inner horizontal line
        final bubble = Path()
          ..moveTo(12.0, 3.5)
          ..cubicTo(16.5, 3.5, 20.0, 6.8, 20.0, 10.8)
          ..cubicTo(20.0, 14.8, 16.5, 18.0, 12.0, 18.0)
          ..cubicTo(10.5, 18.0, 9.2, 17.6, 8.0, 17.0)
          ..lineTo(4.5, 19.5)
          ..lineTo(5.5, 15.5)
          ..cubicTo(4.5, 14.2, 4.0, 12.5, 4.0, 10.8)
          ..cubicTo(4.0, 6.8, 7.5, 3.5, 12.0, 3.5)
          ..close();

        canvas.drawPath(bubble, strokePaint);

        // Inner horizontal line
        canvas.drawLine(
          const Offset(9.0, 10.8),
          const Offset(15.0, 10.8),
          strokePaint,
        );
        break;

      case 3:
      default:
        // 4. Star / Ribbon Badge (4-pointed peak with notched ribbon bottom & center circle)
        final starBadge = Path()
          ..moveTo(12.0, 2.5) // Top peak
          ..lineTo(20.5, 10.5) // Right point
          ..lineTo(17.0, 20.5) // Right foot
          ..lineTo(12.0, 16.5) // Inverted V notch
          ..lineTo(7.0, 20.5) // Left foot
          ..lineTo(3.5, 10.5) // Left point
          ..close();

        canvas.drawPath(starBadge, strokePaint);

        // Center circular cutout
        canvas.drawCircle(
          const Offset(12.0, 10.5),
          2.0,
          strokePaint,
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScreenshotNavIconPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.color != color;
  }
}
