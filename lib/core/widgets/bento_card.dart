import 'package:flutter/material.dart';

class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? glowColor;
  final BorderRadius? borderRadius;
  final LinearGradient? backgroundGradient;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.glowColor,
    this.borderRadius,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = borderRadius ?? BorderRadius.circular(20);

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: r, child: content);
    }

    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: r,
        color: backgroundGradient == null ? cs.surfaceContainerLow : null,
        gradient: backgroundGradient,
        border: glowColor != null
            ? Border.all(color: glowColor!.withValues(alpha: 0.3))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
