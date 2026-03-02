import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/expenses/screens/expense_list_screen.dart';
import '../ui/travel/screens/trip_list_screen.dart';
import '../ui/travel/screens/trip_detail_screen.dart';
import '../ui/assets/screens/asset_overview_screen.dart';
import '../ui/assets/screens/account_history_screen.dart';
import '../ui/charts/widgets/stats_screen.dart';
import '../ui/settings/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/expenses',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ExpenseListScreen()),
        ),
        GoRoute(
          path: '/travel',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TripListScreen()),
          routes: [
            GoRoute(
              path: ':tripId',
              builder: (context, state) {
                final tripId =
                    int.parse(state.pathParameters['tripId']!);
                return TripDetailScreen(tripId: tripId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/assets',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AssetOverviewScreen()),
          routes: [
            GoRoute(
              path: ':accountId',
              builder: (context, state) {
                final accountId =
                    int.parse(state.pathParameters['accountId']!);
                return AccountHistoryScreen(accountId: accountId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/charts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StatsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static int _indexOf(String location) {
    if (location.startsWith('/expenses')) return 0;
    if (location.startsWith('/travel')) return 1;
    if (location.startsWith('/assets')) return 2;
    if (location.startsWith('/charts')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexOf(location),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/expenses');
            case 1:
              context.go('/travel');
            case 2:
              context.go('/assets');
            case 3:
              context.go('/charts');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_outlined),
            selectedIcon: Icon(Icons.flight),
            label: 'Travel',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Assets',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Charts',
          ),
        ],
      ),
    );
  }
}
