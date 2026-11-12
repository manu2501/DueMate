import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';

/// Large amount input used at the top of entry sheets: the amount is the
/// first thing you type, so it gets the most space.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String symbol;
  final Color? accent;
  final VoidCallback? onChanged;
  final bool autofocus;

  const AmountField({
    super.key,
    required this.controller,
    required this.symbol,
    this.focusNode,
    this.accent,
    this.onChanged,
    this.autofocus = false,
  });

  /// Text for a number without a pointless ".0", keeping real paise/cents.
  static String plain(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final big = Theme.of(context).textTheme.displaySmall!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Text(symbol, style: big.copyWith(color: accent ?? cs.onSurfaceVariant)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: big,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: big.copyWith(color: cs.outline),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
              onChanged: (_) => onChanged?.call(),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear amount',
              icon: const Icon(Icons.clear_rounded, size: 20),
              onPressed: () {
                controller.clear();
                onChanged?.call();
              },
            ),
        ],
      ),
    );
  }
}
