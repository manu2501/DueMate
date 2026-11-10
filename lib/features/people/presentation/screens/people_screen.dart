import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/features/people/presentation/screens/add_edit_person_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortMenu(BuildContext context) {
    final currentSort = ref.read(peopleSortProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Sort People By',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.trending_up_rounded),
                title: const Text('Highest Outstanding'),
                trailing: currentSort == PeopleSort.highestOutstanding ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                onTap: () {
                  ref.read(peopleSortProvider.notifier).setSort(PeopleSort.highestOutstanding);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Recently Active'),
                trailing: currentSort == PeopleSort.recentlyActive ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                onTap: () {
                  ref.read(peopleSortProvider.notifier).setSort(PeopleSort.recentlyActive);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Alphabetical (A - Z)'),
                trailing: currentSort == PeopleSort.alphabetical ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                onTap: () {
                  ref.read(peopleSortProvider.notifier).setSort(PeopleSort.alphabetical);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.fiber_new_rounded),
                title: const Text('Recently Added'),
                trailing: currentSort == PeopleSort.recentlyAdded ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                onTap: () {
                  ref.read(peopleSortProvider.notifier).setSort(PeopleSort.recentlyAdded);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currentFilter = ref.watch(peopleFilterProvider);
    final people = ref.watch(filteredPersonSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'People',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sort Options',
            icon: const Icon(Icons.sort_rounded),
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
        label: const Text('Add Person'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people by name, phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(peopleSearchQueryProvider.notifier).setQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) {
                ref.read(peopleSearchQueryProvider.notifier).setQuery(val);
              },
            ),
          ),

          // Filter Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        badgeColor = const Color(0xFFDC2626);
                        badgeText = 'Owes ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
                      } else if (overpaid) {
                        badgeColor = const Color(0xFF9333EA);
                        badgeText = 'Overpaid ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
                      } else {
                        badgeColor = const Color(0xFF16A34A);
                        badgeText = '✓ Settled';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            context.push('/people/${person.id}');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
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
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      if (summary.lastTransaction != null)
                                        Text(
                                          'Last: ${DateFormatter.formatRelative(summary.lastTransaction!.transactionDate)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        )
                                      else if (person.phone != null && person.phone!.isNotEmpty)
                                        Text(
                                          person.phone!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        )
                                      else
                                        Text(
                                          'Added ${DateFormatter.formatShortDate(person.createdAt)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
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
                                        color: badgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 12,
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
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF16A34A)),
                                              SizedBox(width: 2),
                                              Text(
                                                'Receive',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF16A34A),
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

  Widget _filterChip(String label, PeopleFilter filter, PeopleFilter current) {
    final isSelected = filter == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(peopleFilterProvider.notifier).setFilter(filter);
      },
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
