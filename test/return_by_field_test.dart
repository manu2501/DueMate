import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/widgets/return_by_field.dart';

void main() {
  final from = DateTime(2026, 11, 13);

  /// The field with its value held by a parent, as the sheets do.
  Future<ValueNotifier<DateTime?>> pump(WidgetTester tester, {DateTime? initial}) async {
    final value = ValueNotifier<DateTime?>(initial);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<DateTime?>(
          valueListenable: value,
          builder: (_, v, _) => ReturnByField(value: v, from: from, onChanged: (d) => value.value = d),
        ),
      ),
    ));
    return value;
  }

  testWidgets('starts as one link and opens to the quick picks', (tester) async {
    final value = await pump(tester);
    expect(find.text('Add a return-by date'), findsOneWidget);
    expect(find.text('1 week'), findsNothing);

    await tester.tap(find.text('Add a return-by date'));
    await tester.pump();
    await tester.tap(find.text('2 weeks'));
    await tester.pump();
    expect(value.value, DateTime(2026, 11, 27));
    expect(find.text('By 27 Nov 2026'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('already set: shown open; the close button clears it and folds back', (tester) async {
    final value = await pump(tester, initial: DateTime(2026, 11, 20));
    expect(find.text('Return by'), findsOneWidget);

    await tester.tap(find.byTooltip('No return-by date'));
    await tester.pump();
    expect(value.value, isNull);
    expect(find.text('Add a return-by date'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
