import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/main.dart';

void main() {
  testWidgets('DueMate app renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DueMateApp(),
      ),
    );

    // Initial pump and frame
    await tester.pumpAndSettle();

    // Verify DueMate title appears
    expect(find.text('DueMate'), findsWidgets);
  });
}
