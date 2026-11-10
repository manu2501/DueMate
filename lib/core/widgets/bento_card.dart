import 'package:flutter/material.dart';

/// Material 3 Card component replacing legacy custom bento styling
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
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.glowColor,
    this.borderRadius,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final r = borderRadius ?? BorderRadius.circular(16);

    final card = Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: BorderSide(
          color: glowColor != null
              ? glowColor!.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: glowColor != null ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: r,
              child: Padding(
                padding: padding,
                child: child,
              ),
            )
          : Padding(
              padding: padding,
              child: child,
            ),
    );

    return card;
  }
}
