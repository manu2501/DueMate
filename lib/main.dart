import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/navigation/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/settings/presentation/screens/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  // Loaded up front so App Lock is in force on the very first frame.
  final prefs = await SharedPreferences.getInstance();
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
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lock = ref.watch(appLockControllerProvider);

    ref.listen(appLockControllerProvider.select((s) => s.locked), (_, locked) {
      // Don't leave the keyboard up over the lock screen.
      if (locked) FocusManager.instance.primaryFocus?.unfocus();
    });

    return MaterialApp.router(
      title: 'DueMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      // The tree shape stays the same whether or not the app is covered, so
      // locking never rebuilds the router and open pages keep their state.
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          // Hidden content mustn't be read out by TalkBack or keep animating.
          ExcludeSemantics(
            excluding: lock.covered,
            child: TickerMode(enabled: !lock.covered, child: child ?? const SizedBox.shrink()),
          ),
          if (lock.locked)
            const AppLockScreen()
          else if (lock.obscured)
            const AppPrivacyCover(),
        ],
      ),
    );
  }
}
