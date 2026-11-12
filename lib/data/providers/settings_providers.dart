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

/// Your UPI ID and the name payers see, for UPI QR codes and reminders.
@immutable
class UpiProfile {
  final String? id;
  final String? name;

  const UpiProfile({this.id, this.name});

  bool get isSet => id != null && id!.isNotEmpty;

  @override
  bool operator ==(Object other) => other is UpiProfile && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class UpiProfileNotifier extends Notifier<UpiProfile> {
  static const idKey = 'duemate_upi_id';
  static const nameKey = 'duemate_upi_name';

  @override
  UpiProfile build() {
    _load();
    return const UpiProfile();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = UpiProfile(id: prefs.getString(idKey), name: prefs.getString(nameKey));
  }

  /// Saves the profile; empty values clear it.
  Future<void> set({required String? id, required String? name}) async {
    final cleanId = (id ?? '').trim().toLowerCase();
    final cleanName = (name ?? '').trim();
    state = UpiProfile(id: cleanId.isEmpty ? null : cleanId, name: cleanName.isEmpty ? null : cleanName);
    final prefs = await SharedPreferences.getInstance();
    if (cleanId.isEmpty) {
      await prefs.remove(idKey);
    } else {
      await prefs.setString(idKey, cleanId);
    }
    if (cleanName.isEmpty) {
      await prefs.remove(nameKey);
    } else {
      await prefs.setString(nameKey, cleanName);
    }
  }
}

final upiProfileProvider = NotifierProvider<UpiProfileNotifier, UpiProfile>(UpiProfileNotifier.new);

/// UPI features only make sense when amounts are in rupees.
final upiAvailableProvider = Provider<bool>((ref) => ref.watch(currencySymbolProvider) == '₹');

/// Your UPI ID for messages asking to be paid, or null when not set or the
/// currency isn't rupees.
final upiIdForRemindersProvider = Provider<String?>(
  (ref) => ref.watch(upiAvailableProvider) ? ref.watch(upiProfileProvider).id : null,
);
