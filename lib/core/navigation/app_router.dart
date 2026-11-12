import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/theme/app_motion.dart';
import 'package:duemate/core/widgets/dock_nav_icon.dart';
import 'package:duemate/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/expenses/presentation/screens/expense_charts_screen.dart';
import 'package:duemate/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/screens/people_screen.dart';
import 'package:duemate/features/people/presentation/screens/person_details_screen.dart';
import 'package:duemate/features/reports/presentation/screens/reports_screen.dart';
import 'package:duemate/features/settings/presentation/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Peer tabs: fade through, no direction.
CustomTransitionPage<void> _buildTabTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.short,
    transitionsBuilder: AppMotion.fadeThrough,
  );
}

/// Going deeper: shared-axis slide, so back has a direction.
CustomTransitionPage<void> _buildSlideTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.medium,
    transitionsBuilder: AppMotion.sharedAxisX,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
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
            path: '/expenses',
            pageBuilder: (context, state) => _buildTabTransition(
              context: context,
              state: state,
              child: ExpensesScreen(initialTab: state.uri.queryParameters['tab']),
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
        path: '/expense-charts',
        pageBuilder: (context, state) => _buildSlideTransition(
          context: context,
          state: state,
          child: const ExpenseChartsScreen(),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-emi',
        pageBuilder: (context, state) {
          final personId = state.uri.queryParameters['personId'];
          return _buildSlideTransition(
            context: context,
            state: state,
            child: AddEditEmiScreen(initialPersonId: personId),
          );
        },
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
    if (location.startsWith('/expenses')) return 2;
    if (location.startsWith('/reports')) return 3;
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
        context.go('/expenses');
        break;
      case 3:
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final location = GoRouterState.of(context).uri.path;
    final isDashboard = location == '/';

    // PopScope (not BackButtonListener): it is only consulted when the shell
    // is the top route. A router-level listener fires first and would swallow
    // back presses meant for forms/sheets pushed above the tabs.
    return PopScope(
      canPop: isDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: _AppNavBar(
          selectedIndex: selectedIndex,
          onItemSelected: (index) => _onItemTapped(index, context),
        ),
      ),
    );
  }
}

class _AppNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _AppNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'People', 'Expenses', 'Activity'];

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      destinations: [
        for (var i = 0; i < labels.length; i++)
          NavigationDestination(
            label: labels[i],
            tooltip: labels[i],
            icon: DockNavIcon(
              index: i,
              isSelected: false,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            selectedIcon: DockNavIcon(
              index: i,
              isSelected: true,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
      ],
    );
  }
}
