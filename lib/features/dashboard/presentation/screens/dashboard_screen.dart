import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/app_logo.dart';
import 'package:duemate/core/widgets/hide_amounts_toggle.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

/// Home answers, in order: where do I stand, what can I do, who owes what,
/// what I spent and what is due next. Sections without data stay hidden.
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
    // Post EMI installments and recurring expenses that fell due since the
    // app was last opened.
    ref.watch(emiAutoProcessorProvider);
    ref.watch(recurringExpenseProcessorProvider);

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
                const _HideAmountsButton(),
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
              // Most important first; each section only once it has something.
              SliverToBoxAdapter(child: _Position(symbol: symbol)),
              const SliverToBoxAdapter(child: _PrimaryActions()),
              SliverToBoxAdapter(child: _Balances(symbol: symbol)),
              if (hasExpenses) SliverToBoxAdapter(child: _MonthSpend(symbol: symbol)),
              if (hasEmis) SliverToBoxAdapter(child: _NextEmi(symbol: symbol)),
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
    final money = ref.watch(displayMoneyProvider);
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

/// EMIs in one row: the next installment due, with how many are active and
/// what goes out each month. "See all" opens the EMI list.
class _NextEmi extends ConsumerWidget {
  final String symbol;
  const _NextEmi({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emis = ref.watch(activeEmisProvider).value ?? const <CreditCardEmi>[];
    final people = ref.watch(personsMapProvider);

    // Each EMI's earliest unpaid installment, soonest first.
    final upcoming = [
      for (final e in emis)
        if (watchInstallments(ref, e) case final s when s.next != null) s,
    ]..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;
    // What leaves your account each month: your own EMIs and those on your card.
    final monthly = upcoming
        .where((s) => s.emi.isForSelf || s.emi.isPaidByMe)
        .fold<double>(0, (sum, s) => sum + s.nextAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('EMIs & loans', actionLabel: 'See all', onAction: () => context.go('/expenses?tab=emis')),
        GroupCard(
          children: [
            ListTile(
              onTap: () => EmiDetailsSheet.show(context, emi: next.emi, person: people[next.emi.personId]),
              leading: const IconBadge(Icons.event_outlined),
              title: Text('Next: ${next.emi.itemName}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                'Due ${DateFormatter.formatRelative(next.nextDueDate!)}',
                '${emis.length} active',
                if (monthly > 0) '${ref.watch(displayMoneyProvider)(monthly)} a month',
              ].join(' · ')),
              trailing: MoneyText(next.nextAmount, symbol: symbol),
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
    final money = ref.watch(displayMoneyProvider);
    final ratio = budget > 0 ? (spent / budget) : 0.0;
    final over = spent > budget && budget > 0;
    final month = DateFormatter.formatMonthYear(DateTime.now()).split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Spent in $month'),
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
    // Nothing open: the headline already says "All square".
    if (top.isEmpty) return const SizedBox.shrink();
    final dues = ref.watch(loanDuesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Balances', actionLabel: 'All people', onAction: () => context.go('/people')),
        GroupCard(
          children: [for (final s in top) PersonRow(summary: s, symbol: symbol, due: dues[s.person.id])],
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

/// Eye toggle in the Home app bar: hide or show amounts everywhere.
class _HideAmountsButton extends ConsumerWidget {
  const _HideAmountsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideBalancesProvider);
    return IconButton(
      tooltip: hidden ? 'Show amounts' : 'Hide amounts',
      isSelected: hidden,
      icon: const Icon(Icons.visibility_outlined),
      selectedIcon: const Icon(Icons.visibility_off_outlined),
      onPressed: () => setAmountsHidden(context, ref, !hidden),
    );
  }
}
