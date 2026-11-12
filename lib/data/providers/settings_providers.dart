/// User settings persisted in SharedPreferences.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/domain/upi.dart';

/// Preferences loaded before `runApp`, so every setting is right on the very
/// first frame (no flash of real balances before "Hide amounts" loads, no
/// theme flicker, App Lock in force). Null only in tests that don't override
/// it; settings then fall back to loading asynchronously.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// A setting stored in SharedPreferences. Reads synchronously from the
/// preloaded instance when there is one.
abstract class PrefsNotifier<T> extends Notifier<T> {
  /// The setting as stored in [prefs], with defaults for missing keys.
  T read(SharedPreferences prefs);

  /// Used until prefs load, when they weren't preloaded.
  T get initial;

  SharedPreferences? _prefs;

  @override
  T build() {
    final prefs = _prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) return read(prefs);
    SharedPreferences.getInstance().then((p) {
      _prefs = p;
      if (ref.mounted) state = read(p);
    });
    return initial;
  }

  /// The prefs instance captured in [build] (setters run outside it).
  Future<SharedPreferences> prefs() async => _prefs ??= await SharedPreferences.getInstance();

  /// Stores [value], or removes [key] when it's null.
  Future<void> putString(String key, String? value) async {
    final p = await prefs();
    value == null ? await p.remove(key) : await p.setString(key, value);
  }
}

class CurrencyNotifier extends PrefsNotifier<String> {
  static const _key = 'duemate_currency_symbol';

  @override
  String get initial => AppConstants.defaultCurrencySymbol;

  @override
  String read(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    return saved == null || saved.isEmpty ? initial : saved;
  }

  Future<void> setCurrency(String symbol) async {
    state = symbol;
    await putString(_key, symbol);
  }
}

final currencySymbolProvider = NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

/// "Hide amounts": masks balances and totals on screen, e.g. in public.
class HideBalancesNotifier extends PrefsNotifier<bool> {
  static const _key = 'duemate_hide_balances';

  @override
  bool get initial => false;

  @override
  bool read(SharedPreferences prefs) => prefs.getBool(_key) ?? initial;

  Future<void> set(bool hidden) async {
    state = hidden;
    await (await prefs()).setBool(_key, hidden);
  }

  Future<void> toggle() => set(!state);
}

final hideBalancesProvider = NotifierProvider<HideBalancesNotifier, bool>(HideBalancesNotifier.new);

/// Formatter for on-screen amounts; masked while amounts are hidden.
final displayMoneyProvider = Provider<DisplayMoney>((ref) => DisplayMoney(
      symbol: ref.watch(currencySymbolProvider),
      hidden: ref.watch(hideBalancesProvider),
    ));

class ThemeModeNotifier extends PrefsNotifier<ThemeMode> {
  static const _key = 'duemate_theme_mode';

  @override
  ThemeMode get initial => ThemeMode.system;

  @override
  ThemeMode read(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => initial);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await putString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Your UPI ID and the name payers see, for UPI QR codes and reminders.
@immutable
class UpiProfile {
  final String? id;
  final String? name;

  const UpiProfile({this.id, this.name});

  /// The notifier never stores empty strings, so null means "not set".
  bool get isSet => id != null;

  @override
  bool operator ==(Object other) => other is UpiProfile && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class UpiProfileNotifier extends PrefsNotifier<UpiProfile> {
  static const idKey = 'duemate_upi_id';
  static const nameKey = 'duemate_upi_name';

  @override
  UpiProfile get initial => const UpiProfile();

  @override
  UpiProfile read(SharedPreferences prefs) =>
      UpiProfile(id: prefs.getString(idKey), name: prefs.getString(nameKey));

  /// Saves the profile; empty values clear it.
  Future<void> set({required String? id, required String? name}) async {
    String? orNull(String s) => s.isEmpty ? null : s;
    final profile = UpiProfile(id: orNull(Upi.normalizeId(id ?? '')), name: orNull((name ?? '').trim()));
    state = profile;
    await putString(idKey, profile.id);
    await putString(nameKey, profile.name);
  }
}

final upiProfileProvider = NotifierProvider<UpiProfileNotifier, UpiProfile>(UpiProfileNotifier.new);

/// UPI features only make sense when amounts are in rupees.
final upiAvailableProvider =
    Provider<bool>((ref) => ref.watch(currencySymbolProvider) == Upi.currencySymbol);

/// Your UPI ID for messages asking to be paid, or null when not set or the
/// currency isn't rupees.
final upiIdForRemindersProvider = Provider<String?>(
  (ref) => ref.watch(upiAvailableProvider) ? ref.watch(upiProfileProvider).id : null,
);
