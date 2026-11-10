import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/bento_card.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/spotlight_background.dart';
import 'package:smarava/core/widgets/transaction_tile.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/features/transactions/presentation/widgets/transaction_details_dialog.dart';

enum ReportDateFilter { allTime, thisMonth, lastMonth, thisYear, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportDateFilter _dateFilter = ReportDateFilter.allTime;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isDateInRange(DateTime date) {
    final now = DateTime.now();

    switch (_dateFilter) {
      case ReportDateFilter.allTime:
        return true;
      case ReportDateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ReportDateFilter.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        return date.year == lastMonthDate.year && date.month == lastMonthDate.month;
      case ReportDateFilter.thisYear:
        return date.year == now.year;
      case ReportDateFilter.custom:
        if (_customDateRange == null) return true;
        return date.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = ReportDateFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Audit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final txs = allTxsAsync.value ?? [];
              final filteredTxs = txs.where((t) => _isDateInRange(t.transactionDate)).toList();
              CsvExporter.exportAndShareAllTransactions(
                transactions: filteredTxs,
                personsMap: personsMap,
                currencySymbol: currencySymbol,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF71717A),
          tabs: const [
            Tab(text: 'Summary & Breakdown'),
            Tab(text: 'Filtered Activity'),
          ],
        ),
      ),
      body: SpotlightBackground(
        primaryGlow: const Color(0xFF06B6D4),
        secondaryGlow: const Color(0xFF10B981),
        child: Column(
          children: [
            // Date Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _datePill('All Time', ReportDateFilter.allTime, isDark),
                  const SizedBox(width: 8),
                  _datePill('This Month', ReportDateFilter.thisMonth, isDark),
                  const SizedBox(width: 8),
                  _datePill('Last Month', ReportDateFilter.lastMonth, isDark),
                  const SizedBox(width: 8),
                  _datePill('This Year', ReportDateFilter.thisYear, isDark),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _pickCustomRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _dateFilter == ReportDateFilter.custom
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : isDark
                                ? const Color(0xFF18181B)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _dateFilter == ReportDateFilter.custom ? const Color(0xFF10B981) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            _dateFilter == ReportDateFilter.custom && _customDateRange != null
                                ? '${DateFormatter.formatShortDate(_customDateRange!.start)} - ${DateFormatter.formatShortDate(_customDateRange!.end)}'
                                : 'Custom',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _dateFilter == ReportDateFilter.custom ? const Color(0xFF10B981) : const Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: allTxsAsync.when(
                data: (allTxs) {
                  final filteredTxs = allTxs.where((t) => _isDateInRange(t.transactionDate)).toList();

                  double given = 0;
                  double received = 0;
                  for (final tx in filteredTxs) {
                    if (tx.type == TransactionType.moneyGiven) {
                      given += tx.amount;
                    } else {
                      received += tx.amount;
                    }
                  }
                  final net = given - received;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Summary & Breakdown by Person
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overview Stats Bento Card
                            BentoCard(
                              glowColor: const Color(0xFF06B6D4),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _statBox('GIVEN', given, const Color(0xFFF43F5E), currencySymbol, isDark),
                                      const SizedBox(width: 12),
                                      _statBox('RECEIVED', received, const Color(0xFF10B981), currencySymbol, isDark),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Divider(height: 1, color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0)),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Net Outstanding Shift',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(net, symbol: currencySymbol),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: net > 0
                                              ? const Color(0xFFF43F5E)
                                              : net < 0
                                                  ? const Color(0xFF10B981)
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Breakdown by Person
                            const Text(
                              'Breakdown By Person',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 12),

                            allSummariesAsync.when(
                              data: (summaries) {
                                if (summaries.isEmpty) {
                                  return const Text('No records available', style: TextStyle(color: Color(0xFF71717A)));
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: summaries.length,
                                  itemBuilder: (ctx, index) {
                                    final s = summaries[index];
                                    return BentoCard(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          AvatarWidget(name: s.person.name, radius: 18),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(s.person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text(
                                                  'Given: ${CurrencyFormatter.formatCompact(s.totalGiven, symbol: currencySymbol)} • Received: ${CurrencyFormatter.formatCompact(s.totalReceived, symbol: currencySymbol)}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.format(s.balance, symbol: currencySymbol),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: s.balance > 0
                                                  ? const Color(0xFFF43F5E)
                                                  : s.balance < 0
                                                      ? const Color(0xFF8B5CF6)
                                                      : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Text('Error: $err'),
                            ),
                          ],
                        ),
                      ),

                      // Tab 2: Filtered Activity List
                      filteredTxs.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.filter_list_off_rounded,
                              title: 'No activity in this period',
                              description: 'No transactions found for the selected date range.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: filteredTxs.length,
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                indent: 72,
                                endIndent: 20,
                                color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                              ),
                              itemBuilder: (ctx, index) {
                                final tx = filteredTxs[index];
                                final person = personsMap[tx.personId];
                                return BentoCard(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: EdgeInsets.zero,
                                  child: TransactionTile(
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
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePill(String label, ReportDateFilter filter, bool isDark) {
    final isSelected = _dateFilter == filter;
    return InkWell(
      onTap: () => setState(() => _dateFilter = filter),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : isDark
                  ? const Color(0xFF18181B)
                  : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, double amount, Color color, String symbol, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount, symbol: symbol),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
