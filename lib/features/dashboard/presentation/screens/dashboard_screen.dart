import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/utils/permission_manager.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_give_sheet.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/core/widgets/transaction_tile.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:smarava/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Ask for permissions needed at start of app or on update
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await PermissionManager.checkAndPromptOnStartupOrUpdate(context);
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final ledgerSummaryAsync = ref.watch(ledgerSummaryProvider);
    final topDebtors = ref.watch(topDebtorsProvider);
    final recentTxAsync = ref.watch(recentTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Person',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Record Entry',
        onPressed: () => _showQuickActionSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ledgerSummaryProvider);
          ref.invalidate(allPersonSummariesProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Material 3 Hero Card - Total Outstanding Balance
              ledgerSummaryAsync.when(
                data: (summary) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        Card(
                          elevation: 0,
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'TOTAL OUTSTANDING RECEIVABLES',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (summary.activePeopleCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${summary.activePeopleCount} owing',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  CurrencyFormatter.format(summary.totalOutstanding, symbol: currencySymbol),
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.0,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Material 3 Given vs Received Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward_rounded,
                                                  size: 14,
                                                  color: colorScheme.error,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Given',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol),
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_downward_rounded,
                                                  size: 14,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Received',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol),
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Material 3 Quick Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => QuickReceiveSheet.show(context),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                                label: const Text(
                                  'Receive',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => QuickGiveSheet.show(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                label: const Text(
                                  'Give Money',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading summary: $err'),
                ),
              ),

              // Section: People Owing You
              if (topDebtors.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'People owing you',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/people'),
                        child: const Row(
                          children: [
                            Text('View all', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: topDebtors.length > 5 ? 5 : topDebtors.length,
                  itemBuilder: (ctx, index) {
                    final debtor = topDebtors[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        onTap: () => context.push('/people/${debtor.person.id}'),
                        leading: AvatarWidget(name: debtor.person.name, radius: 20),
                        title: Text(
                          debtor.person.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: debtor.lastTransaction != null
                            ? Text(
                                'Last: ${DateFormatter.formatRelative(debtor.lastTransaction!.transactionDate)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              )
                            : null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                CurrencyFormatter.format(debtor.balance, symbol: currencySymbol),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              // Section: Recent Activity
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: Text(
                        'Full History',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              recentTxAsync.when(
                data: (recentTxs) {
                  if (recentTxs.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No lending records yet',
                      description: 'Start keeping track of money you give to friends and family.',
                      actionLabel: 'Add Person',
                      onActionPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
                        );
                      },
                    );
                  }

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTxs.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      itemBuilder: (ctx, index) {
                        final tx = recentTxs[index];
                        final person = personsMap[tx.personId];
                        return TransactionTile(
                          transaction: tx,
                          person: person,
                          currencySymbol: currencySymbol,
                          onTap: () {
                            TransactionDetailsDialog.show(
                              context,
                              transaction: tx,
                              person: person,
                            );
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Record Transaction',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.errorContainer,
                    child: Icon(Icons.arrow_upward_rounded, color: colorScheme.onErrorContainer, size: 20),
                  ),
                  title: const Text('Give Money', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Record money given or loan advanced'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    QuickGiveSheet.show(context);
                  },
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.arrow_downward_rounded, color: colorScheme.onPrimaryContainer, size: 20),
                  ),
                  title: const Text('Receive Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Record ad-hoc or installment repayment'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    QuickReceiveSheet.show(context);
                  },
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(Icons.person_add_rounded, color: colorScheme.onSecondaryContainer, size: 20),
                  ),
                  title: const Text('Add Person', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Add someone new to your ledger'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (c) => const AddEditPersonScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
