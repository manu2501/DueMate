import 'package:flutter/material.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';

class EmiTypeSelector extends StatelessWidget {
  final EmiType selectedType;
  final ValueChanged<EmiType> onChanged;

  const EmiTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeTile(
              label: 'Credit Card EMI',
              subtitle: 'Cards & Online EMIs',
              icon: Icons.credit_card_rounded,
              color: Theme.of(context).colorScheme.secondary,
              isSelected: selectedType == EmiType.creditCard,
              onTap: () => onChanged(EmiType.creditCard),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TypeTile(
              label: 'Personal Loan',
              subtitle: 'Cash / Bank Advances',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF0D9488),
              isSelected: selectedType == EmiType.loan,
              onTap: () => onChanged(EmiType.loan),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? color : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
