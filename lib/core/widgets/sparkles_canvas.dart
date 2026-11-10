import 'package:flutter/material.dart';

/// Clean Material 3 canvas wrapper replacing legacy neon sparkle canvas animations
class SparklesCanvas extends StatelessWidget {
  final Widget child;
  final int count;

  const SparklesCanvas({
    super.key,
    required this.child,
    this.count = 45,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
