import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person_summary.dart';
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

    // Repayment / recovery progress
    final double totalGiven = totals.totalGiven;
    final double totalReceived = totals.totalReceived;
    final double progress = totalGiven > 0
        ? (totalReceived / totalGiven).clamp(0.0, 1.0)
        : (totals.totalTheyOwe == 0 ? 1.0 : 0.0);
    final int percentRecovered = (progress * 100).toInt();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // User Avatar on Left
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const AvatarWidget(
                      name: 'DueMate User',
                      radius: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Center Branding: Icon + DueMate
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppConstants.appName,
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                      ),
                    ],
                  ),
                ),

                // Notification / Action Icon on Right
                InkWell(
                  onTap: () => _showQuickActionSheet(context),
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: cs.onSurface,
                        ),
                        Positioned(
                          top: 10,
                          right: 11,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Lift FAB comfortably above the floating dock navigation bar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => _showQuickActionSheet(context),
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

              // 1. Repayment / Settlement Progress Card (Replaces Congratulations message)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBannerBackground,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24131438),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF26274E),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.donut_large_rounded,
                              size: 22,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settlement Progress',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  totalGiven > 0
                                      ? '$percentRecovered% of total lent funds collected'
                                      : 'All accounts balanced & settled',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.darkBannerSubtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF26274E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$percentRecovered%',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: const Color(0xFF26274E),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Stats row inside card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Collected: ${CurrencyFormatter.format(totalReceived, symbol: currencySymbol)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFB4B3D4),
                            ),
                          ),
                          Text(
                            'Outstanding: ${CurrencyFormatter.format(totals.totalTheyOwe, symbol: currencySymbol)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFB4B3D4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Core Dashboard Cards: "They Owe You" & "You Owe"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Card 1: They Owe You (Money owed to user)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.south_west_rounded,
                                    size: 14,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "They owe you",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.mutedLabel,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              CurrencyFormatter.format(totals.totalTheyOwe, symbol: currencySymbol),
                              style: GoogleFonts.dmSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : const Color(0xFF131438),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totals.peopleOweUserCount == 1
                                  ? '1 person owing'
                                  : '${totals.peopleOweUserCount} people owing',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Card 2: You Owe (Money user owes to others)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cs.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.north_east_rounded,
                                    size: 14,
                                    color: cs.error,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "You owe",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.mutedLabel,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              CurrencyFormatter.format(totals.totalUserOwes, symbol: currencySymbol),
                              style: GoogleFonts.dmSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: totals.totalUserOwes > 0
                                    ? cs.error
                                    : (isDark ? Colors.white : const Color(0xFF131438)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totals.peopleUserOwesCount == 1
                                  ? '1 person to pay'
                                  : '${totals.peopleUserOwesCount} people to pay',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Prominent On-Page Quick Record Shortcuts (Always visible and reachable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => QuickReceiveSheet.show(context),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.south_west_rounded, size: 17, color: cs.primary),
                            const SizedBox(width: 6),
                            const Text('Receive Money'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => QuickGiveSheet.show(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.north_east_rounded, size: 17),
                            SizedBox(width: 6),
                            Text('Give Money'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Section: Top 5 Users (Based on amount owed / user owes) + "Show all" button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top Dues',
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      label: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // List of Top 5 Users
              if (topPeople.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: topPeople.map((personSummary) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildUserDueCard(
                          context: context,
                          summary: personSummary,
                          currencySymbol: currencySymbol,
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                // Empty state when no people have active balances
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF131438),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Everyone in your ledger is settled up. Tap below to record a new loan or advance.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
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
                                'Add someone to directory',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, size: 18, color: cs.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 4. Section: Recent Transactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
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
                      description: 'Tap Give or Receive to record your first ledger entry.',
                      actionLabel: 'Add Person',
                      onActionPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
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
                      separatorBuilder: (ctx, i) => Divider(
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

  // Two-column Card styled directly after the screenshot
  Widget _buildUserDueCard({
    required BuildContext context,
    required PersonSummary summary,
    required String currencySymbol,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    final owesMoney = summary.balance > 0.0001;
    final labelText = owesMoney ? 'Owes you' : 'You owe';
    final amountColor = owesMoney
        ? (isDark ? Colors.white : const Color(0xFF131438))
        : cs.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Two Columns ("Owes / Amount" and "Contact / Status")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Column: Amount & Direction
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: owesMoney ? AppTheme.mutedLabel : cs.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(summary.balance.abs(), symbol: currencySymbol),
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: amountColor,
                    ),
                  ),
                ],
              ),

              // Right Column: Borrower / Contact Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: owesMoney
                          ? cs.primary.withValues(alpha: 0.1)
                          : cs.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      owesMoney ? 'Pending' : 'To Pay',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: owesMoney ? cs.primary : cs.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarWidget(
                        name: summary.person.name,
                        radius: 12,
                        heroTag: 'avatar-dash-${summary.person.id}',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        summary.person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 12),

          // Bottom Action Row: "View ledger & record payment ->"
          InkWell(
            onTap: () => context.push('/people/${summary.person.id}'),
            child: Row(
              children: [
                Text(
                  'View ledger & record payment',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: cs.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
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
                  Navigator.of(ctx).pop();
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
                  Navigator.of(ctx).pop();
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
                    color: cs.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add_outlined, color: cs.secondary),
                ),
                title: const Text('Add Person'),
                subtitle: const Text('Create a new contact in your ledger'),
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
