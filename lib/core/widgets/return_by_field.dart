import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';

/// "Return by" for money given: optional, so it starts as one link ("Add a
/// return-by date") and opens to quick picks (1 week, 2 weeks, 1 month) and
/// a date picker. Opens by itself when a date is already set.
class ReturnByField extends StatefulWidget {
  final DateTime? value;
  final DateTime from;
  final ValueChanged<DateTime?> onChanged;

  const ReturnByField({super.key, required this.value, required this.from, required this.onChanged});

  @override
  State<ReturnByField> createState() => _ReturnByFieldState();
}

class _ReturnByFieldState extends State<ReturnByField> {
  static const _presets = <(String, int)>[('1 week', 7), ('2 weeks', 14), ('1 month', 30)];

  late bool _open = widget.value != null;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void didUpdateWidget(ReturnByField old) {
    super.didUpdateWidget(old);
    if (widget.value != null && !_open) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.event_available_outlined, size: 20),
          label: const Text('Add a return-by date'),
        ),
      );
    }

    final base = _day(widget.from);
    final picked = widget.value == null ? null : _day(widget.value!);
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
      if (d != null) widget.onChanged(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('Return by', style: theme.textTheme.labelLarge?.copyWith(color: muted))),
            // Back to the single link; clears any date chosen.
            IconButton(
              tooltip: 'No return-by date',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                widget.onChanged(null);
                setState(() => _open = false);
              },
            ),
          ],
        ),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (var i = 0; i < _presets.length; i++)
              ChoiceChip(
                label: Text(_presets[i].$1),
                selected: picked == presetDates[i],
                onSelected: (_) => widget.onChanged(presetDates[i]),
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
            child: Text('By ${DateFormatter.formatDate(picked)}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
      ],
    );
  }
}
