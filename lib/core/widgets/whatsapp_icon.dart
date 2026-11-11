import 'package:flutter/material.dart';

class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({
    super.key,
    this.size = 22.0,
    this.color = const Color(0xFF25D366),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppPainter(color: color),
      ),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;

  _WhatsAppPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.scale(scaleX, scaleY);

    // Vector path for WhatsApp speech bubble
    final path = Path()
      ..moveTo(12.01, 2.0)
      ..cubicTo(6.48, 2.0, 2.0, 6.48, 2.0, 12.01)
      ..cubicTo(2.0, 13.78, 2.46, 15.44, 3.27, 16.89)
      ..lineTo(2.0, 22.0)
      ..lineTo(7.23, 20.73)
      ..cubicTo(8.64, 21.5, 10.28, 21.94, 12.01, 21.94)
      ..cubicTo(17.54, 21.94, 22.02, 17.46, 22.02, 11.93)
      ..cubicTo(22.02, 6.48, 17.54, 2.0, 12.01, 2.0)
      ..close();

    canvas.drawPath(path, paint);

    // Inner phone handset cut-out
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final phonePath = Path()
      ..moveTo(17.2, 14.33)
      ..cubicTo(16.92, 14.2, 15.54, 13.51, 15.28, 13.42)
      ..cubicTo(15.02, 13.33, 14.83, 13.28, 14.64, 13.56)
      ..cubicTo(14.45, 13.84, 13.91, 14.48, 13.75, 14.67)
      ..cubicTo(13.59, 14.86, 13.43, 14.88, 13.15, 14.74)
      ..cubicTo(12.87, 14.6, 11.97, 14.31, 10.9, 13.36)
      ..cubicTo(10.07, 12.62, 9.51, 11.71, 9.35, 11.43)
      ..cubicTo(9.19, 11.15, 9.33, 11.0, 9.47, 10.86)
      ..cubicTo(9.6, 10.73, 9.76, 10.52, 9.9, 10.36)
      ..cubicTo(10.04, 10.2, 10.09, 10.09, 10.18, 9.9)
      ..cubicTo(10.27, 9.71, 10.23, 9.55, 10.16, 9.41)
      ..cubicTo(10.09, 9.27, 9.53, 7.9, 9.3, 7.34)
      ..cubicTo(9.07, 6.8, 8.84, 6.87, 8.67, 6.86)
      ..cubicTo(8.51, 6.85, 8.32, 6.85, 8.13, 6.85)
      ..cubicTo(7.94, 6.85, 7.64, 6.92, 7.38, 7.2)
      ..cubicTo(7.12, 7.48, 6.38, 8.18, 6.38, 9.61)
      ..cubicTo(6.38, 11.04, 7.42, 12.42, 7.57, 12.61)
      ..cubicTo(7.72, 12.8, 9.62, 15.72, 12.54, 16.98)
      ..cubicTo(13.23, 17.28, 13.77, 17.46, 14.19, 17.59)
      ..cubicTo(14.88, 17.81, 15.51, 17.78, 16.01, 17.71)
      ..cubicTo(16.57, 17.63, 17.73, 17.01, 17.97, 16.34)
      ..cubicTo(18.21, 15.67, 18.21, 15.1, 18.14, 14.98)
      ..cubicTo(18.07, 14.86, 17.88, 14.79, 17.6, 14.65)
      ..close();

    canvas.drawPath(phonePath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
