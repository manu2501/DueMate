import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/settings/presentation/screens/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(
    const ProviderScope(
      child: DueMateApp(),
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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(appLockEnabledProvider)) {
        ref.read(appIsLockedProvider.notifier).lock();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (ref.read(appLockEnabledProvider)) {
        ref.read(appIsLockedProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isLocked = ref.watch(appIsLockedProvider);

    return MaterialApp.router(
      title: 'DueMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (isLocked) {
          return Stack(
            children: [
              ?child,
              const AppLockScreen(),
            ],
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
