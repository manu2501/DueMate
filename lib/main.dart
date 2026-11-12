import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/navigation/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/emis/presentation/widgets/emi_details_sheet.dart';
import 'features/settings/presentation/screens/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Settings are loaded up front so they're right on the very first frame
  // (App Lock in force, amounts hidden). Independent of notifications, so
  // both start together.
  final prefsLoading = SharedPreferences.getInstance();
  await NotificationService().initialize();
  final prefs = await prefsLoading;
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const DueMateApp(),
    ),
  );
}

class DueMateApp extends ConsumerStatefulWidget {
  const DueMateApp({super.key});

  @override
  ConsumerState<DueMateApp> createState() => _DueMateAppState();
}

class _DueMateAppState extends ConsumerState<DueMateApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registered before the router's back-button dispatcher, so
    // [didPopRoute] gets the back press first.
    WidgetsBinding.instance.addObserver(this);
    // Keeps EMI due reminders scheduled for as long as the app runs.
    ref.listenManual(emiReminderSyncProvider, (_, _) {});
    // Tapping a reminder opens its EMI, whether the app was running or the
    // tap launched it. With App Lock on, it opens behind the lock screen.
    _reminderTaps = ref.read(emiReminderTapsProvider).listen(_openEmi);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await ref.read(emiReminderLaunchProvider)();
      if (id != null) _openEmi(id);
    });
  }

  StreamSubscription<String>? _reminderTaps;

  Future<void> _openEmi(String emiId) async {
    final emi = await ref.read(emiRepositoryProvider).getEmiById(emiId);
    if (emi == null || !mounted) return; // Deleted since the reminder was set.
    final person = emi.isForSelf ? null : ref.read(personsMapProvider)[emi.personId];
    final navContext = ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    EmiDetailsSheet.show(navContext, emi: emi, person: person);
  }

  @override
  void dispose() {
    _reminderTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockControllerProvider.notifier).onLifecycleChanged(state);
  }

  /// While locked, back must not pop the (hidden) pages behind the lock
  /// screen; it sends the app to the background instead.
  @override
  Future<bool> didPopRoute() async {
    if (!ref.read(appLockControllerProvider).locked) return false;
    SystemNavigator.pop().catchError((_) {});
    return true;
  }

  static final _lightTheme = AppTheme.light();
  static final _darkTheme = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DueMate',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
      // Lock state lives in its own widget so locking, and the privacy cover
      // on every trip to the background, don't rebuild the whole app.
      builder: (context, child) => _LockOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Draws the lock screen or privacy cover over the app. The tree shape stays
/// the same whether or not the app is covered, so locking never rebuilds the
/// router and open pages keep their state.
class _LockOverlay extends ConsumerWidget {
  final Widget child;
  const _LockOverlay({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (locked, obscured) = ref.watch(appLockControllerProvider.select((s) => (s.locked, s.obscured)));
    final covered = locked || obscured;

    ref.listen(appLockControllerProvider.select((s) => s.locked), (_, locked) {
      // Don't leave the keyboard up over the lock screen.
      if (locked) FocusManager.instance.primaryFocus?.unfocus();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        // Hidden content mustn't be read out by TalkBack or keep animating.
        ExcludeSemantics(
          excluding: covered,
          child: TickerMode(enabled: !covered, child: child),
        ),
        if (locked)
          const AppLockScreen()
        else if (obscured)
          const AppPrivacyCover(),
      ],
    );
  }
}
