import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
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
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Statements', style: TextStyle(fontWeight: FontWeight.bold)),
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
          tabs: const [
            Tab(text: 'Summary & Breakdown'),
            Tab(text: 'Filtered Activity'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _chip('All Time', ReportDateFilter.allTime),
                const SizedBox(width: 8),
                _chip('This Month', ReportDateFilter.thisMonth),
                const SizedBox(width: 8),
                _chip('Last Month', ReportDateFilter.lastMonth),
                const SizedBox(width: 8),
                _chip('This Year', ReportDateFilter.thisYear),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(_dateFilter == ReportDateFilter.custom && _customDateRange != null
                      ? '${DateFormatter.formatShortDate(_customDateRange!.start)} - ${DateFormatter.formatShortDate(_customDateRange!.end)}'
                      : 'Custom Range'),
                  backgroundColor: _dateFilter == ReportDateFilter.custom
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : null,
                  onPressed: _pickCustomRange,
                  visualDensity: VisualDensity.compact,
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
                          // Overview Stats Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _statBox('Given', given, const Color(0xFFDC2626), currencySymbol),
                                    const SizedBox(width: 12),
                                    _statBox('Received', received, const Color(0xFF16A34A), currencySymbol),
                                  ],
                                ),
                                const Divider(height: 28),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Outstanding Change', style: TextStyle(fontWeight: FontWeight.w500)),
                                    Text(
                                      CurrencyFormatter.format(net, symbol: currencySymbol),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: net > 0
                                            ? const Color(0xFFDC2626)
                                            : net < 0
                                                ? const Color(0xFF16A34A)
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
                          Text(
                            'Breakdown By Person',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          allSummariesAsync.when(
                            data: (summaries) {
                              if (summaries.isEmpty) {
                                return const Text('No records available');
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: summaries.length,
                                itemBuilder: (ctx, index) {
                                  final s = summaries[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: AvatarWidget(name: s.person.name, radius: 18),
                                      title: Text(s.person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        'Given: ${CurrencyFormatter.formatCompact(s.totalGiven, symbol: currencySymbol)} • Received: ${CurrencyFormatter.formatCompact(s.totalReceived, symbol: currencySymbol)}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: Text(
                                        CurrencyFormatter.format(s.balance, symbol: currencySymbol),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: s.balance > 0
                                              ? const Color(0xFFDC2626)
                                              : s.balance < 0
                                                  ? const Color(0xFF9333EA)
                                                  : const Color(0xFF16A34A),
                                        ),
                                      ),
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
                            separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 72, endIndent: 20),
                            itemBuilder: (ctx, index) {
                              final tx = filteredTxs[index];
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
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, ReportDateFilter filter) {
    final isSelected = _dateFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _dateFilter = filter);
      },
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _statBox(String label, double amount, Color color, String symbol) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount, symbol: symbol),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
