import 'package:flutter/material.dart';

/// Initials avatar. One tonal colour for everyone: a per-person rainbow
/// competes with the green/red that carries money meaning.
class AvatarWidget extends StatelessWidget {
  final String name;
  final double radius;
  final TextStyle? textStyle;
  final String? heroTag;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = 20,
    this.textStyle,
    this.heroTag,
  });

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
    final cs = Theme.of(context).colorScheme;

    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: textStyle ??
            TextStyle(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: radius * 0.75,
            ),
      ),
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: avatar,
        ),
      );
    }

    return avatar;
  }
}
