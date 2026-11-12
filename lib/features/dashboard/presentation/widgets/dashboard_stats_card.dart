import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/data/providers/app_providers.dart';

class DashboardStatsCard extends StatelessWidget {
  final DashboardTotals totals;
  final String currencySymbol;

  const DashboardStatsCard({
    super.key,
    required this.totals,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final totalGiven = totals.totalGiven;
    final totalReceived = totals.totalReceived;
    final double progress = totalGiven > 0 ? (totalReceived / totalGiven).clamp(0.0, 1.0) : 1.0;
    final int percentRecovered = (progress * 100).round();
    final netBalance = totals.netBalance;
    final isSurplus = netBalance >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Net Ledger Position Hero Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                    : [const Color(0xFF131438), const Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 20,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Net Ledger Balance',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isSurplus ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isSurplus ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isSurplus ? 'Net Surplus' : 'Net Deficit',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSurplus ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  CurrencyFormatter.format(netBalance.abs(), symbol: currencySymbol),
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 14),

                // Settlement Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settlement Recovery',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkBannerSubtitle,
                      ),
                    ),
                    Text(
                      '$percentRecovered% Collected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFF26274E),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 2. Side-by-Side Breakdown Cards: "You'll Get" & "You Owe"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Card 1: You'll Get (Money given out)
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.south_west_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You\'ll Get',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totals.peopleOweUserCount == 1
                            ? '1 contact owing'
                            : '${totals.peopleOweUserCount} contacts owing',
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
              const SizedBox(width: 14),

              // Card 2: You Owe (Money borrowed/credited)
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
                              color: cs.error.withValues(alpha: 0.12),
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
                              'You Owe',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          color: totals.totalUserOwes > 0 ? cs.error : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totals.peopleUserOwesCount == 1
                            ? '1 contact to pay'
                            : '${totals.peopleUserOwesCount} contacts to pay',
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
      ],
    );
  }
}
