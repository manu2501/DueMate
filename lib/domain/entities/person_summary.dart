import 'ledger_transaction.dart';
import 'person.dart';

class PersonSummary {
  final Person person;
  final double totalGiven;
  final double totalReceived;
  final double balance; // totalGiven - totalReceived
  final LedgerTransaction? lastTransaction;
  final int transactionCount;

  const PersonSummary({
    required this.person,
    required this.totalGiven,
    required this.totalReceived,
    required this.balance,
    this.lastTransaction,
    this.transactionCount = 0,
  });

  bool get owesMoney => balance > 0.0001;
  bool get isSettled => balance.abs() <= 0.0001 && (totalGiven > 0 || totalReceived > 0);
  bool get isOverpaid => balance < -0.0001;
  bool get hasNoTransactions => totalGiven == 0 && totalReceived == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonSummary &&
          runtimeType == other.runtimeType &&
          person.id == other.person.id &&
          balance == other.balance &&
          totalGiven == other.totalGiven &&
          totalReceived == other.totalReceived;

  @override
  int get hashCode => person.id.hashCode ^ balance.hashCode;
}

