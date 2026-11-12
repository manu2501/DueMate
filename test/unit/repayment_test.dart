import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';

PersonSummary _s(double given, double received) {
  final t = DateTime(2026);
  return PersonSummary(
    person: Person(id: 'p', name: 'P', createdAt: t, updatedAt: t),
    totalGiven: given,
    totalReceived: received,
    balance: given - received,
  );
}

void main() {
  test('they owe you: what they repaid of what you gave', () {
    final r = _s(15000, 2500).repayment!;
    expect((r.paid, r.of, r.byYou), (2500.0, 15000.0, false));
    expect(r.fraction, closeTo(0.1667, 0.001));
    expect(r.percent, 16, reason: 'rounded down, never overstated');
  });

  test('settled: fully paid', () {
    final r = _s(1200, 1200).repayment!;
    expect((r.fraction, r.percent, r.byYou), (1.0, 100, false));
  });

  test('you owe them: what you repaid of what they gave', () {
    final r = _s(1000, 3000).repayment!;
    expect((r.paid, r.of, r.byYou, r.percent), (1000.0, 3000.0, true, 33));
    final none = _s(0, 3000).repayment!;
    expect((none.paid, none.percent), (0.0, 0));
  });

  test('100% only when fully paid; no entries: nothing to show', () {
    expect(_s(1000, 999.99).repayment!.percent, 99);
    expect(_s(0, 0).repayment, isNull);
  });
}
