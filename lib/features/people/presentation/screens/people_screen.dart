import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/utils/contacts_helper.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/bento_card.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/core/widgets/spotlight_background.dart';
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

  Future<void> _importFromContacts(BuildContext context) async {
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
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Added ${newPerson.name} from contacts',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF09090B)),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'Sort Directory By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                _sortTile('Highest Outstanding', PeopleSort.highestOutstanding, currentSort, Icons.trending_up_rounded),
                _sortTile('Recently Active', PeopleSort.recentlyActive, currentSort, Icons.schedule_rounded),
                _sortTile('Alphabetical (A - Z)', PeopleSort.alphabetical, currentSort, Icons.sort_by_alpha_rounded),
                _sortTile('Recently Added', PeopleSort.recentlyAdded, currentSort, Icons.fiber_new_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String title, PeopleSort sort, PeopleSort current, IconData icon) {
    final isSelected = sort == current;
    return BentoCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      glowColor: isSelected ? const Color(0xFF10B981) : null,
      onTap: () {
        ref.read(peopleSortProvider.notifier).setSort(sort);
        Navigator.of(context).pop();
      },
      child: Row(
        children: [
          Icon(icon, size: 20, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF71717A)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF10B981) : null,
              ),
            ),
          ),
          if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currentFilter = ref.watch(peopleFilterProvider);
    final people = ref.watch(filteredPersonSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'People Ledger',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          _isImporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.0),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Import from Phone Contacts',
                  icon: const Icon(Icons.contacts_rounded, color: Color(0xFF10B981)),
                  onPressed: () => _importFromContacts(context),
                ),
          IconButton(
            tooltip: 'Sort Options',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showSortMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: const Color(0xFF09090B),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddEditPersonScreen()),
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Person', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SpotlightBackground(
        primaryGlow: const Color(0xFF10B981),
        secondaryGlow: const Color(0xFF6366F1),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search people, notes...',
                  hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF71717A)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(peopleSearchQueryProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onChanged: (val) {
                  ref.read(peopleSearchQueryProvider.notifier).setQuery(val);
                },
              ),
            ),

            // Aceternity Segmented Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _filterPill('Active', PeopleFilter.active, currentFilter, isDark),
                  const SizedBox(width: 8),
                  _filterPill('Settled', PeopleFilter.settled, currentFilter, isDark),
                  const SizedBox(width: 8),
                  _filterPill('Archived', PeopleFilter.archived, currentFilter, isDark),
                  const SizedBox(width: 8),
                  _filterPill('All Directory', PeopleFilter.all, currentFilter, isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),

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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: people.length,
                      itemBuilder: (ctx, index) {
                        final summary = people[index];
                        final person = summary.person;
                        final balance = summary.balance;
                        final owes = summary.owesMoney;
                        final overpaid = summary.isOverpaid;

                        Color badgeColor;
                        String badgeText;
                        if (owes) {
                          badgeColor = const Color(0xFFF43F5E);
                          badgeText = 'Owes ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
                        } else if (overpaid) {
                          badgeColor = const Color(0xFF8B5CF6);
                          badgeText = 'Overpaid ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
                        } else {
                          badgeColor = const Color(0xFF10B981);
                          badgeText = '✓ Settled';
                        }

                        return BentoCard(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(14),
                          onTap: () => context.push('/people/${person.id}'),
                          child: Row(
                            children: [
                              AvatarWidget(name: person.name, radius: 22),
                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    if (summary.lastTransaction != null)
                                      Text(
                                        'Last: ${DateFormatter.formatRelative(summary.lastTransaction!.transactionDate)}',
                                        style: const TextStyle(
                                          color: Color(0xFF71717A),
                                          fontSize: 11,
                                        ),
                                      )
                                    else if (person.phone != null && person.phone!.isNotEmpty)
                                      Text(
                                        person.phone!,
                                        style: const TextStyle(
                                          color: Color(0xFF71717A),
                                          fontSize: 11,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Added ${DateFormatter.formatShortDate(person.createdAt)}',
                                        style: const TextStyle(
                                          color: Color(0xFF71717A),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Balance / Status Badge
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                  if (owes) ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => QuickReceiveSheet.show(context, personId: person.id),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF10B981)),
                                            SizedBox(width: 3),
                                            Text(
                                              'Receive',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label, PeopleFilter filter, PeopleFilter current, bool isDark) {
    final isSelected = filter == current;
    return InkWell(
      onTap: () => ref.read(peopleFilterProvider.notifier).setFilter(filter),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : isDark
                  ? const Color(0xFF18181B)
                  : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF10B981)
                : isDark
                    ? const Color(0xFFA1A1AA)
                    : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
