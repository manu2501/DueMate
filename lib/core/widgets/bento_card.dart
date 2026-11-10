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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(20);

    final cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: backgroundGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF18181B).withValues(alpha: 0.85), // Zinc-900
                      const Color(0xFF0F0F12).withValues(alpha: 0.95),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF1F5F9), // Slate-100
                    ],
            ),
        border: Border.all(
          color: isDark
              ? (glowColor != null
                  ? glowColor!.withValues(alpha: 0.35)
                  : const Color(0x1FFFFFFF)) // 12% white border
              : (glowColor != null
                  ? glowColor!.withValues(alpha: 0.25)
                  : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
        boxShadow: [
          if (glowColor != null && isDark)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          else if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

