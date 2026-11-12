import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/fade_slide_transition.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/dashboard/presentation/widgets/dashboard_quick_actions_bar.dart';
import 'package:duemate/features/dashboard/presentation/widgets/dashboard_stats_card.dart';
import 'package:duemate/features/dashboard/presentation/widgets/dashboard_top_dues_card.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await PermissionManager.checkAndPromptOnStartupOrUpdate(context);
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final totals = ref.watch(dashboardTotalsProvider);
    final topPeople = ref.watch(topPeopleByBalanceProvider);
    final recentTxAsync = ref.watch(recentTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);
    final activeEmisAsync = ref.watch(activeEmisProvider);

    // Auto-process any pending EMI installments on app open/build
    ref.watch(emiAutoProcessorProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getGreeting(),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allPersonSummariesProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // 1. Net Ledger Position & Recovery Card
              DashboardStatsCard(
                totals: totals,
                currencySymbol: currencySymbol,
              ),

              const SizedBox(height: 20),

              // 2. Prominent Quick Actions Dock Bar
              const DashboardQuickActionsBar(),

              const SizedBox(height: 24),

              // 3. Active Dues Carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Largest balances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/people'),
                      icon: Text(
                        'Show all',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      label: Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (topPeople.isNotEmpty)
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: topPeople.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return FadeSlideTransition(
                        index: index,
                        child: DashboardTopDuesCard(
                          summary: topPeople[index],
                          currencySymbol: currencySymbol,
                        ),
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All settled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nobody owes you and you owe nobody.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => AddEditPersonScreen.show(context),
                          child: Row(
                            children: [
                              Text(
                                'Add a person',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, size: 16, color: cs.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Active EMIs Section
              activeEmisAsync.when(
                data: (activeEmis) {
                  if (activeEmis.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'EMIs and loans',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${activeEmis.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => AddEditEmiScreen.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add EMI'),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: activeEmis.map((emi) {
                            final person = personsMap[emi.personId];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: EmiCard(
                                emi: emi,
                                person: person,
                                currencySymbol: currencySymbol,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // 5. Recent Activity Feed
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              recentTxAsync.when(
                data: (recentTxs) {
                  if (recentTxs.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No activity yet',
                      description: 'Use Give or Receive above to record your first entry.',
                      actionLabel: 'Add a person',
                      onActionPressed: () => AddEditPersonScreen.show(context),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTxs.length > 5 ? 5 : recentTxs.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.6),
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
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => const Center(child: Text("Couldn't load this. Please try again.")),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
