import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';

class ChoiceOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  const ChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}

/// A row of equal-width, single-select tiles. Use it for small "pick one"
/// choices that need a subtitle; for plain labels prefer [SegmentedButton].
class ChoiceTileGroup<T> extends StatelessWidget {
  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const ChoiceTileGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.sm + 2),
          Expanded(
            child: _ChoiceTile(
              option: options[i],
              isSelected: options[i].value == selected,
              onTap: () => onChanged(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final ChoiceOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = isSelected ? cs.primary : cs.onSurface;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer.withValues(alpha: 0.5) : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, size: 18, color: isSelected ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  Expanded(
                    child: Text(
                      option.label,
                      style: theme.textTheme.labelLarge?.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
                ],
              ),
              if (option.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  option.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
