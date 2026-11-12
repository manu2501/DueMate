/// Values derived for the dashboard.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'ledger_providers.dart';

// Dashboard Top Debtors Provider (ordered by highest outstanding balance)
final topDebtorsProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      final owing = list
          .where((s) => s.person.id != AppConstants.selfPersonId && !s.person.isArchived && s.owesMoney)
          .toList();
      owing.sort((a, b) => b.balance.compareTo(a.balance));
      return owing;
    },
    orElse: () => [],
  );
});

class DashboardTotals {
  final double totalTheyOwe; // Money given out that is owed to user
  final double totalUserOwes; // Money user owes to others (overpaid/credit)
  final double netBalance;    // totalTheyOwe - totalUserOwes
  final double totalGiven;
  final double totalReceived;
  final int peopleOweUserCount;
  final int peopleUserOwesCount;

  const DashboardTotals({
    required this.totalTheyOwe,
    required this.totalUserOwes,
    required this.netBalance,
    required this.totalGiven,
    required this.totalReceived,
    required this.peopleOweUserCount,
    required this.peopleUserOwesCount,
  });

  static const empty = DashboardTotals(
    totalTheyOwe: 0,
    totalUserOwes: 0,
    netBalance: 0,
    totalGiven: 0,
    totalReceived: 0,
    peopleOweUserCount: 0,
    peopleUserOwesCount: 0,
  );
}

final dashboardTotalsProvider = Provider<DashboardTotals>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      double theyOwe = 0;
      double userOwes = 0;
      double given = 0;
      double received = 0;
      int oweUserCount = 0;
      int userOwesCount = 0;

      for (final s in list) {
        // The "self" row only holds the user's own EMIs/expenses, never money owed by/to others.
        if (s.person.id == AppConstants.selfPersonId) continue;
        if (!s.person.isArchived) {
          if (s.balance > 0.0001) {
            theyOwe += s.balance;
            oweUserCount++;
          } else if (s.balance < -0.0001) {
            userOwes += s.balance.abs();
            userOwesCount++;
          }
        }
        given += s.totalGiven;
        received += s.totalReceived;
      }

      return DashboardTotals(
        totalTheyOwe: theyOwe,
        totalUserOwes: userOwes,
        netBalance: theyOwe - userOwes,
        totalGiven: given,
        totalReceived: received,
        peopleOweUserCount: oweUserCount,
        peopleUserOwesCount: userOwesCount,
      );
    },
    orElse: () => DashboardTotals.empty,
  );
});

// Top 5 people ordered by highest absolute balance (debts or credits)
final topPeopleByBalanceProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      final active = list
          .where((s) =>
              s.person.id != AppConstants.selfPersonId && !s.person.isArchived && s.balance.abs() > 0.0001)
          .toList();
      active.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
      return active.take(5).toList();
    },
    orElse: () => [],
  );
});
