import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_give_sheet.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/core/widgets/transaction_tile.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:smarava/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning ☀️';
    } else if (hour < 17) {
      return 'Good afternoon 🌤️';
    } else {
      return 'Good evening 🌙';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
        tooltip: 'Quick Actions',
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
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              ledgerSummaryAsync.when(
                data: (summary) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Main Hero Card - Total Outstanding
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'TOTAL OUTSTANDING',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (summary.activePeopleCount > 0)
                                    Text(
                                      '${summary.activePeopleCount} people owing',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                CurrencyFormatter.format(summary.totalOutstanding, symbol: currencySymbol),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Sub breakdown: Given vs Received
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Given',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Received',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
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
                        const SizedBox(height: 16),

                        // Prominent Quick Action Row
                        Row(
                          children: [
                            // Receive Payment (Green)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => QuickReceiveSheet.show(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                label: const Text(
                                  'Receive',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Give Money (Red)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => QuickGiveSheet.show(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                                label: const Text(
                                  'Give Money',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  padding: EdgeInsets.all(16.0),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'People owing you',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/people'),
                        child: const Text('View All'),
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
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: AvatarWidget(name: debtor.person.name, radius: 20),
                        title: Text(
                          debtor.person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: debtor.lastTransaction != null
                            ? Text(
                                'Last: ${DateFormatter.formatRelative(debtor.lastTransaction!.transactionDate)}',
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.format(debtor.balance, symbol: currencySymbol),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Receive Payment',
                              icon: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 20),
                              onPressed: () => QuickReceiveSheet.show(context, personId: debtor.person.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          context.push('/people/${debtor.person.id}');
                        },
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('All Activity'),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTxs.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 72, endIndent: 20),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'What do you want to record?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_outward_rounded, color: Color(0xFFDC2626)),
                ),
                title: const Text('💸 Give Money', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Record money given to a person'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QuickGiveSheet.show(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('💰 Payment Received', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Record repayment received from someone'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QuickReceiveSheet.show(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_rounded, color: Color(0xFF0D9488)),
                ),
                title: const Text('👤 Add Person', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add someone new to your ledger'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (c) => const AddEditPersonScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
