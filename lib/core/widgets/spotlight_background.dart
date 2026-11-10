import 'package:flutter/material.dart';

/// Clean Material 3 Surface wrapper replacing legacy radial spotlight animations
class SpotlightBackground extends StatelessWidget {
  final Widget child;
  final Color? primaryGlow;
  final Color? secondaryGlow;

  const SpotlightBackground({
    super.key,
    required this.child,
    this.primaryGlow,
    this.secondaryGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}
