/// People list filtering, sorting and search.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/domain/loan_dues.dart';
import 'ledger_providers.dart';

// People Screen Filter & Sort Enums
enum PeopleFilter { all, active, overdue, settled, archived }
enum PeopleSort { highestOutstanding, recentlyActive, alphabetical, recentlyAdded }

class PeopleFilterNotifier extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => PeopleFilter.all;

  void setFilter(PeopleFilter filter) => state = filter;
}

final peopleFilterProvider = NotifierProvider<PeopleFilterNotifier, PeopleFilter>(PeopleFilterNotifier.new);

class PeopleSortNotifier extends Notifier<PeopleSort> {
  @override
  PeopleSort build() => PeopleSort.highestOutstanding;

  void setSort(PeopleSort sort) => state = sort;
}

final peopleSortProvider = NotifierProvider<PeopleSortNotifier, PeopleSort>(PeopleSortNotifier.new);

class PeopleSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final peopleSearchQueryProvider = NotifierProvider<PeopleSearchQueryNotifier, String>(PeopleSearchQueryNotifier.new);

// Filtered and Sorted People Provider
final filteredPersonSummariesProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  final filter = ref.watch(peopleFilterProvider);
  final sort = ref.watch(peopleSortProvider);
  final query = ref.watch(peopleSearchQueryProvider).trim().toLowerCase();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Only needed (and only watched) for the Overdue filter.
  final dues = filter == PeopleFilter.overdue ? ref.watch(loanDuesProvider) : const <String, LoanDueStatus>{};

  return summariesAsync.maybeWhen(
    data: (list) {
      var filtered = list.where((item) {
        if (item.person.id == AppConstants.selfPersonId) return false;

        // Apply Archive / Status Filter
        switch (filter) {
          case PeopleFilter.all:
            return !item.person.isArchived;
          case PeopleFilter.active:
            if (item.person.isArchived) return false;
            return item.balance.abs() > 0.0001;
          case PeopleFilter.overdue:
            if (item.person.isArchived) return false;
            return dues[item.person.id]?.isOverdue(today) ?? false;
          case PeopleFilter.settled:
            if (item.person.isArchived) return false;
            return item.balance.abs() <= 0.0001;
          case PeopleFilter.archived:
            return item.person.isArchived;
        }
      }).where((item) {
        // Apply Search Filter (name, phone, notes)
        if (query.isEmpty) return true;
        final nameMatch = item.person.name.toLowerCase().contains(query);
        final phoneMatch = item.person.phone?.toLowerCase().contains(query) ?? false;
        final notesMatch = item.person.notes?.toLowerCase().contains(query) ?? false;
        return nameMatch || phoneMatch || notesMatch;
      }).toList();

      // Apply Sorting
      switch (sort) {
        case PeopleSort.highestOutstanding:
          filtered.sort((a, b) => b.balance.compareTo(a.balance));
          break;
        case PeopleSort.recentlyActive:
          filtered.sort((a, b) {
            final aTime = a.lastTransaction?.transactionDate ?? a.person.createdAt;
            final bTime = b.lastTransaction?.transactionDate ?? b.person.createdAt;
            return bTime.compareTo(aTime);
          });
          break;
        case PeopleSort.alphabetical:
          filtered.sort((a, b) => a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase()));
          break;
        case PeopleSort.recentlyAdded:
          filtered.sort((a, b) => b.person.createdAt.compareTo(a.person.createdAt));
          break;
      }

      return filtered;
    },
    orElse: () => [],
  );
});
