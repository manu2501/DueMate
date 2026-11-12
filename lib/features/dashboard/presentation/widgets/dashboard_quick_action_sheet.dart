import 'package:flutter/material.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class DashboardQuickActionSheet extends StatelessWidget {
  const DashboardQuickActionSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomPadding),
          child: const SingleChildScrollView(
            child: DashboardQuickActionSheet(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Record Entry',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: cs.surfaceContainer,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.north_east_rounded, color: cs.error),
          ),
          title: const Text('Give Money (Loan / Advance)'),
          subtitle: const Text('Record money you gave to someone'),
          onTap: () {
            Navigator.of(context).pop();
            QuickGiveSheet.show(context);
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: cs.surfaceContainer,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.south_west_rounded, color: cs.primary),
          ),
          title: const Text('Receive Money (Repayment)'),
          subtitle: const Text('Record a repayment collected from someone'),
          onTap: () {
            Navigator.of(context).pop();
            QuickReceiveSheet.show(context);
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: cs.surfaceContainer,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_repeat_rounded, color: Colors.purple),
          ),
          title: const Text('Add EMI or Monthly Loan'),
          subtitle: const Text('Track monthly installments for cards & loans'),
          onTap: () {
            Navigator.of(context).pop();
            AddEditEmiScreen.show(context);
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: cs.surfaceContainer,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_add_outlined, color: cs.secondary),
          ),
          title: const Text('Add Person'),
          subtitle: const Text('Create a new contact in your ledger'),
          onTap: () {
            Navigator.of(context).pop();
            AddEditPersonScreen.show(context);
          },
        ),
      ],
    );
  }
}
