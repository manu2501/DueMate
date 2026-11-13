import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/domain/loan_dues.dart';

void main() {
  Future<void> pump(WidgetTester tester, RepaymentRecord record) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: RepaymentRecordLine(record))));

  testWidgets('hidden until a dated loan has been paid back', (tester) async {
    await pump(tester, const RepaymentRecord());
    expect(find.textContaining('Repaid on time'), findsNothing);
    // Only overdue so far: the due-back line already says so.
    await pump(tester, const RepaymentRecord(missed: 1));
    expect(find.textContaining('Repaid on time'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('counts every judged loan, missed ones included', (tester) async {
    await pump(tester, const RepaymentRecord(onTime: 2, late: 1, missed: 1));
    expect(find.text('Repaid on time: 2 of 4 loans (50%)'), findsOneWidget);
    await pump(tester, const RepaymentRecord(onTime: 1));
    expect(find.text('Repaid on time: 1 of 1 loan (100%)'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
