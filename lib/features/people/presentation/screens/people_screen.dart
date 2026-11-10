import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/contacts_helper.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

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
          context.push('/people/${existing.person.id}');
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
            content: Text('Added ${newPerson.name} to ledger'),
          ),
        );
        context.push('/people/${newPerson.id}');
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
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort People',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _sortItem('Highest Outstanding', PeopleSort.highestOutstanding, currentSort, Icons.trending_up_rounded, cs),
              _sortItem('Recently Active', PeopleSort.recentlyActive, currentSort, Icons.history_rounded, cs),
              _sortItem('Alphabetical (A - Z)', PeopleSort.alphabetical, currentSort, Icons.sort_by_alpha_rounded, cs),
              _sortItem('Recently Added', PeopleSort.recentlyAdded, currentSort, Icons.schedule_rounded, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortItem(String title, PeopleSort sort, PeopleSort current, IconData icon, ColorScheme cs) {
    final isSelected = sort == current;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: isSelected ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
      leading: Icon(
        icon,
        color: isSelected ? cs.primary : cs.onSurfaceVariant,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: cs.primary, size: 20)
          : null,
      onTap: () {
        ref.read(peopleSortProvider.notifier).setSort(sort);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currentFilter = ref.watch(peopleFilterProvider);
    final people = ref.watch(filteredPersonSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
        actions: [
          _isImporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Import from Contacts',
                  icon: const Icon(Icons.contacts_rounded),
                  onPressed: _importFromContacts,
                ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _showSortMenu(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
            );
          },
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: Text('Add Person', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
              hintText: 'Search people or notes...',
              hintStyle: WidgetStatePropertyAll(
                TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              leading: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
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

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _filterChip('Active', PeopleFilter.active, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Settled', PeopleFilter.settled, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Archived', PeopleFilter.archived, currentFilter),
                const SizedBox(width: 8),
                _filterChip('All', PeopleFilter.all, currentFilter),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // People List with AnimatedSwitcher
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: people.isEmpty
                  ? EmptyStateWidget(
                      key: ValueKey('empty_${currentFilter.name}_${_searchController.text}'),
                      icon: Icons.people_outline_rounded,
                      title: _searchController.text.isNotEmpty ? 'No matches' : 'No records yet',
                      description: _searchController.text.isNotEmpty
                          ? 'Try searching with another name or phone number.'
                          : 'Add someone to track balances and payments.',
                      actionLabel: _searchController.text.isNotEmpty ? null : 'Add Person',
                      onActionPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
                        );
                      },
                    )
                  : ListView.separated(
                      key: ValueKey('list_${currentFilter.name}'),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                      itemCount: people.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final summary = people[index];
                        final person = summary.person;
                        final balance = summary.balance;
                        final owes = summary.owesMoney;
                        final overpaid = summary.isOverpaid;

                        Color badgeColor;
                        String badgeText;
                        if (owes) {
                          badgeColor = cs.error;
                          badgeText = CurrencyFormatter.format(balance, symbol: currencySymbol);
                        } else if (overpaid) {
                          badgeColor = cs.tertiary;
                          badgeText = 'Over ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
                        } else {
                          badgeColor = cs.primary;
                          badgeText = 'Settled';
                        }

                        return InkWell(
                          onTap: () => context.push('/people/${person.id}'),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.15 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                AvatarWidget(
                                  name: person.name,
                                  radius: 22,
                                  heroTag: 'avatar-${person.id}',
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        summary.lastTransaction != null
                                          ? 'Last: ${DateFormatter.formatRelative(summary.lastTransaction!.transactionDate)}'
                                          : (person.phone != null && person.phone!.isNotEmpty)
                                              ? person.phone!
                                              : 'Added ${DateFormatter.formatShortDate(person.createdAt)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      badgeText,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                      ),
                                    ),
                                    if (owes) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => QuickReceiveSheet.show(context, personId: person.id),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text(
                                            'Receive',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, PeopleFilter filter, PeopleFilter current) {
    final isSelected = filter == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(peopleFilterProvider.notifier).setFilter(filter),
    );
  }
}
