import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();

  static const _filters = {
    PeopleFilter.all: 'All',
    PeopleFilter.owesYou: 'Owes you',
    PeopleFilter.youOwe: 'You owe',
    PeopleFilter.overdue: 'Overdue',
    PeopleFilter.archived: 'Archived',
  };

  static const _sorts = {
    PeopleSort.highestOutstanding: 'Largest balance',
    PeopleSort.recentlyActive: 'Recent activity',
    PeopleSort.alphabetical: 'Name (A–Z)',
    PeopleSort.recentlyAdded: 'Recently added',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortSheet() {
    final current = ref.read(peopleSortProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<PeopleSort>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ref.read(peopleSortProvider.notifier).setSort(v);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, 0, AppSpace.screenGutter, AppSpace.sm),
                child: Text('Sort by', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final e in _sorts.entries) RadioListTile<PeopleSort>(value: e.key, title: Text(e.value)),
              const SizedBox(height: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  /// Long-press shortcuts so common actions don't need opening the ledger.
  void _showQuickActions(PersonSummary s, String symbol) {
    final p = s.person;
    final canRemind = s.owesMoney && (p.phone?.isNotEmpty ?? false);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: AvatarWidget(name: p.name, radius: 20),
              title: Text(p.name),
              subtitle: Text(
                s.balance.abs() < 0.0001
                    ? 'Settled'
                    : '${balanceWording(s).label} ${ref.read(displayMoneyProvider)(s.balance.abs())}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.north_east_rounded),
              title: const Text('Give money'),
              onTap: () {
                Navigator.of(ctx).pop();
                QuickGiveSheet.show(context, personId: p.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.south_west_rounded),
              title: const Text('Receive money'),
              onTap: () {
                Navigator.of(ctx).pop();
                QuickReceiveSheet.show(context, personId: p.id);
              },
            ),
            if (canRemind)
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Send a reminder on WhatsApp'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WhatsAppHelper.sendWhatsAppMessage(
                    phoneNumber: p.phone,
                    message: WhatsAppHelper.generateLedgerReminderMessage(s,
                        currencySymbol: symbol, upiId: ref.read(upiIdForRemindersProvider)),
                    context: context,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open ledger'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/people/${p.id}');
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final filter = ref.watch(peopleFilterProvider);
    final people = ref.watch(filteredPersonSummariesProvider);
    final dues = ref.watch(loanDuesProvider);
    final totals = ref.watch(dashboardTotalsProvider);
    final searching = _searchController.text.isNotEmpty;
    final money = ref.watch(displayMoneyProvider);

    final summary = [
      if (totals.totalTheyOwe > 0) '${money(totals.totalTheyOwe)} to collect',
      if (totals.totalUserOwes > 0) '${money(totals.totalUserOwes)} to pay',
    ].join(' · ');

    return TabScaffold(
      title: 'People',
      // One menu instead of a row of unlabelled icons. Adding from contacts
      // lives in the Add person form.
      actions: [
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _showSortSheet,
              child: const ListTile(leading: Icon(Icons.sort_rounded), title: Text('Sort by…')),
            ),
            PopupMenuItem(
              value: () => context.push('/lending-trends'),
              child: const ListTile(leading: Icon(Icons.insights_outlined), title: Text('Lending trends')),
            ),
            PopupMenuItem(
              value: () => ref.read(peopleFilterProvider.notifier).setFilter(PeopleFilter.archived),
              child: const ListTile(leading: Icon(Icons.archive_outlined), title: Text('Archived people')),
            ),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditPersonScreen.show(context),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add person'),
      ),
      slivers: [
        if (summary.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, 0, AppSpace.screenGutter, AppSpace.md),
              child: Text(summary, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, phone or notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(peopleSearchQueryProvider.notifier).setQuery('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                ref.read(peopleSearchQueryProvider.notifier).setQuery(v);
                setState(() {});
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: Row(
              children: [
                // Archived only shows as a chip while it's the filter (picked
                // from the menu), so there's a visible way back.
                for (final e in _filters.entries)
                  if (e.key != PeopleFilter.archived || filter == PeopleFilter.archived) ...[
                  ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(e.key),
                  ),
                  const SizedBox(width: AppSpace.sm),
                ],
              ],
            ),
          ),
        ),
        if (people.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
              title: searching
                  ? 'No one matches "${_searchController.text}"'
                  : switch (filter) {
                      PeopleFilter.all => 'No one here yet',
                      PeopleFilter.owesYou => 'No one owes you',
                      PeopleFilter.youOwe => "You don't owe anyone",
                      PeopleFilter.overdue => 'Nothing overdue',
                      PeopleFilter.archived => 'No archived people',
                    },
              description: searching
                  ? 'Try a different name or number.'
                  : switch (filter) {
                      PeopleFilter.all => 'Add someone you lend to, borrow from, or share EMIs with.',
                      PeopleFilter.overdue => 'Set a "Return by" date when you give money; anyone late shows up here.',
                      PeopleFilter.archived => 'Archive someone from their page to tidy the list; their records stay.',
                      _ => 'Balances show up here as you record what you give and receive.',
                    },
              actionLabel: !searching && filter == PeopleFilter.all ? 'Add person' : null,
              onActionPressed: !searching && filter == PeopleFilter.all ? () => AddEditPersonScreen.show(context) : null,
            ),
          )
        else
          SliverToBoxAdapter(
            child: GroupCard(
              children: [
                for (final s in people)
                  PersonRow(
                    summary: s,
                    symbol: symbol,
                    onLongPress: () => _showQuickActions(s, symbol),
                    showRepayment: true,
                    due: dues[s.person.id],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
