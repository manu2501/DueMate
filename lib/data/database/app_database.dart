import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Persons, Transactions, CreditCardEmis, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'duemate_db'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(creditCardEmis);
        await m.addColumn(transactions, transactions.emiId);
        await m.addColumn(transactions, transactions.installmentNumber);
      }
      if (from < 3) {
        await m.createTable(expenses);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_person_id ON transactions(person_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_emi_id ON transactions(emi_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_emis_person_id ON credit_card_emis(person_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date DESC)');
    },
  );
}
