import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/widgets/pressable_scale.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class DashboardQuickActionsBar extends StatelessWidget {
  const DashboardQuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              label: 'Give',
              icon: Icons.north_east_rounded,
              color: const Color(0xFFEF4444),
              onTap: () => QuickGiveSheet.show(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              label: 'Receive',
              icon: Icons.south_west_rounded,
              color: const Color(0xFF10B981),
              onTap: () => QuickReceiveSheet.show(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              label: 'Expense',
              icon: Icons.receipt_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => AddEditExpenseSheet.show(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              label: 'Add EMI',
              icon: Icons.event_repeat_rounded,
              color: Colors.purple,
              onTap: () => AddEditEmiScreen.show(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              label: 'Person',
              icon: Icons.person_add_outlined,
              color: const Color(0xFF4F46E5),
              onTap: () => AddEditPersonScreen.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
