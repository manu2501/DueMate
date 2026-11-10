import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double radius;
  final TextStyle? textStyle;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = 20,
    this.textStyle,
  });

  Color _getColorForName(String name) {
    final colors = [
      const Color(0xFF0D9488), // Teal
      const Color(0xFF0284C7), // Sky
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF97316), // Orange
      const Color(0xFF10B981), // Emerald
      const Color(0xFF64748B), // Slate
    ];

    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getColorForName(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor.withValues(alpha: 0.15),
      child: Text(
        _getInitials(name),
        style: textStyle ??
            TextStyle(
              color: bgColor,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8,
            ),
      ),
    );
  }
}

