import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/widgets/screenshot_nav_icons.dart';
import 'package:duemate/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/screens/people_screen.dart';
import 'package:duemate/features/people/presentation/screens/person_details_screen.dart';
import 'package:duemate/features/reports/presentation/screens/reports_screen.dart';
import 'package:duemate/features/settings/presentation/screens/settings_screen.dart';
import 'package:duemate/features/welcome/presentation/screens/welcome_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _buildTabTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

CustomTransitionPage<void> _buildSlideTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final offset = Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).animate(curved);

      return SlideTransition(
        position: offset,
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => _buildSlideTransition(
          context: context,
          state: state,
          child: const WelcomeScreen(),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _buildTabTransition(
              context: context,
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/people',
            pageBuilder: (context, state) => _buildTabTransition(
              context: context,
              state: state,
              child: const PeopleScreen(),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _buildTabTransition(
              context: context,
              state: state,
              child: const ReportsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        pageBuilder: (context, state) => _buildSlideTransition(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/people/:id',
        pageBuilder: (context, state) {
          final personId = state.pathParameters['id']!;
          return _buildSlideTransition(
            context: context,
            state: state,
            child: PersonDetailsScreen(personId: personId),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-person',
        pageBuilder: (context, state) => _buildSlideTransition(
          context: context,
          state: state,
          child: const AddEditPersonScreen(),
        ),
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/people')) return 1;
    if (location.startsWith('/reports')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/people');
        break;
      case 2:
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final location = GoRouterState.of(context).uri.path;
    final isDashboard = location == '/';

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!isDashboard) {
          context.go('/');
          return true;
        }
        return false;
      },
      child: Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: _FloatingDockNavBar(
          selectedIndex: selectedIndex,
          onItemSelected: (index) => _onItemTapped(index, context),
        ),
      ),
    );
  }
}

class _FloatingDockNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _FloatingDockNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final labels = const [
      'Dashboard',
      'Directory',
      'Reports',
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF101124))
                    .withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(labels.length, (index) {
              final isSelected = selectedIndex == index;
              final label = labels[index];

              return Tooltip(
                message: label,
                child: InkWell(
                  onTap: () => onItemSelected(index),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? cs.surfaceContainerHigh
                              : const Color(0xFFEFF1FB))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.9),
                              width: 1,
                            )
                          : null,
                      boxShadow: isSelected && !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ScreenshotNavIcon(
                      index: index,
                      isSelected: isSelected,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF131438))
                          : cs.onSurfaceVariant.withValues(alpha: 0.75),
                      size: 22,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
