import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/fade_slide_transition.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/monthly_budget_card.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _emiOwnershipFilter = 0; // 0: For Myself, 1: For Others, 2: All
  ExpenseCategory? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  List<CreditCardEmi> _filterEmis(List<CreditCardEmi> activeEmis) {
    if (_emiOwnershipFilter == 0) {
      return activeEmis.where((e) => e.isForSelf).toList();
    } else if (_emiOwnershipFilter == 1) {
      return activeEmis.where((e) => !e.isForSelf).toList();
    } else {
      return activeEmis;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PersonalExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currencySymbol = ref.watch(currencySymbolProvider);
    final monthlyExpensesAsync = ref.watch(monthlyExpensesProvider);
    final totalSpent = ref.watch(monthlyExpenseTotalProvider);
    final activeEmisAsync = ref.watch(activeEmisProvider);
    final personsMap = ref.watch(personsMapProvider);

    final monthlyExpenses = monthlyExpensesAsync.value ?? [];
    final filteredExpenses = _selectedCategoryFilter == null
        ? monthlyExpenses
        : monthlyExpenses.where((e) => e.category == _selectedCategoryFilter).toList();

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
                            'My Expenses & Outflows',
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF131438),
                            ),
                          ),
                          Text(
                            '${monthlyExpenses.length} Outflows • ${CurrencyFormatter.format(totalSpent, symbol: currencySymbol)} Spent This Month',
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
                      tooltip: 'View Expense Charts',
                      icon: const Icon(Icons.bar_chart_rounded, size: 18),
                      onPressed: () => context.push('/expense-charts'),
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
                  Tab(text: 'Personal Outflows'),
                  Tab(text: 'EMIs & Bank Loans'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => AddEditExpenseSheet.show(context),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Log Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          const MonthlyBudgetCard(),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Personal Outflows List & Usage Charts
                monthlyExpenses.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No personal expenses logged this month',
                        description: 'Tap Log Expense below to record your daily outflows.',
                        actionLabel: 'Log Expense',
                        onActionPressed: () => AddEditExpenseSheet.show(context),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 160),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: InkWell(
                              onTap: () => context.push('/expense-charts'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'View Expense Analytics & Charts',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: cs.primary,
                                            ),
                                          ),
                                          Text(
                                            'Month-over-month trends & category usage',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: cs.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filteredExpenses.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: cs.outlineVariant.withValues(alpha: 0.6),
                              ),
                              itemBuilder: (ctx, index) {
                                final expense = filteredExpenses[index];
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
                                      '${_getPaymentMethodName(expense.paymentMethod)} • ${DateFormatter.formatShortDate(expense.expenseDate)}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(expense.amount, symbol: currencySymbol),
                                          style: GoogleFonts.dmSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: cs.error,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                                          onPressed: () => _confirmDelete(context, ref, expense),
                                        ),
                                      ],
                                    ),
                                    onTap: () => AddEditExpenseSheet.show(context, expenseToEdit: expense),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                // Tab 2: EMIs & Bank Loans
                activeEmisAsync.when(
                  data: (activeEmis) {
                    final filteredEmis = _filterEmis(activeEmis);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('For Myself'),
                                selected: _emiOwnershipFilter == 0,
                                onSelected: (_) => setState(() => _emiOwnershipFilter = 0),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('For Others'),
                                selected: _emiOwnershipFilter == 1,
                                onSelected: (_) => setState(() => _emiOwnershipFilter = 1),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _emiOwnershipFilter == 2,
                                onSelected: (_) => setState(() => _emiOwnershipFilter = 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        Expanded(
                          child: filteredEmis.isEmpty
                              ? EmptyStateWidget(
                                  icon: Icons.event_repeat_rounded,
                                  title: _emiOwnershipFilter == 0
                                      ? 'No personal EMIs or loans'
                                      : _emiOwnershipFilter == 1
                                          ? 'No EMIs or loans for contacts'
                                          : 'No active EMIs or loans',
                                  description: 'Track credit card EMIs or bank loans easily.',
                                  actionLabel: 'Add EMI / Loan',
                                  onActionPressed: () => AddEditEmiScreen.show(context),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
                                  itemCount: filteredEmis.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (ctx, index) {
                                    final emi = filteredEmis[index];
                                    final person = personsMap[emi.personId];
                                    return EmiCard(
                                      emi: emi,
                                      person: person,
                                      currencySymbol: currencySymbol,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
