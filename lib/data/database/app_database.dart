import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Persons, Transactions, CreditCardEmis, Expenses, RecurringExpenses, EmiPayments])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'duemate_db'));

  @override
  int get schemaVersion => 12;

  /// Your own EMI installments are repayments, kept in [emiPayments]. Older
  /// versions posted them to the hidden "self" ledger (before v11) or to
  /// expenses (v11); both move here with the same id, amount and date. Runs
  /// on upgrade to v12 and after restoring an older backup; does nothing once
  /// there is nothing left to move. A purchase expense (EMI id without an
  /// installment number) stays in expenses.
  Future<void> moveEmiPostingsToPayments() => transaction(() async {
        const self = AppConstants.selfPersonId;
        const cols = 'id, emi_id, installment_number, amount, paid_on, payment_method, note, created_at, updated_at';
        await customStatement(
          'INSERT OR IGNORE INTO emi_payments ($cols) '
          'SELECT t.id, t.emi_id, coalesce(t.installment_number, 0), t.amount, t.transaction_date, t.payment_method, '
          "coalesce('EMI ' || t.installment_number || '/' || e.total_tenure_months || ' · ' || e.card_name, t.note), "
          't.created_at, t.updated_at '
          'FROM transactions t LEFT JOIN credit_card_emis e ON e.id = t.emi_id '
          "WHERE t.person_id = '$self' AND t.emi_id IS NOT NULL",
        );
        await customStatement("DELETE FROM transactions WHERE person_id = '$self' AND emi_id IS NOT NULL");
        await customStatement(
          'INSERT OR IGNORE INTO emi_payments ($cols) '
          'SELECT id, emi_id, installment_number, amount, expense_date, payment_method, notes, created_at, updated_at '
          'FROM expenses WHERE emi_id IS NOT NULL AND installment_number IS NOT NULL',
        );
        await customStatement('DELETE FROM expenses WHERE emi_id IS NOT NULL AND installment_number IS NOT NULL');
      });

  /// One installment of an EMI is no longer paid (its ledger entry was
  /// deleted): counts one fewer and reopens a finished EMI. No-op if the EMI
  /// itself is gone.
  Future<void> releaseEmiInstallment(String emiId) => customUpdate(
        'UPDATE credit_card_emis SET installments_paid = max(installments_paid - 1, 0), '
        "status = CASE WHEN status = 'completed' THEN 'active' ELSE status END WHERE id = ?1",
        variables: [Variable.withString(emiId)],
        updates: {creditCardEmis},
      );

  /// Deletes every person, transaction, EMI, EMI payment, expense and
  /// recurring expense, in one transaction.
  /// The user's own "self" row is kept: EMIs and expenses added afterwards
  /// reference it.
  Future<void> eraseAllData() => transaction(() async {
        await delete(transactions).go();
        await delete(creditCardEmis).go();
        await delete(expenses).go();
        await delete(emiPayments).go();
        await delete(recurringExpenses).go();
        await (delete(persons)..where((p) => p.id.equals(AppConstants.selfPersonId).not())).go();
      });

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
      if (from < 4) {
        await m.addColumn(transactions, transactions.isSettled);
      }
      if (from < 5) {
        await m.addColumn(creditCardEmis, creditCardEmis.customScheduleJson);
      }
      if (from < 6) {
        await m.addColumn(creditCardEmis, creditCardEmis.interestRate);
        await m.addColumn(creditCardEmis, creditCardEmis.interestType);
      }
      if (from < 7) {
        await m.addColumn(creditCardEmis, creditCardEmis.kind);
        await m.addColumn(creditCardEmis, creditCardEmis.planMode);
        await m.addColumn(creditCardEmis, creditCardEmis.principal);
        await m.addColumn(creditCardEmis, creditCardEmis.charges);
        // Existing rows: carry over what the UI used to guess from the names.
        await customStatement(
          "UPDATE credit_card_emis SET kind = 'loan' WHERE "
          "lower(card_name) LIKE '%loan%' OR lower(item_name) LIKE '%loan%' OR "
          "lower(card_name) LIKE '%cash%' OR lower(card_name) LIKE '%transfer%' OR "
          "lower(coalesce(notes, '')) LIKE '%loan%'",
        );
      }
      if (from < 8) {
        await m.addColumn(persons, persons.upiId);
      }
      if (from < 9) {
        await m.createTable(recurringExpenses);
        await m.addColumn(expenses, expenses.recurringId);
      }
      if (from < 10) {
        await m.addColumn(transactions, transactions.dueDate);
      }
      if (from < 11) {
        await m.addColumn(expenses, expenses.emiId);
        await m.addColumn(expenses, expenses.installmentNumber);
      }
      if (from < 12) {
        await m.createTable(emiPayments);
        await moveEmiPostingsToPayments();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');

      // Ensure Self / Personal Vault record exists in persons table so FK checks pass 100%
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await customStatement(
        "INSERT OR IGNORE INTO persons (id, name, created_at, updated_at) "
        "VALUES ('${AppConstants.selfPersonId}', 'Myself (Personal)', $nowSec, $nowSec)"
      );

      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_person_id ON transactions(person_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_emi_id ON transactions(emi_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_emis_person_id ON credit_card_emis(person_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_emi_id ON expenses(emi_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_emi_payments_emi_id ON emi_payments(emi_id)');
    },
  );
}
