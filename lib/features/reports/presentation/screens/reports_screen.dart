import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

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
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
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
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _filterChip('All Time', ReportDateFilter.allTime),
                const SizedBox(width: 8),
                _filterChip('This Month', ReportDateFilter.thisMonth),
                const SizedBox(width: 8),
                _filterChip('Last Month', ReportDateFilter.lastMonth),
                const SizedBox(width: 8),
                _filterChip('This Year', ReportDateFilter.thisYear),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
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
                    // Tab 1: Overview
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cs.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.15 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _statBox('GIVEN', given, cs.error, cs.surfaceContainer, currencySymbol, context),
                                    const SizedBox(width: 12),
                                    _statBox('RECEIVED', received, cs.primary, cs.surfaceContainer, currencySymbol, context),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Divider(height: 1, color: cs.outlineVariant),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Net Difference',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.0, 0.2),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                      child: Text(
                                        CurrencyFormatter.format(net, symbol: currencySymbol),
                                        key: ValueKey('net-$net'),
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: net > 0
                                              ? cs.error
                                              : net < 0
                                                  ? cs.primary
                                                  : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Breakdown by Person
                          Text(
                            'By Person',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          allSummariesAsync.when(
                            data: (summaries) {
                              if (summaries.isEmpty) {
                                return const Text('No records available');
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: summaries.length,
                                  separatorBuilder: (ctx, i) => Divider(
                                    height: 1,
                                    indent: 68,
                                    endIndent: 16,
                                    color: cs.outlineVariant,
                                  ),
                                  itemBuilder: (ctx, index) {
                                    final s = summaries[index];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: AvatarWidget(name: s.person.name, radius: 20),
                                      title: Text(
                                        s.person.name,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: Text(
                                        'Given: ${CurrencyFormatter.formatCompact(s.totalGiven, symbol: currencySymbol)} Â· Received: ${CurrencyFormatter.formatCompact(s.totalReceived, symbol: currencySymbol)}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                      trailing: Text(
                                        CurrencyFormatter.format(s.balance, symbol: currencySymbol),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: s.balance > 0
                                              ? cs.error
                                              : s.balance < 0
                                                  ? cs.tertiary
                                                  : cs.primary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Text('Error: $err'),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Activity List
                    filteredTxs.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No activity in this period',
                            description: 'Try changing the date range filter above.',
                          )
                        : Container(
                            margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filteredTxs.length,
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: cs.outlineVariant,
                              ),
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

  Widget _filterChip(String label, ReportDateFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _dateFilter == filter,
      onSelected: (_) => setState(() => _dateFilter = filter),
    );
  }

  Widget _statBox(String label, double amount, Color accent, Color bg, String symbol, BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                CurrencyFormatter.format(amount, symbol: symbol),
                key: ValueKey('$label-$amount'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
