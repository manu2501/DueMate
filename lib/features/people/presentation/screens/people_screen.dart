import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/utils/contacts_helper.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/person.dart';
import 'package:smarava/features/people/presentation/screens/add_edit_person_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    setState(() => _isImporting = true);
    try {
      final contact = await ContactsHelper.pickContact();
      if (contact == null) {
        setState(() => _isImporting = false);
        return;
      }

      final allPersons = await ref.read(allPersonSummariesProvider.future);
      final existing = allPersons.where((s) {
        final sameName = s.person.name.toLowerCase() == contact.name.toLowerCase();
        final samePhone = contact.phone != null &&
            s.person.phone != null &&
            s.person.phone!.replaceAll(RegExp(r'\s+'), '') ==
                contact.phone!.replaceAll(RegExp(r'\s+'), '');
        return sameName || samePhone;
      }).firstOrNull;

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${existing.person.name} is already in your ledger'),
            ),
          );
          context.go('/people/${existing.person.id}');
        }
        return;
      }

      final now = DateTime.now();
      final newPerson = Person(
        id: const Uuid().v4(),
        name: contact.name,
        phone: contact.phone,
        email: contact.email,
        notes: 'Imported from phone contacts',
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(personRepositoryProvider).createPerson(newPerson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newPerson.name} from contacts'),
          ),
        );
        context.go('/people/${newPerson.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read contact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSortMenu(BuildContext context) {
    final currentSort = ref.read(peopleSortProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Sort People',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _sortTile('Highest Outstanding', PeopleSort.highestOutstanding, currentSort, Icons.trending_up_rounded),
              _sortTile('Recently Active', PeopleSort.recentlyActive, currentSort, Icons.history_rounded),
              _sortTile('Alphabetical (A - Z)', PeopleSort.alphabetical, currentSort, Icons.sort_by_alpha_rounded),
              _sortTile('Recently Added', PeopleSort.recentlyAdded, currentSort, Icons.schedule_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String title, PeopleSort sort, PeopleSort current, IconData icon) {
    final isSelected = sort == current;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_rounded, color: colorScheme.onPrimaryContainer)
            : null,
        onTap: () {
          ref.read(peopleSortProvider.notifier).setSort(sort);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currentFilter = ref.watch(peopleFilterProvider);
    final people = ref.watch(filteredPersonSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People Ledger'),
        actions: [
          _isImporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Import from Phone Contacts',
                  icon: const Icon(Icons.contacts_rounded),
                  onPressed: _importFromContacts,
                ),
          IconButton(
            tooltip: 'Sort Options',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showSortMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Person', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Material 3 Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
              hintText: 'Search people, notes...',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(peopleSearchQueryProvider.notifier).setQuery('');
                    },
                  ),
              ],
              onChanged: (val) {
                ref.read(peopleSearchQueryProvider.notifier).setQuery(val);
              },
            ),
          ),

          // Material 3 Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Active'),
                  selected: currentFilter == PeopleFilter.active,
                  onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(PeopleFilter.active),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Settled'),
                  selected: currentFilter == PeopleFilter.settled,
                  onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(PeopleFilter.settled),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archived'),
                  selected: currentFilter == PeopleFilter.archived,
                  onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(PeopleFilter.archived),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All Directory'),
                  selected: currentFilter == PeopleFilter.all,
                  onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(PeopleFilter.all),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // List of People
          Expanded(
            child: people.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: _searchController.text.isNotEmpty ? 'No matches found' : 'No records here',
                    description: _searchController.text.isNotEmpty
                        ? 'Try searching with a different name or phone number.'
                        : 'Add friends or contacts to start tracking balances.',
                    actionLabel: _searchController.text.isNotEmpty ? null : 'Add Person',
                    onActionPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: people.length,
                    itemBuilder: (ctx, index) {
                      final summary = people[index];
                      final person = summary.person;
                      final balance = summary.balance;
                      final owes = summary.owesMoney;
                      final overpaid = summary.isOverpaid;

                      Color badgeBg;
                      Color badgeFg;
                      String badgeText;
                      if (owes) {
                        badgeBg = colorScheme.errorContainer;
                        badgeFg = colorScheme.onErrorContainer;
                        badgeText = 'Owes ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
                      } else if (overpaid) {
                        badgeBg = colorScheme.tertiaryContainer;
                        badgeFg = colorScheme.onTertiaryContainer;
                        badgeText = 'Overpaid ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
                      } else {
                        badgeBg = colorScheme.primaryContainer;
                        badgeFg = colorScheme.onPrimaryContainer;
                        badgeText = 'Settled';
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          onTap: () => context.push('/people/${person.id}'),
                          leading: AvatarWidget(name: person.name, radius: 22),
                          title: Text(
                            person.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              if (summary.lastTransaction != null)
                                Text(
                                  'Last: ${DateFormatter.formatRelative(summary.lastTransaction!.transactionDate)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                )
                              else if (person.phone != null && person.phone!.isNotEmpty)
                                Text(
                                  person.phone!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                )
                              else
                                Text(
                                  'Added ${DateFormatter.formatShortDate(person.createdAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: badgeFg,
                                  ),
                                ),
                              ),
                              if (owes) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => QuickReceiveSheet.show(context, personId: person.id),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_downward_rounded, size: 11, color: colorScheme.primary),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Receive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
