import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';

/// "Return by" for money given: none, a quick 1 week / 2 weeks / 1 month
/// from [from] (the day it was given), or any date.
class ReturnByField extends StatelessWidget {
  final DateTime? value;
  final DateTime from;
  final ValueChanged<DateTime?> onChanged;

  const ReturnByField({super.key, required this.value, required this.from, required this.onChanged});

  static const _presets = <(String, int)>[('1 week', 7), ('2 weeks', 14), ('1 month', 30)];

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = _day(from);
    final picked = value == null ? null : _day(value!);
    final presetDates = [for (final (_, days) in _presets) base.add(Duration(days: days))];
    final isCustom = picked != null && !presetDates.contains(picked);

    Future<void> pick() async {
      final d = await showDatePicker(
        context: context,
        initialDate: picked ?? base.add(const Duration(days: 7)),
        firstDate: base,
        lastDate: base.add(const Duration(days: 365 * 3)),
        helpText: 'Return by',
      );
      if (d != null) onChanged(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Return by (optional)',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            ChoiceChip(label: const Text('No date'), selected: picked == null, onSelected: (_) => onChanged(null)),
            for (var i = 0; i < _presets.length; i++)
              ChoiceChip(
                label: Text(_presets[i].$1),
                selected: picked == presetDates[i],
                onSelected: (_) => onChanged(presetDates[i]),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(isCustom ? DateFormatter.formatShortDate(picked) : 'Pick a date'),
              selected: isCustom,
              onSelected: (_) => pick(),
            ),
          ],
        ),
        if (picked != null && !isCustom)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text('By ${DateFormatter.formatDate(picked)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}
