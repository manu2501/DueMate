import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/tables.dart';
import '../../domain/entities/credit_card_emi.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/repositories/emi_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

class EmiProcessorResult {
  final int emisChecked;
  final int installmentsGenerated;

  const EmiProcessorResult({
    required this.emisChecked,
    required this.installmentsGenerated,
  });
}

class EmiProcessorService {
  final EmiRepository emiRepository;
  final TransactionRepository transactionRepository;
  final db.AppDatabase database;

  EmiProcessorService({
    required this.emiRepository,
    required this.transactionRepository,
    required this.database,
  });

  /// Automatically scans all active EMIs and generates any due monthly installment transactions
  Future<EmiProcessorResult> processDueInstallments({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final activeEmis = await emiRepository.getActiveEmis();
    int generatedCount = 0;

    for (final emi in activeEmis) {
      int newlyGeneratedForEmi = 0;

      // Installments the user declared as already paid have no ledger rows.
      // Treat them as a baseline so they are never re-posted.
      final postedBefore = await countPostedInstallments(emi.id);
      final prepaid = (emi.installmentsPaid - postedBefore).clamp(0, emi.totalTenureMonths);

      for (int k = prepaid + 1; k <= emi.totalTenureMonths; k++) {
        final dueDate = emi.getDueDateForInstallment(k);

        // Check if installment is due as of the reference date
        if (dueDate.isBefore(now) || _isSameDay(dueDate, now)) {
          final alreadyPosted = await _isInstallmentPosted(emi.id, k);

          if (!alreadyPosted) {
            final tx = LedgerTransaction(
              id: const Uuid().v4(),
              personId: emi.personId,
              type: emi.isPaidByMe ? TransactionType.moneyGiven : TransactionType.paymentReceived,
              amount: emi.getMonthlyInstallmentFor(k),
              transactionDate: dueDate,
              paymentMethod: PaymentMethod.card,
              note: 'EMI $k/${emi.totalTenureMonths}: ${emi.itemName} (${emi.cardName})',
              emiId: emi.id,
              installmentNumber: k,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await transactionRepository.addTransaction(tx);
            generatedCount++;
            newlyGeneratedForEmi++;
          }
        }
      }

      // Re-query total posted installments to update emi status accurately
      final totalPosted = prepaid + await countPostedInstallments(emi.id);
      final isNowCompleted = totalPosted >= emi.totalTenureMonths;

      if (totalPosted != emi.installmentsPaid || isNowCompleted || newlyGeneratedForEmi > 0) {
        final updatedEmi = emi.copyWith(
          installmentsPaid: totalPosted,
          status: isNowCompleted ? 'completed' : emi.status,
          lastProcessedDate: now,
          updatedAt: DateTime.now(),
        );
        await emiRepository.updateEmi(updatedEmi);
      }
    }

    return EmiProcessorResult(
      emisChecked: activeEmis.length,
      installmentsGenerated: generatedCount,
    );
  }

  /// Manually posts the next installment for an EMI immediately
  Future<bool> postNextInstallment(CreditCardEmi emi) async {
    if (emi.isCompleted || emi.installmentsPaid >= emi.totalTenureMonths) {
      return false;
    }

    final postedBefore = await countPostedInstallments(emi.id);
    final nextNumber = emi.installmentsPaid + 1;
    final alreadyPosted = await _isInstallmentPosted(emi.id, nextNumber);
    if (alreadyPosted) return false;

    final dueDate = emi.getDueDateForInstallment(nextNumber);

    final tx = LedgerTransaction(
      id: const Uuid().v4(),
      personId: emi.personId,
      type: emi.isPaidByMe ? TransactionType.moneyGiven : TransactionType.paymentReceived,
      amount: emi.getMonthlyInstallmentFor(nextNumber),
      transactionDate: dueDate,
      paymentMethod: PaymentMethod.card,
      note: 'EMI $nextNumber/${emi.totalTenureMonths}: ${emi.itemName} (${emi.cardName})',
      emiId: emi.id,
      installmentNumber: nextNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await transactionRepository.addTransaction(tx);

    final prepaid = (emi.installmentsPaid - postedBefore).clamp(0, emi.totalTenureMonths);
    final totalPosted = prepaid + await countPostedInstallments(emi.id);
    final updated = emi.copyWith(
      installmentsPaid: totalPosted,
      status: totalPosted >= emi.totalTenureMonths ? 'completed' : emi.status,
      lastProcessedDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await emiRepository.updateEmi(updated);

    return true;
  }

  Future<bool> _isInstallmentPosted(String emiId, int installmentNumber) async {
    final query = database.select(database.transactions)
      ..where((tbl) => tbl.emiId.equals(emiId) & tbl.installmentNumber.equals(installmentNumber));
    final count = await query.get();
    return count.isNotEmpty;
  }

  Future<int> countPostedInstallments(String emiId) async {
    final query = database.select(database.transactions)..where((tbl) => tbl.emiId.equals(emiId));
    final rows = await query.get();
    return rows.length;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
