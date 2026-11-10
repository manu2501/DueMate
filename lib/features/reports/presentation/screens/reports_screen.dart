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
    final initial = _customDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initial,
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
    final colorScheme = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Audit'),
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
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Summary & Breakdown'),
            Tab(text: 'Filtered Activity'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Bar using Material 3 Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Time'),
                  selected: _dateFilter == ReportDateFilter.allTime,
                  onSelected: (_) => setState(() => _dateFilter = ReportDateFilter.allTime),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Month'),
                  selected: _dateFilter == ReportDateFilter.thisMonth,
                  onSelected: (_) => setState(() => _dateFilter = ReportDateFilter.thisMonth),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Last Month'),
                  selected: _dateFilter == ReportDateFilter.lastMonth,
                  onSelected: (_) => setState(() => _dateFilter = ReportDateFilter.lastMonth),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Year'),
                  selected: _dateFilter == ReportDateFilter.thisYear,
                  onSelected: (_) => setState(() => _dateFilter = ReportDateFilter.thisYear),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    _dateFilter == ReportDateFilter.custom && _customDateRange != null
                        ? '${DateFormatter.formatShortDate(_customDateRange!.start)} - ${DateFormatter.formatShortDate(_customDateRange!.end)}'
                        : 'Custom Range',
                  ),
                  onPressed: _pickCustomRange,
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
                          Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _statBox('GIVEN', given, colorScheme.error, colorScheme.errorContainer, colorScheme.onErrorContainer, currencySymbol, context),
                                      const SizedBox(width: 12),
                                      _statBox('RECEIVED', received, colorScheme.primary, colorScheme.primaryContainer, colorScheme.onPrimaryContainer, currencySymbol, context),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Net Outstanding Shift',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(net, symbol: currencySymbol),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: net > 0
                                              ? colorScheme.error
                                              : net < 0
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Breakdown by Person
                          Text(
                            'Breakdown By Person',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 10),

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
                                    elevation: 0,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: colorScheme.surfaceContainerLow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: AvatarWidget(name: s.person.name, radius: 20),
                                      title: Text(s.person.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                        'Given: ${CurrencyFormatter.formatCompact(s.totalGiven, symbol: currencySymbol)} • Received: ${CurrencyFormatter.formatCompact(s.totalReceived, symbol: currencySymbol)}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      ),
                                      trailing: Text(
                                        CurrencyFormatter.format(s.balance, symbol: currencySymbol),
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: s.balance > 0
                                              ? colorScheme.error
                                              : s.balance < 0
                                                  ? colorScheme.tertiary
                                                  : colorScheme.primary,
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
                            separatorBuilder: (ctx, i) => Divider(
                              height: 1,
                              indent: 72,
                              endIndent: 16,
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            itemBuilder: (ctx, index) {
                              final tx = filteredTxs[index];
                              final person = personsMap[tx.personId];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                                ),
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
    );
  }

  Widget _statBox(String label, double amount, Color accent, Color bg, Color fg, String symbol, BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.format(amount, symbol: symbol),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
