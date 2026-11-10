import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static const _palettes = [
    [Color(0xFF4F46E5), Color(0xFF6366F1)], // Indigo
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)], // Sky
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)], // Violet
    [Color(0xFFEC4899), Color(0xFFF472B6)], // Pink
    [Color(0xFFF97316), Color(0xFFFB923C)], // Orange
    [Color(0xFF10B981), Color(0xFF34D399)], // Emerald
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)], // Teal
    [Color(0xFFEF4444), Color(0xFFF87171)], // Red
  ];

  List<Color> _getGradient(String name) {
    if (name.isEmpty) return _palettes[0];
    final hash = name.codeUnits.fold(0, (prev, curr) => prev + curr);
    return _palettes[hash % _palettes.length];
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
    final gradient = _getGradient(name);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: textStyle ??
            GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.75,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
