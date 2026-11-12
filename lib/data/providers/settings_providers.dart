/// User settings persisted in SharedPreferences.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/display_money.dart';

// App Settings Notifiers with persistent SharedPreferences storage
class CurrencyNotifier extends Notifier<String> {
  static const _key = 'duemate_currency_symbol';

  @override
  String build() {
    _load();
    return AppConstants.defaultCurrencySymbol;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setCurrency(String symbol) async {
    state = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, symbol);
  }
}

final currencySymbolProvider = NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

/// "Hide amounts": masks balances and totals on screen, e.g. in public.
class HideBalancesNotifier extends Notifier<bool> {
  static const _key = 'duemate_hide_balances';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) state = saved;
  }

  Future<void> set(bool hidden) async {
    state = hidden;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, hidden);
  }

  Future<void> toggle() => set(!state);
}

final hideBalancesProvider = NotifierProvider<HideBalancesNotifier, bool>(HideBalancesNotifier.new);

/// Formatter for on-screen amounts; masked while amounts are hidden.
final displayMoneyProvider = Provider<DisplayMoney>((ref) => DisplayMoney(
      symbol: ref.watch(currencySymbolProvider),
      hidden: ref.watch(hideBalancesProvider),
    ));

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'duemate_theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
