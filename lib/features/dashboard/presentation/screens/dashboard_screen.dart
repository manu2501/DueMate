import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/bento_card.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_give_sheet.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/core/widgets/spotlight_background.dart';
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
    final isDark = theme.brightness == Brightness.dark;
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF71717A),
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
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
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: const Color(0xFF09090B),
        onPressed: () => _showQuickActionSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SpotlightBackground(
        primaryGlow: const Color(0xFF10B981),
        secondaryGlow: const Color(0xFF06B6D4),
        child: RefreshIndicator(
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
                // Aceternity Hero Card - Total Outstanding
                ledgerSummaryAsync.when(
                  data: (summary) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        children: [
                          BentoCard(
                            glowColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        'TOTAL OUTSTANDING RECEIVABLES',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (summary.activePeopleCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF27272A),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${summary.activePeopleCount} people owing',
                                          style: const TextStyle(
                                            color: Color(0xFFA1A1AA),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  CurrencyFormatter.format(summary.totalOutstanding, symbol: currencySymbol),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Sub breakdown: Given vs Received Bento row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF27272A).withValues(alpha: 0.5)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.arrow_outward_rounded, size: 14, color: Color(0xFFF43F5E)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Given',
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol),
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
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
                                          color: isDark
                                              ? const Color(0xFF27272A).withValues(alpha: 0.5)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Received',
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol),
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
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
                          const SizedBox(height: 14),

                          // Quick Action Buttons
                          Row(
                            children: [
                              // Receive Payment (Green Glow)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: () => QuickReceiveSheet.show(context),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: const Color(0xFF09090B),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                    label: const Text(
                                      'Quick Receive',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Give Money (Rose Glow)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: () => QuickGiveSheet.show(context),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFF43F5E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                                    label: const Text(
                                      'Give Money',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          'People owing you',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => context.go('/people'),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF10B981)),
                              ],
                            ),
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
                      return BentoCard(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onTap: () => context.push('/people/${debtor.person.id}'),
                        child: Row(
                          children: [
                            AvatarWidget(name: debtor.person.name, radius: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    debtor.person.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (debtor.lastTransaction != null)
                                    Text(
                                      'Last: ${DateFormatter.formatRelative(debtor.lastTransaction!.transactionDate)}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(debtor.balance, symbol: currencySymbol),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFFF43F5E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => QuickReceiveSheet.show(context, personId: debtor.person.id),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFF10B981)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Receive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
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
                      );
                    },
                  ),
                ],

                // Section: Recent Activity
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => context.go('/reports'),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Full History',
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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

                    return BentoCard(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentTxs.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 20,
                          color: isDark ? const Color(0x15FFFFFF) : const Color(0xFFE2E8F0),
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
      ),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x28FFFFFF))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 14),
                child: Text(
                  'Record Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              BentoCard(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QuickGiveSheet.show(context);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_outward_rounded, color: Color(0xFFF43F5E), size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💸 Give Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Record money given or loan advanced', style: TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF71717A)),
                  ],
                ),
              ),
              BentoCard(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QuickReceiveSheet.show(context);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💰 Receive Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Record ad-hoc or installment repayment', style: TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF71717A)),
                  ],
                ),
              ),
              BentoCard(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (c) => const AddEditPersonScreen()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('👤 Add Person', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Add someone new to your ledger', style: TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF71717A)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
