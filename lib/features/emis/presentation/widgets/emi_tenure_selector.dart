import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tenure (Months)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (currentTenureMonths > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currentTenureMonths ${currentTenureMonths == 1 ? 'Month' : 'Months'}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Custom Tenure Input
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.timer_outlined),
            labelText: 'Enter Tenure (Number of Months)',
            hintText: 'e.g. 1, 4, 5, 10, 15, 60...',
            suffixText: 'months',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            final val = int.tryParse(value?.trim() ?? '');
            if (val == null || val <= 0) {
              return 'Please enter a valid tenure in months (at least 1)';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        // Quick Presets
        Text(
          'Quick Presets:',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presetOptions.map((months) {
            final isSelected = currentTenureMonths == months;
            return ChoiceChip(
              label: Text('$months mo'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelectPreset(months);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
