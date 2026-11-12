import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/dashboard/presentation/widgets/dashboard_quick_action_sheet.dart';
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
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                      ),
                      Text(
                        '${AppConstants.appName} • 100% Private Offline Vault',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Icon Button
                InkWell(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // FAB comfortably above floating dock navbar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => DashboardQuickActionSheet.show(context),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            'New Entry',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
          padding: const EdgeInsets.only(bottom: 160),
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
                      'Top Active Dues',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF131438),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/people'),
                      icon: Text(
                        'Show all',
                        style: GoogleFonts.inter(
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
                  height: 145,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: topPeople.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return DashboardTopDuesCard(
                        summary: topPeople[index],
                        currencySymbol: currencySymbol,
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
                          'No pending dues',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF131438),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Everyone in your ledger is settled up. Tap below to record a new loan or advance.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                'Add contact to ledger',
                                style: GoogleFonts.inter(
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
                                  'Upcoming EMIs & Loans',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: isDark ? Colors.white : const Color(0xFF131438),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${activeEmis.length}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purple,
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
                      'Recent Activity',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF131438),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: Text(
                        'View all',
                        style: GoogleFonts.inter(
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
                      title: 'No transactions yet',
                      description: 'Tap Give or Receive above to record your first entry.',
                      actionLabel: 'Add Person',
                      onActionPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddEditPersonScreen()),
                        );
                      },
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
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
