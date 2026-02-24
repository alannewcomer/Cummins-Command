import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/command_center/command_center_screen.dart';
import '../features/data_explorer/data_explorer_screen.dart';
import '../features/drive_history/drive_history_screen.dart';
import '../features/drive_history/drive_detail_screen.dart';
import '../features/drive_history/route_detail_screen.dart';
import '../features/ai_insights/ai_insights_screen.dart';
import '../features/maintenance/maintenance_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/onboarding/bluetooth_setup_screen.dart';
import '../features/debug/debug_log_screen.dart';
import '../features/debug/did_scanner_screen.dart';
import '../features/vehicles/add_vehicle_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import 'theme.dart';

/// Listens to auth + vehicle state and notifies GoRouter to re-evaluate redirects.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(vehiclesStreamProvider, (_, __) => notifyListeners());
  }
}

/// Auth-aware GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // Still loading auth — don't redirect yet
      if (authAsync.isLoading) return null;

      final isAuthenticated = authAsync.value != null;
      final loc = state.matchedLocation;

      // Not signed in → sign-in screen
      if (!isAuthenticated) {
        return loc == '/sign-in' ? null : '/sign-in';
      }

      // Signed in → off sign-in screen
      if (loc == '/sign-in') return '/';

      // First-time setup: no vehicles → add-vehicle screen
      final vehiclesAsync = ref.read(vehiclesStreamProvider);
      if (vehiclesAsync.hasValue &&
          vehiclesAsync.value!.isEmpty &&
          loc != '/add-vehicle') {
        return '/add-vehicle';
      }

      return null;
    },
    routes: [
      // ── Auth ──
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SignInScreen(),
        ),
      ),

      // ── Add / first-time vehicle setup ──
      GoRoute(
        path: '/add-vehicle',
        builder: (context, state) => const AddVehicleScreen(),
      ),

      // ── Main app shell with bottom navigation ──
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CommandCenterScreen(),
            ),
          ),
          GoRoute(
            path: '/explorer',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DataExplorerScreen(),
            ),
          ),
          GoRoute(
            path: '/drives',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DriveHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AiInsightsScreen(),
            ),
          ),
          GoRoute(
            path: '/maintenance',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MaintenanceScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // ── Detail routes (outside shell for full-screen) ──
      GoRoute(
        path: '/drives/:driveId',
        builder: (context, state) => DriveDetailScreen(
          driveId: state.pathParameters['driveId']!,
        ),
      ),
      GoRoute(
        path: '/routes/:routeId',
        builder: (context, state) => RouteDetailScreen(
          routeId: state.pathParameters['routeId']!,
        ),
      ),
      GoRoute(
        path: '/bluetooth-setup',
        builder: (context, state) => const BluetoothSetupScreen(),
      ),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugLogScreen(),
      ),
      GoRoute(
        path: '/did-scanner',
        builder: (context, state) => const DidScannerScreen(),
      ),
    ],
  );
});

/// App shell with bottom navigation.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static int _indexFromLocation(String location) {
    if (location.startsWith('/explorer')) return 1;
    if (location.startsWith('/drives')) return 2;
    if (location.startsWith('/ai')) return 3;
    if (location.startsWith('/maintenance')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/');
              case 1:
                context.go('/explorer');
              case 2:
                context.go('/drives');
              case 3:
                context.go('/ai');
              case 4:
                context.go('/maintenance');
              case 5:
                context.go('/settings');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Command',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Explorer',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Drives',
            ),
            NavigationDestination(
              icon: Icon(Icons.diamond_outlined),
              selectedIcon: Icon(Icons.diamond),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'Service',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
