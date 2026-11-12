import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duemate/core/theme/app_theme.dart';

/// Number of months: type any value, or tap a common length.
class EmiTenureSelector extends StatelessWidget {
  final TextEditingController controller;
  final int currentTenureMonths;
  final List<int> presetOptions;
  final ValueChanged<int> onSelectPreset;

  const EmiTenureSelector({
    super.key,
    required this.controller,
    required this.currentTenureMonths,
    required this.presetOptions,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Number of months',
            prefixIcon: Icon(Icons.date_range_outlined),
            suffixText: 'months',
          ),
          validator: (value) {
            final n = int.tryParse(value?.trim() ?? '');
            return (n == null || n <= 0) ? 'Enter at least 1 month' : null;
          },
        ),
        const SizedBox(height: AppSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final m in presetOptions) ...[
                ChoiceChip(
                  label: Text('$m'),
                  selected: currentTenureMonths == m,
                  onSelected: (_) => onSelectPreset(m),
                ),
                const SizedBox(width: AppSpace.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
