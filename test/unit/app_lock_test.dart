import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/data/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppIsLockedNotifier toggles lock status correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appIsLockedProvider), isFalse);

    container.read(appIsLockedProvider.notifier).lock();
    expect(container.read(appIsLockedProvider), isTrue);

    container.read(appIsLockedProvider.notifier).unlock();
    expect(container.read(appIsLockedProvider), isFalse);
  });

  test('AppLockEnabledNotifier initializes to false by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appLockEnabledProvider), isFalse);
  });
}
