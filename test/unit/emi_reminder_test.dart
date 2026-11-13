import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/services/notification_service.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, CreditCardEmi;
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/emi_reminder_planner.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';

CreditCardEmi _emi({
  String id = 'e1',
  String personId = AppConstants.selfPersonId,
  int paid = 0,
  int tenure = 12,
  String status = 'active',
  DateTime? start,
  int dueDay = 10,
  String? custom,
}) {
  final t = DateTime(2026, 1, 1);
  return CreditCardEmi(
    id: id,
    personId: personId,
    itemName: 'Phone',
    cardName: 'HDFC',
    totalAmount: 12000,
    monthlyInstallment: 1000,
    totalTenureMonths: tenure,
    installmentsPaid: paid,
    startDate: start ?? DateTime(2026, 11, 10),
    dueDayOfMonth: dueDay,
    status: status,
    customScheduleJson: custom,
    createdAt: t,
    updatedAt: t,
  );
}

class _FakeScheduler implements ReminderScheduler {
  final plans = <List<Reminder>>[];
  @override
  Future<void> replaceReminders(List<Reminder> plan) async => plans.add(plan);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 12, 12); // noon, 12 Nov

  group('EmiReminderPlanner', () {
    String money(double a) => '₹${a.toStringAsFixed(0)}';

    test('next three unpaid installments, the day before at 9:00, oldest first', () {
      // Installment 1 was due 10 Nov (past). 2..4: 10 Dec, 10 Jan, 10 Feb.
      final plan = EmiReminderPlanner.plan([_emi(paid: 1)], now: now, amountText: money);
      expect(plan.map((r) => r.at), [
        DateTime(2026, 12, 9, 9),
        DateTime(2027, 1, 9, 9),
        DateTime(2027, 2, 9, 9),
      ]);
      expect(plan.first.title, 'Phone due tomorrow');
      expect(plan.first.body, '₹1000 · installment 2 of 12 · HDFC');
    });

    test('due today (or tomorrow with 9:00 passed) falls back to 9:00 on the day', () {
      final dueTomorrow = _emi(start: DateTime(2026, 11, 13), dueDay: 13);
      expect(EmiReminderPlanner.plan([dueTomorrow], now: now).first.at, DateTime(2026, 11, 13, 9));
      expect(EmiReminderPlanner.plan([dueTomorrow], now: now).first.title, 'Phone due today');

      final dueToday = _emi(start: DateTime(2026, 11, 12), dueDay: 12);
      final early = DateTime(2026, 11, 12, 7);
      expect(EmiReminderPlanner.plan([dueToday], now: early).first.at, DateTime(2026, 11, 12, 9));
      expect(EmiReminderPlanner.plan([dueToday], now: now).first.at, DateTime(2026, 12, 11, 9),
          reason: 'today 9:00 has passed; next one');
    });

    test('skips installments already paid ahead; reminds of the unpaid ones', () {
      // #1 and #3 are posted (#3 paid ahead): remind #2, #4, #5.
      final plan = EmiReminderPlanner.plan([_emi(paid: 2)], now: now, posted: {'e1': {1, 3}});
      expect(plan.map((r) => r.body.split(' · ').first), ['installment 2 of 12', 'installment 4 of 12', 'installment 5 of 12']);
    });

    test('stops at the last installment and skips finished or cancelled EMIs', () {
      expect(EmiReminderPlanner.plan([_emi(paid: 11)], now: now), hasLength(1));
      expect(EmiReminderPlanner.plan([_emi(paid: 12)], now: now), isEmpty);
      expect(EmiReminderPlanner.plan([_emi(status: 'cancelled')], now: now), isEmpty);
      expect(EmiReminderPlanner.plan([_emi(status: 'completed')], now: now), isEmpty);
    });

    test('uses per-month custom amounts, names the person, and can leave amounts out', () {
      final e = _emi(paid: 1, personId: 'p', custom: '{"2": 1500}');
      final withAmounts = EmiReminderPlanner.plan([e], now: now, amountText: money, whoFor: (_) => 'Rahul');
      expect(withAmounts.first.body, '₹1500 · installment 2 of 12 · HDFC · with Rahul');
      final hidden = EmiReminderPlanner.plan([e], now: now, whoFor: (_) => 'Rahul');
      expect(hidden.first.body, 'installment 2 of 12 · HDFC · with Rahul');
    });

    test('ids are stable across plans, unique, and valid notification ids', () {
      final a = EmiReminderPlanner.plan([_emi(), _emi(id: 'e2')], now: now);
      final b = EmiReminderPlanner.plan([_emi(), _emi(id: 'e2')], now: now);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      expect(a.map((r) => r.id).toSet(), hasLength(a.length));
      expect(a.every((r) => r.id >= 0 && r.id <= 0x7fffffff), isTrue);
      expect(a, b, reason: 'equal plans compare equal, so unchanged plans are skipped');
    });
  });

  group('reminderSyncProvider', () {
    test('reschedules when EMIs change, and hides amounts when asked', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final scheduler = _FakeScheduler();
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ]);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      c.listen(reminderSyncProvider, (_, _) {});

      Future<List<Reminder>> settled() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return scheduler.plans.last;
      }

      expect(await settled(), isEmpty, reason: 'no EMIs yet');

      final t = DateTime.now();
      await PersonRepositoryImpl(db).createPerson(Person(id: 'p', name: 'Rahul', createdAt: t, updatedAt: t));
      final next = DateTime(t.year, t.month + 1, 15);
      await EmiRepositoryImpl(db).createEmi(_emi(personId: 'p', start: next, dueDay: 15));
      final plan = await settled();
      expect(plan, hasLength(3));
      expect(plan.first.body, contains('with Rahul'));
      expect(plan.first.body, contains('₹'));

      await c.read(hideBalancesProvider.notifier).set(true);
      expect((await settled()).first.body, isNot(contains('₹')));

      await EmiRepositoryImpl(db).deleteEmi('e1');
      expect(await settled(), isEmpty, reason: 'deleted EMI: reminders cancelled');
    });

    test('money due back is reminded too, and repaying cancels it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final scheduler = _FakeScheduler();
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ]);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      c.listen(reminderSyncProvider, (_, _) {});
      Future<List<Reminder>> settled() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return scheduler.plans.last;
      }

      final t = DateTime.now();
      await PersonRepositoryImpl(db).createPerson(Person(id: 'p', name: 'Asha', createdAt: t, updatedAt: t));
      LedgerTransaction tx(String id, TransactionType type, {DateTime? due}) => LedgerTransaction(
            id: id,
            personId: 'p',
            type: type,
            amount: 2000,
            transactionDate: t,
            paymentMethod: PaymentMethod.cash,
            dueDate: due,
            createdAt: t,
            updatedAt: t,
          );
      await TransactionRepositoryImpl(db)
          .addTransaction(tx('g', TransactionType.moneyGiven, due: t.add(const Duration(days: 10))));
      final plan = await settled();
      expect(plan.single.target, const PersonTarget('p'));
      expect(plan.single.title, contains('due back from Asha'));

      await TransactionRepositoryImpl(db).addTransaction(tx('r', TransactionType.paymentReceived));
      expect(await settled(), isEmpty, reason: 'paid back: nothing left to remind');
    });
  });
}
