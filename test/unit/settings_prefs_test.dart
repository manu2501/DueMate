import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/data/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('with preloaded prefs, every setting is right on the first read (no default flash)', () async {
    SharedPreferences.setMockInitialValues({
      'duemate_hide_balances': true,
      'duemate_currency_symbol': '\$',
      'duemate_theme_mode': 'dark',
      'duemate_monthly_budget_limit': 40000.0,
      'duemate_upi_id': 'me@ybl',
      'duemate_app_lock_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    // Read synchronously, with no awaiting in between.
    expect(c.read(hideBalancesProvider), isTrue, reason: 'balances must never show before this loads');
    expect(c.read(currencySymbolProvider), '\$');
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(c.read(monthlyBudgetLimitProvider), 40000.0);
    expect(c.read(upiProfileProvider).id, 'me@ybl');
    expect(c.read(appLockSettingsProvider).enabled, isTrue);
  });

  test('without preloaded prefs, settings start at defaults and then load', () async {
    SharedPreferences.setMockInitialValues({'duemate_hide_balances': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(hideBalancesProvider), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(hideBalancesProvider), isTrue);
  });

  test('UPI profile saves normalized values and clears empty ones', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    await c.read(upiProfileProvider.notifier).set(id: ' Me@OKSBI ', name: ' Arjun ');
    expect(c.read(upiProfileProvider), const UpiProfile(id: 'me@oksbi', name: 'Arjun'));
    expect(prefs.getString(UpiProfileNotifier.idKey), 'me@oksbi');

    await c.read(upiProfileProvider.notifier).set(id: '', name: ' ');
    expect(c.read(upiProfileProvider).isSet, isFalse);
    expect(prefs.containsKey(UpiProfileNotifier.idKey), isFalse);
    expect(prefs.containsKey(UpiProfileNotifier.nameKey), isFalse);
  });
}
