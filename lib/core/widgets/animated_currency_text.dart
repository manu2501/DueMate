import 'package:flutter/material.dart';
import 'package:duemate/core/utils/currency_formatter.dart';

/// Smooth animated rollup text for monetary currency values
class AnimatedCurrencyText extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCurrencyText({
    super.key,
    required this.amount,
    required this.currencySymbol,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          CurrencyFormatter.format(value, symbol: currencySymbol),
          style: style,
        );
      },
    );
  }
}
