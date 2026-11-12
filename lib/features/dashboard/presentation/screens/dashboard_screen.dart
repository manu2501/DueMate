import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/app_logo.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

/// Home answers, in order: where do I stand, what can I do, what's coming
/// up, and who's involved.
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
      if (mounted) await PermissionManager.checkAndPromptOnStartupOrUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Post any EMI installments that fell due since the app was last opened.
    ref.watch(emiAutoProcessorProvider);

    final symbol = ref.watch(currencySymbolProvider);
    final hasPeople = (ref.watch(allPersonSummariesProvider).value ?? const [])
        .any((s) => !s.person.isArchived && s.person.id != AppConstants.selfPersonId);
    final hasExpenses = (ref.watch(monthlyExpensesProvider).value ?? const []).isNotEmpty;
    final hasEmis = (ref.watch(activeEmisProvider).value ?? const []).isNotEmpty;
    final isEmpty = !hasPeople && !hasExpenses && !hasEmis;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allPersonSummariesProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: AppSpace.screenGutter,
              title: const Row(
                children: [
                  AppLogo(size: 28),
                  SizedBox(width: AppSpace.md),
                  Text('DueMate'),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
                const SizedBox(width: AppSpace.xs),
              ],
            ),
            if (isEmpty)
              const SliverToBoxAdapter(child: _Welcome())
            else ...[
              SliverToBoxAdapter(child: _Position(symbol: symbol)),
              const SliverToBoxAdapter(child: _PrimaryActions()),
              SliverToBoxAdapter(child: _EmisAndCards(symbol: symbol)),
              SliverToBoxAdapter(child: _MonthSpend(symbol: symbol)),
              SliverToBoxAdapter(child: _Balances(symbol: symbol)),
              SliverToBoxAdapter(child: _Recent(symbol: symbol)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
          ],
        ),
      ),
    );
  }
}

/// The one number that matters: net position, then the two sides.
class _Position extends ConsumerWidget {
  final String symbol;
  const _Position({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final t = ref.watch(dashboardTotalsProvider);
    String money(double v) => CurrencyFormatter.format(v, symbol: symbol);
    String people(int n) => n == 1 ? '1 person' : '$n people';

    final net = t.netBalance;
    final String label;
    final MoneyTone tone;
    if (net > 0.0001) {
      label = 'Owed to you overall';
      tone = MoneyTone.positive;
    } else if (net < -0.0001) {
      label = 'You owe overall';
      tone = MoneyTone.negative;
    } else {
      label = 'All square';
      tone = MoneyTone.neutral;
    }

    final parts = [
      if (t.totalTheyOwe > 0) '${money(t.totalTheyOwe)} to collect from ${people(t.peopleOweUserCount)}',
      if (t.totalUserOwes > 0) '${money(t.totalUserOwes)} to pay ${people(t.peopleUserOwesCount)}',
    ];

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.lg, AppSpace.screenGutter, AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: muted)),
            const SizedBox(height: AppSpace.xs),
            MoneyText(net, symbol: symbol, tone: tone, style: theme.textTheme.displaySmall),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              for (final p in parts) Text(p, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions();

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        children: [
          action(Icons.north_east_rounded, 'Give', () => QuickGiveSheet.show(context)),
          const SizedBox(width: AppSpace.sm),
          action(Icons.south_west_rounded, 'Receive', () => QuickReceiveSheet.show(context)),
          const SizedBox(width: AppSpace.sm),
          action(Icons.receipt_long_outlined, 'Expense', () => AddEditExpenseSheet.show(context)),
        ],
      ),
    );
  }
}

/// Shortcut to EMIs and cards: how many, what goes out each month, and the
/// next installments due. Always shown, so EMIs are one tap from Home.
class _EmisAndCards extends ConsumerWidget {
  final String symbol;
  const _EmisAndCards({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emis = ref.watch(activeEmisProvider).value ?? const <CreditCardEmi>[];
    final people = ref.watch(personsMapProvider);
    void openAll() => context.go('/expenses?tab=emis');

    final upcoming = emis.where((e) => e.nextDueDate != null).toList()
      ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    // What leaves your account each month: your own EMIs and those on your card.
    final monthly = emis
        .where((e) => e.isForSelf || e.isPaidByMe)
        .fold<double>(0, (s, e) => s + e.getMonthlyInstallmentFor(e.installmentsPaid + 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('EMIs & cards', actionLabel: 'Add', onAction: () => AddEditEmiScreen.show(context)),
        GroupCard(
          children: emis.isEmpty
              ? [
                  ListTile(
                    onTap: () => AddEditEmiScreen.show(context),
                    leading: const IconBadge(Icons.credit_card_outlined),
                    title: const Text('Add an EMI or loan'),
                    subtitle: const Text('Installments go into the ledger on their due dates'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ]
              : [
                  ListTile(
                    onTap: openAll,
                    leading: const IconBadge(Icons.credit_card_outlined),
                    title: Text('${emis.length} active'),
                    subtitle: Text(
                      monthly > 0
                          ? '${CurrencyFormatter.format(monthly, symbol: symbol)} goes out each month'
                          : 'Paid by others',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  for (final e in upcoming.take(3))
                    ListTile(
                      onTap: () => EmiDetailsSheet.show(context, emi: e, person: people[e.personId]),
                      leading: const IconBadge(Icons.event_outlined),
                      title: Text(e.itemName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Due ${DateFormatter.formatRelative(e.nextDueDate!)} · ${e.cardName}'),
                      trailing: MoneyText(e.getMonthlyInstallmentFor(e.installmentsPaid + 1), symbol: symbol),
                    ),
                ],
        ),
      ],
    );
  }
}

class _MonthSpend extends ConsumerWidget {
  final String symbol;
  const _MonthSpend({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final spent = ref.watch(monthlyExpenseTotalProvider);
    final budget = ref.watch(monthlyBudgetLimitProvider);
    String money(double v) => CurrencyFormatter.format(v, symbol: symbol);
    final ratio = budget > 0 ? (spent / budget) : 0.0;
    final over = spent > budget && budget > 0;
    final month = DateFormatter.formatMonthYear(DateTime.now()).split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Spending in $month'),
        GroupCard(
          children: [
            InkWell(
              onTap: () => context.go('/expenses'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: MoneyText(spent, symbol: symbol, style: theme.textTheme.headlineSmall)),
                        Text(
                          over ? '${money(spent - budget)} over' : '${money(budget - spent)} left',
                          style: theme.textTheme.labelLarge?.copyWith(color: over ? cs.error : cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        color: over ? cs.error : (ratio > 0.85 ? cs.tertiary : cs.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'of ${money(budget)} monthly budget',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Balances extends ConsumerWidget {
  final String symbol;
  const _Balances({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topPeopleByBalanceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Balances', actionLabel: 'All people', onAction: () => context.go('/people')),
        GroupCard(
          children: top.isEmpty
              ? [
                  ListTile(
                    leading: const IconBadge(Icons.check_rounded),
                    title: const Text('No open balances'),
                    subtitle: const Text('Record what you give or receive and it shows up here.'),
                    onTap: () => context.go('/people'),
                  ),
                ]
              : [for (final s in top) PersonRow(summary: s, symbol: symbol)],
        ),
      ],
    );
  }
}

class _Recent extends ConsumerWidget {
  final String symbol;
  const _Recent({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider).value ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    final people = ref.watch(personsMapProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Recent', actionLabel: 'All activity', onAction: () => context.go('/reports')),
        GroupCard(
          children: [
            for (final tx in recent.take(5))
              TransactionTile(
                transaction: tx,
                person: people[tx.personId],
                currencySymbol: symbol,
                onTap: () => TransactionDetailsDialog.show(context, transaction: tx, person: people[tx.personId]),
              ),
          ],
        ),
      ],
    );
  }
}

/// First run: explain the app in one line and offer the two ways in.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(size: 56),
          const SizedBox(height: AppSpace.xl),
          Text('Keep track of who owes what', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Record money you lend or borrow, EMIs you share, and what you spend. '
            'Everything stays on this phone.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => AddEditPersonScreen.show(context),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add a person'),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => AddEditExpenseSheet.show(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Add an expense'),
            ),
          ),
        ],
      ),
    );
  }
}
