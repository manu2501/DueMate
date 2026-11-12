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
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

enum ReportDateFilter { allTime, thisMonth, lastMonth, thisYear, custom }
enum ActivityTypeFilter { all, ledger, expenses }

class ActivityItem {
  final bool isExpense;
  final DateTime date;
  final LedgerTransaction? transaction;
  final PersonalExpense? expense;

  ActivityItem.transaction(this.transaction)
      : isExpense = false,
        date = transaction!.transactionDate,
        expense = null;

  ActivityItem.expense(this.expense)
      : isExpense = true,
        date = expense!.expenseDate,
        transaction = null;
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  ReportDateFilter _dateFilter = ReportDateFilter.allTime;
  ActivityTypeFilter _typeFilter = ActivityTypeFilter.all;
  PaymentMethod? _paymentMethodFilter;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return '🛒 Groceries';
      case ExpenseCategory.utilities:
        return '⚡ Utilities';
      case ExpenseCategory.rent:
        return '🏠 Rent';
      case ExpenseCategory.fuel:
        return '⛽ Fuel';
      case ExpenseCategory.food:
        return '🍔 Food';
      case ExpenseCategory.shopping:
        return '🛍️ Shopping';
      case ExpenseCategory.entertainment:
        return '🎬 Entertainment';
      case ExpenseCategory.health:
        return '🏥 Health';
      case ExpenseCategory.other:
        return '📦 Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allExpensesAsync = ref.watch(allExpensesProvider);
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final personsMap = ref.watch(personsMapProvider);

    final allTxs = allTxsAsync.value ?? [];
    final allExpenses = allExpensesAsync.value ?? [];
    final query = _searchController.text.trim().toLowerCase();

    // 1. Filter Ledger Transactions
    final filteredTxs = allTxs.where((t) {
      if (!_isDateInRange(t.transactionDate)) return false;
      if (_typeFilter == ActivityTypeFilter.expenses) return false;
      if (_paymentMethodFilter != null && t.paymentMethod != _paymentMethodFilter) return false;

      if (query.isNotEmpty) {
        final person = personsMap[t.personId];
        final nameMatch = person?.name.toLowerCase().contains(query) ?? false;
        final noteMatch = t.note?.toLowerCase().contains(query) ?? false;
        return nameMatch || noteMatch;
      }
      return true;
    }).toList();

    // 2. Filter Personal Expenses
    final filteredExpenses = allExpenses.where((e) {
      if (!_isDateInRange(e.expenseDate)) return false;
      if (_typeFilter == ActivityTypeFilter.ledger) return false;
      if (_paymentMethodFilter != null && e.paymentMethod != _paymentMethodFilter) return false;

      if (query.isNotEmpty) {
        final titleMatch = e.title.toLowerCase().contains(query);
        final notesMatch = e.notes?.toLowerCase().contains(query) ?? false;
        final catMatch = _getCategoryName(e.category).toLowerCase().contains(query);
        return titleMatch || notesMatch || catMatch;
      }
      return true;
    }).toList();

    // 3. Combine into Unified Activity Timeline
    final List<ActivityItem> activityTimeline = [
      ...filteredTxs.map((t) => ActivityItem.transaction(t)),
      ...filteredExpenses.map((e) => ActivityItem.expense(e)),
    ];
    activityTimeline.sort((a, b) => b.date.compareTo(a.date));

    // Stats calculations
    double totalGiven = 0;
    double totalReceived = 0;
    for (final tx in filteredTxs) {
      if (tx.type == TransactionType.moneyGiven) {
        totalGiven += tx.amount;
      } else {
        totalReceived += tx.amount;
      }
    }
    double totalPersonalExpenses = 0;
    for (final e in filteredExpenses) {
      totalPersonalExpenses += e.amount;
    }
    final totalVolume = totalGiven + totalReceived + totalPersonalExpenses;

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
                            'Transactions & Outflows',
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF131438),
                            ),
                          ),
                          Text(
                            '${activityTimeline.length} Items • ${CurrencyFormatter.formatCompact(totalVolume, symbol: currencySymbol)} Total Volume',
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
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: SearchBar(
              controller: _searchController,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerLow),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
              ),
              hintText: 'Search title, contact, or notes...',
              hintStyle: WidgetStatePropertyAll(
                TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
              ),
              leading: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Multi-Filter Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                // Type Filter Chips
                ChoiceChip(
                  label: const Text('All Types'),
                  selected: _typeFilter == ActivityTypeFilter.all,
                  onSelected: (_) => setState(() => _typeFilter = ActivityTypeFilter.all),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Ledger Dues'),
                  selected: _typeFilter == ActivityTypeFilter.ledger,
                  onSelected: (_) => setState(() => _typeFilter = ActivityTypeFilter.ledger),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Personal Expenses'),
                  selected: _typeFilter == ActivityTypeFilter.expenses,
                  onSelected: (_) => setState(() => _typeFilter = ActivityTypeFilter.expenses),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: cs.outlineVariant),
                const SizedBox(width: 12),

                // Date Filter Chips
                _filterChip('All Time', ReportDateFilter.allTime),
                const SizedBox(width: 6),
                _filterChip('This Month', ReportDateFilter.thisMonth),
                const SizedBox(width: 6),
                _filterChip('Last Month', ReportDateFilter.lastMonth),
                const SizedBox(width: 6),
                _filterChip('This Year', ReportDateFilter.thisYear),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
                  label: Text(
                    _dateFilter == ReportDateFilter.custom && _customDateRange != null
                        ? '${DateFormatter.formatShortDate(_customDateRange!.start)} - ${DateFormatter.formatShortDate(_customDateRange!.end)}'
                        : 'Custom Range',
                  ),
                  onPressed: _pickCustomRange,
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: cs.outlineVariant),
                const SizedBox(width: 12),

                // Payment Mode Filter Chips
                ChoiceChip(
                  label: const Text('All Modes'),
                  selected: _paymentMethodFilter == null,
                  onSelected: (_) => setState(() => _paymentMethodFilter = null),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('UPI'),
                  selected: _paymentMethodFilter == PaymentMethod.upi,
                  onSelected: (_) => setState(() => _paymentMethodFilter = PaymentMethod.upi),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _paymentMethodFilter == PaymentMethod.cash,
                  onSelected: (_) => setState(() => _paymentMethodFilter = PaymentMethod.cash),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Card'),
                  selected: _paymentMethodFilter == PaymentMethod.card,
                  onSelected: (_) => setState(() => _paymentMethodFilter = PaymentMethod.card),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Bank Transfer'),
                  selected: _paymentMethodFilter == PaymentMethod.bankTransfer,
                  onSelected: (_) => setState(() => _paymentMethodFilter = PaymentMethod.bankTransfer),
                ),
              ],
            ),
          ),

          // Cashflow Overview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  _statBox('LENT / GIVEN', totalGiven, cs.error, cs.surfaceContainer, currencySymbol, context),
                  const SizedBox(width: 8),
                  _statBox('RECEIVED', totalReceived, const Color(0xFF10B981), cs.surfaceContainer, currencySymbol, context),
                  const SizedBox(width: 8),
                  _statBox('EXPENSES', totalPersonalExpenses, const Color(0xFFF59E0B), cs.surfaceContainer, currencySymbol, context),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: allTxsAsync.when(
              data: (_) {
                // Group filtered transactions by personId for Tab 2
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
                    // Tab 1: Activity Timeline (Ledger + Personal Expenses)
                    activityTimeline.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No activity matching filters',
                            description: 'Try adjusting your search query, type, or date filters above.',
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
                              itemCount: activityTimeline.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: cs.outlineVariant.withValues(alpha: 0.6),
                              ),
                              itemBuilder: (ctx, index) {
                                final item = activityTimeline[index];
                                if (!item.isExpense) {
                                  final tx = item.transaction!;
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
                                } else {
                                  final expense = item.expense!;
                                  return FadeSlideTransition(
                                    index: index,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          _getCategoryName(expense.category).split(' ').first,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      title: Text(
                                        expense.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF131438),
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Personal Expense • ${DateFormatter.formatRelative(expense.expenseDate)}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                      trailing: Text(
                                        '-${CurrencyFormatter.format(expense.amount, symbol: currencySymbol)}',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: cs.error,
                                        ),
                                      ),
                                      onTap: () => AddEditExpenseSheet.show(context, expenseToEdit: expense),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),

                    // Tab 2: By Person Breakdown
                    filteredPersonSummaries.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.people_outline_rounded,
                            title: 'No contact activity matching filters',
                            description: 'Try adjusting your search query or filters above.',
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
        padding: const EdgeInsets.all(10),
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
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatCompact(amount, symbol: symbol),
              style: GoogleFonts.dmSans(
                fontSize: 15,
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
