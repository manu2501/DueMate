import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/pdf_exporter.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/export_options_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
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

/// Everything that happened, newest first: ledger entries and expenses in
/// one timeline, with search and filters.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _searchController = TextEditingController();

  // This month by default: totals for all time say little at a glance.
  ReportDateFilter _dateFilter = ReportDateFilter.thisMonth;
  ActivityTypeFilter _typeFilter = ActivityTypeFilter.all;
  PaymentMethod? _methodFilter;
  DateTimeRange? _customRange;

  static const _typeLabels = {
    ActivityTypeFilter.all: 'Everything',
    ActivityTypeFilter.ledger: 'Lending',
    ActivityTypeFilter.expenses: 'Expenses',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _periodLabel => switch (_dateFilter) {
        ReportDateFilter.allTime => 'All time',
        ReportDateFilter.thisMonth => 'This month',
        ReportDateFilter.lastMonth => 'Last month',
        ReportDateFilter.thisYear => 'This year',
        ReportDateFilter.custom => _customRange == null
            ? 'Custom'
            : '${DateFormatter.formatShortDate(_customRange!.start)} – ${DateFormatter.formatShortDate(_customRange!.end)}',
      };

  bool _inPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case ReportDateFilter.allTime:
        return true;
      case ReportDateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ReportDateFilter.lastMonth:
        final last = DateTime(now.year, now.month - 1, 1);
        return date.year == last.year && date.month == last.month;
      case ReportDateFilter.thisYear:
        return date.year == now.year;
      case ReportDateFilter.custom:
        final r = _customRange;
        if (r == null) return true;
        return !date.isBefore(r.start) && date.isBefore(r.end.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickPeriod() async {
    final choice = await showModalBottomSheet<ReportDateFilter>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ReportDateFilter>(
          groupValue: _dateFilter,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in ReportDateFilter.values)
                RadioListTile<ReportDateFilter>(
                  value: f,
                  title: Text(switch (f) {
                    ReportDateFilter.allTime => 'All time',
                    ReportDateFilter.thisMonth => 'This month',
                    ReportDateFilter.lastMonth => 'Last month',
                    ReportDateFilter.thisYear => 'This year',
                    ReportDateFilter.custom => 'Pick dates…',
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == ReportDateFilter.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: _customRange ??
            DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      );
      if (picked == null) return;
      setState(() {
        _customRange = picked;
        _dateFilter = ReportDateFilter.custom;
      });
    } else {
      setState(() => _dateFilter = choice);
    }
  }

  /// Type and payment method, the filters used less often, together in one
  /// sheet. Changes apply as you tap.
  int get _activeFilters => (_typeFilter != ActivityTypeFilter.all ? 1 : 0) + (_methodFilter != null ? 1 : 0);

  Future<void> _openFilters() {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          final theme = Theme.of(ctx);
          Widget heading(String text) => Padding(
                padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
                child: Text(text, style: theme.textTheme.titleSmall),
              );
          Widget choice(String label, bool selected, VoidCallback onTap) =>
              ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => update(onTap));

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, 0, AppSpace.screenGutter, AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Filters', style: theme.textTheme.titleLarge)),
                      if (_activeFilters > 0)
                        TextButton(
                          onPressed: () => update(() {
                            _typeFilter = ActivityTypeFilter.all;
                            _methodFilter = null;
                          }),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  heading('Show'),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final e in _typeLabels.entries)
                        choice(e.value, _typeFilter == e.key, () => _typeFilter = e.key),
                    ],
                  ),
                  heading('Paid with'),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      choice('Any', _methodFilter == null, () => _methodFilter = null),
                      for (final m in PaymentMethodX.ordered) choice(m.label, _methodFilter == m, () => _methodFilter = m),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final people = ref.watch(personsMapProvider);
    final allTxs = ref.watch(allTransactionsProvider).value ?? const <LedgerTransaction>[];
    final allExpenses = ref.watch(allExpensesProvider).value ?? const <PersonalExpense>[];
    final query = _searchController.text.trim().toLowerCase();

    final txs = allTxs.where((t) {
      if (_typeFilter == ActivityTypeFilter.expenses) return false;
      if (!_inPeriod(t.transactionDate)) return false;
      if (_methodFilter != null && t.paymentMethod != _methodFilter) return false;
      if (query.isEmpty) return true;
      final name = people[t.personId]?.name.toLowerCase() ?? '';
      return name.contains(query) || (t.note?.toLowerCase().contains(query) ?? false);
    }).toList();

    final expenses = allExpenses.where((e) {
      if (_typeFilter == ActivityTypeFilter.ledger) return false;
      if (!_inPeriod(e.expenseDate)) return false;
      if (_methodFilter != null && e.paymentMethod != _methodFilter) return false;
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          (e.notes?.toLowerCase().contains(query) ?? false) ||
          e.category.label.toLowerCase().contains(query);
    }).toList();

    final items = [
      ...txs.map(ActivityItem.transaction),
      ...expenses.map(ActivityItem.expense),
    ]..sort((a, b) => b.date.compareTo(a.date));

    double moneyIn = 0, moneyOut = 0, spent = 0;
    for (final t in txs) {
      t.type == TransactionType.paymentReceived ? moneyIn += t.amount : moneyOut += t.amount;
    }
    for (final e in expenses) {
      spent += e.amount;
    }

    final byDay = <DateTime, List<ActivityItem>>{};
    for (final i in items) {
      byDay.putIfAbsent(DateTime(i.date.year, i.date.month, i.date.day), () => []).add(i);
    }

    void export() => ExportOptionsSheet.show(
          context: context,
          title: 'Share activity ($_periodLabel)',
          onSharePdf: () => PdfExporter.exportAndShareAllTransactions(
            transactions: txs,
            personsMap: people,
            currencySymbol: symbol,
            filterTitle: _periodLabel,
          ),
          onShareCsv: () => CsvExporter.exportAndShareAllTransactions(
            transactions: txs,
            personsMap: people,
            currencySymbol: symbol,
          ),
        );

    Widget figure(String label, double v, MoneyTone tone, String sign) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              MoneyText(v, symbol: symbol, tone: v == 0 ? MoneyTone.muted : tone, sign: v == 0 ? '' : sign),
            ],
          ),
        );

    return TabScaffold(
      title: 'Activity',
      actions: [
        IconButton(tooltip: 'Share or export', icon: const Icon(Icons.ios_share_rounded), onPressed: export),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search people, notes or expenses',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_searchController.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
            child: Row(
              children: [
                // The period stays in view: the totals below depend on it.
                _MenuChip(label: _periodLabel, onTap: _pickPeriod),
                const SizedBox(width: AppSpace.sm),
                FilterChip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(_activeFilters == 0 ? 'Filters' : 'Filters · $_activeFilters'),
                  selected: _activeFilters > 0,
                  showCheckmark: false,
                  onSelected: (_) => _openFilters(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.lg, AppSpace.screenGutter, 0),
            child: Row(
              children: [
                figure('Money in', moneyIn, MoneyTone.positive, '+'),
                figure('Money out', moneyOut, MoneyTone.neutral, '−'),
                figure('Spent', spent, MoneyTone.neutral, '−'),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: query.isEmpty ? Icons.receipt_long_outlined : Icons.search_off_rounded,
              title: query.isEmpty ? 'Nothing in this period' : 'Nothing matches "${_searchController.text}"',
              description: 'Try a different period, type or search.',
            ),
          )
        else
          for (final entry in byDay.entries) ...[
            SliverToBoxAdapter(child: DateHeader(entry.key)),
            SliverToBoxAdapter(
              child: GroupCard(
                children: [
                  for (final item in entry.value)
                    if (item.isExpense)
                      ListTile(
                        onTap: () => AddEditExpenseSheet.show(context, expenseToEdit: item.expense),
                        leading: IconBadge(item.expense!.category.icon),
                        title: Text(item.expense!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('Expense · ${item.expense!.category.label}'),
                        trailing: MoneyText(item.expense!.amount, symbol: symbol, sign: '−'),
                      )
                    else
                      TransactionTile(
                        transaction: item.transaction!,
                        person: people[item.transaction!.personId],
                        currencySymbol: symbol,
                        showDate: false,
                        onTap: () => TransactionDetailsDialog.show(
                          context,
                          transaction: item.transaction!,
                          person: item.transaction!.personId == AppConstants.selfPersonId
                              ? null
                              : people[item.transaction!.personId],
                        ),
                      ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// A chip that opens a choice sheet and shows the current choice.
class _MenuChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ],
      ),
      onSelected: (_) => onTap(),
    );
  }
}
