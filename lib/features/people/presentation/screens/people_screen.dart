import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/contacts_helper.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/fade_slide_transition.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/widgets/person_directory_tile.dart';

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

  static final _nonDigitsRegex = RegExp(r'\D');

  String _normalizePhone(String raw) {
    final digitsOnly = raw.replaceAll(_nonDigitsRegex, '');
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  Future<void> _importFromContacts() async {
    setState(() => _isImporting = true);
    try {
      final contact = await ContactsHelper.pickContact();
      if (contact == null) return;

      final allPersons = await ref.read(allPersonSummariesProvider.future);
      final contactName = contact.name.trim();
      final contactPhone = contact.phone != null ? contact.phone!.trim() : '';
      final normPhone = contactPhone.isNotEmpty ? _normalizePhone(contactPhone) : '';

      final existing = allPersons.where((s) {
        // Phone numbers decide it when both sides have one; otherwise fall
        // back to the name, so different people sharing a name can coexist.
        final existingNorm = (s.person.phone ?? '').trim().isNotEmpty
            ? _normalizePhone(s.person.phone!)
            : '';
        if (normPhone.isNotEmpty && existingNorm.isNotEmpty) {
          return existingNorm == normPhone;
        }
        return s.person.name.trim().toLowerCase() == contactName.toLowerCase();
      }).firstOrNull;

      if (existing != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Already in your ledger'),
              content: Text(
                existing.person.phone == null || existing.person.phone!.isEmpty
                    ? '${existing.person.name} is already in your ledger.'
                    : '${existing.person.name} (${existing.person.phone}) is already in your ledger.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/people/${existing.person.id}');
                  },
                  child: const Text('Open ledger'),
                ),
              ],
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newPerson.name} added'),
          ),
        );
        context.push('/people/${newPerson.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that contact.")),
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
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _sortItem('Largest balance', PeopleSort.highestOutstanding, currentSort, Icons.trending_up_rounded, cs),
              _sortItem('Recent activity', PeopleSort.recentlyActive, currentSort, Icons.history_rounded, cs),
              _sortItem('Name (A–Z)', PeopleSort.alphabetical, currentSort, Icons.sort_by_alpha_rounded, cs),
              _sortItem('Recently added', PeopleSort.recentlyAdded, currentSort, Icons.schedule_rounded, cs),
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
    final allSummariesAsync = ref.watch(allPersonSummariesProvider);
    final allPersons = allSummariesAsync.value ?? [];

    final totalCount = allPersons.length;
    final activeDuesCount = allPersons.where((s) => s.owesMoney || s.isOverpaid).length;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'People',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '$totalCount Contacts • $activeDuesCount Active Dues',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _isImporting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filledTonal(
                        tooltip: 'Import from Contacts',
                        icon: const Icon(Icons.contacts_rounded, size: 18),
                        onPressed: _importFromContacts,
                      ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded, size: 18),
                  onPressed: () => _showSortMenu(context),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: FloatingActionButton.extended(
          onPressed: () => AddEditPersonScreen.show(context),
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: Text('Add person', style: TextStyle(fontWeight: FontWeight.w700)),
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
              hintText: 'Search by name, phone or notes',
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
                _filterChip('All', PeopleFilter.all, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Owes You', PeopleFilter.active, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Settled', PeopleFilter.settled, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Archived', PeopleFilter.archived, currentFilter),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // People List
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
                      onActionPressed: () => AddEditPersonScreen.show(context),
                    )
                  : ListView.separated(
                      key: ValueKey('list_${currentFilter.name}'),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 160),
                      itemCount: people.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        return FadeSlideTransition(
                          index: index,
                          child: PersonDirectoryTile(
                            summary: people[index],
                            currencySymbol: currencySymbol,
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
