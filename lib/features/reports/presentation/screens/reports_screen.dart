import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/pdf_exporter.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/export_options_sheet.dart';
import 'package:duemate/core/widgets/fade_slide_transition.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person_summary.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    final allTxs = allTxsAsync.value ?? [];
    final filteredTxs = allTxs.where((t) => _isDateInRange(t.transactionDate)).toList();

    double totalGiven = 0;
    double totalReceived = 0;
    for (final tx in filteredTxs) {
      if (tx.type == TransactionType.moneyGiven) {
        totalGiven += tx.amount;
      } else {
        totalReceived += tx.amount;
      }
    }
    final netBalance = totalGiven - totalReceived;
    final totalVolume = totalGiven + totalReceived;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(112),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Transactions',
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF131438),
                            ),
                          ),
                          Text(
                            '${filteredTxs.length} Transactions • ${CurrencyFormatter.formatCompact(totalVolume, symbol: currencySymbol)} Volume',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Share Report',
                      icon: const Icon(Icons.share_outlined, size: 18),
                      onPressed: () {
                        final filterName = switch (_dateFilter) {
                          ReportDateFilter.allTime => 'All Time',
                          ReportDateFilter.thisMonth => 'This Month',
                          ReportDateFilter.lastMonth => 'Last Month',
                          ReportDateFilter.thisYear => 'This Year',
                          ReportDateFilter.custom => 'Custom Range',
                        };

                        ExportOptionsSheet.show(
                          context: context,
                          title: 'Share Activity Report ($filterName)',
                          onSharePdf: () => PdfExporter.exportAndShareAllTransactions(
                            transactions: filteredTxs,
                            personsMap: personsMap,
                            currencySymbol: currencySymbol,
                            filterTitle: filterName,
                          ),
                          onShareCsv: () => CsvExporter.exportAndShareAllTransactions(
                            transactions: filteredTxs,
                            personsMap: personsMap,
                            currencySymbol: currencySymbol,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Activity Feed'),
                  Tab(text: 'By Person'),
                ],
              ),
            ],
          ),
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

          // Cashflow Overview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                children: [
                  Row(
                    children: [
                      _statBox('TOTAL GIVEN', totalGiven, cs.error, cs.surfaceContainer, currencySymbol, context),
                      const SizedBox(width: 12),
                      _statBox('TOTAL RECEIVED', totalReceived, const Color(0xFF10B981), cs.surfaceContainer, currencySymbol, context),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Difference',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(netBalance, symbol: currencySymbol),
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: netBalance > 0
                              ? cs.error
                              : netBalance < 0
                                  ? const Color(0xFF10B981)
                                  : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: allTxsAsync.when(
              data: (_) {
                // Group filtered transactions by personId to update breakdown as per filters
                final Map<String, ({double given, double received, LedgerTransaction? lastTx, int count})> personStats = {};
                for (final tx in filteredTxs) {
                  final current = personStats[tx.personId];
                  final isGiven = tx.type == TransactionType.moneyGiven;
                  final g = (current?.given ?? 0.0) + (isGiven ? tx.amount : 0.0);
                  final r = (current?.received ?? 0.0) + (!isGiven ? tx.amount : 0.0);
                  final last = current?.lastTx == null || tx.transactionDate.isAfter(current!.lastTx!.transactionDate)
                      ? tx
                      : current.lastTx;
                  final c = (current?.count ?? 0) + 1;
                  personStats[tx.personId] = (given: g, received: r, lastTx: last, count: c);
                }

                final List<PersonSummary> filteredPersonSummaries = [];
                for (final entry in personStats.entries) {
                  final person = personsMap[entry.key];
                  if (person != null) {
                    filteredPersonSummaries.add(
                      PersonSummary(
                        person: person,
                        totalGiven: entry.value.given,
                        totalReceived: entry.value.received,
                        balance: entry.value.given - entry.value.received,
                        lastTransaction: entry.value.lastTx,
                        transactionCount: entry.value.count,
                      ),
                    );
                  }
                }

                if (_dateFilter == ReportDateFilter.allTime) {
                  final allSummaries = allSummariesAsync.value ?? [];
                  for (final s in allSummaries) {
                    if (!personStats.containsKey(s.person.id)) {
                      filteredPersonSummaries.add(s);
                    }
                  }
                }

                filteredPersonSummaries.sort((a, b) {
                  final volumeA = a.totalGiven + a.totalReceived;
                  final volumeB = b.totalGiven + b.totalReceived;
                  final cmp = volumeB.compareTo(volumeA);
                  if (cmp != 0) return cmp;
                  return a.person.name.compareTo(b.person.name);
                });

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Activity Timeline
                    filteredTxs.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No activity in this period',
                            description: 'Try changing the date range filter above.',
                          )
                        : Container(
                            margin: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filteredTxs.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: cs.outlineVariant.withValues(alpha: 0.6),
                              ),
                              itemBuilder: (ctx, index) {
                                final tx = filteredTxs[index];
                                final person = personsMap[tx.personId];
                                return FadeSlideTransition(
                                  index: index,
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
                          ),

                    // Tab 2: By Person Breakdown
                    filteredPersonSummaries.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.people_outline_rounded,
                            title: 'No contact activity in this period',
                            description: 'Try selecting another date filter above.',
                          )
                        : Container(
                            margin: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filteredPersonSummaries.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: cs.outlineVariant.withValues(alpha: 0.6),
                              ),
                              itemBuilder: (ctx, index) {
                                final s = filteredPersonSummaries[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: AvatarWidget(name: s.person.name, radius: 20),
                                  title: Text(
                                    s.person.name,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    'Given: ${CurrencyFormatter.formatCompact(s.totalGiven, symbol: currencySymbol)} • Received: ${CurrencyFormatter.formatCompact(s.totalReceived, symbol: currencySymbol)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  trailing: Text(
                                    CurrencyFormatter.format(s.balance, symbol: currencySymbol),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: s.balance > 0.001
                                          ? cs.error
                                          : s.balance < -0.001
                                              ? const Color(0xFF10B981)
                                              : cs.primary,
                                    ),
                                  ),
                                  onTap: () => context.push('/people/${s.person.id}'),
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
        padding: const EdgeInsets.all(12),
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
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount, symbol: symbol),
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
