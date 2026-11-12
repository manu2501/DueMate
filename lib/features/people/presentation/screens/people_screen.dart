import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/contacts_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/domain/person_matcher.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();
  bool _isImporting = false;

  static const _filters = {
    PeopleFilter.all: 'All',
    PeopleFilter.active: 'Open balance',
    PeopleFilter.settled: 'Settled',
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

  Future<void> _importFromContacts() async {
    setState(() => _isImporting = true);
    try {
      final contact = await ContactsHelper.pickContact();
      if (contact == null) return;

      final people = (await ref.read(allPersonSummariesProvider.future)).map((s) => s.person);
      final existing = PersonMatcher.findDuplicate(people, name: contact.name, phone: contact.phone);
      if (existing != null) {
        if (mounted && await showAlreadyInLedgerDialog(context, existing) && mounted) {
          context.push('/people/${existing.id}');
        }
        return;
      }

      final now = DateTime.now();
      final newPerson = Person(
        id: const Uuid().v4(),
        name: contact.name,
        phone: contact.phone,
        email: contact.email,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(personRepositoryProvider).createPerson(newPerson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${newPerson.name} added')));
        context.push('/people/${newPerson.id}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that contact.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
    final totals = ref.watch(dashboardTotalsProvider);
    final searching = _searchController.text.isNotEmpty;
    final money = ref.watch(displayMoneyProvider);

    final summary = [
      if (totals.totalTheyOwe > 0) '${money(totals.totalTheyOwe)} to collect',
      if (totals.totalUserOwes > 0) '${money(totals.totalUserOwes)} to pay',
    ].join(' · ');

    return TabScaffold(
      title: 'People',
      actions: [
        IconButton(
          tooltip: 'Add from contacts',
          onPressed: _isImporting ? null : _importFromContacts,
          icon: _isImporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.contacts_outlined),
        ),
        IconButton(tooltip: 'Sort', onPressed: _showSortSheet, icon: const Icon(Icons.sort_rounded)),
        IconButton(
          tooltip: 'Lending trends',
          onPressed: () => context.push('/lending-trends'),
          icon: const Icon(Icons.insights_outlined),
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
                for (final e in _filters.entries) ...[
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
                  : filter == PeopleFilter.all
                      ? 'No one here yet'
                      : 'No one in ${_filters[filter]!.toLowerCase()}',
              description: searching
                  ? 'Try a different name or number.'
                  : 'Add someone you lend to, borrow from, or share EMIs with.',
              actionLabel: searching ? null : 'Add person',
              onActionPressed: searching ? null : () => AddEditPersonScreen.show(context),
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
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
