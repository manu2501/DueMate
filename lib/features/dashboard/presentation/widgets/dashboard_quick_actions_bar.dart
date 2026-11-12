import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

/// Five shortcuts in one neutral style. Colour is reserved for money
/// direction (give/receive), not decoration.
class DashboardQuickActionsBar extends StatelessWidget {
  const DashboardQuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
      child: Row(
        children: [
          _Action(
            label: 'Give',
            icon: Icons.north_east_rounded,
            color: ledger.cashOut,
            onTap: () => QuickGiveSheet.show(context),
          ),
          _Action(
            label: 'Receive',
            icon: Icons.south_west_rounded,
            color: ledger.cashIn,
            onTap: () => QuickReceiveSheet.show(context),
          ),
          _Action(
            label: 'Expense',
            icon: Icons.receipt_long_outlined,
            color: cs.onSurfaceVariant,
            onTap: () => AddEditExpenseSheet.show(context),
          ),
          _Action(
            label: 'Add EMI',
            icon: Icons.event_repeat_outlined,
            color: cs.onSurfaceVariant,
            onTap: () => AddEditEmiScreen.show(context),
          ),
          _Action(
            label: 'Person',
            icon: Icons.person_add_alt_outlined,
            color: cs.onSurfaceVariant,
            onTap: () => AddEditPersonScreen.show(context),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: AppSpace.xs + 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
