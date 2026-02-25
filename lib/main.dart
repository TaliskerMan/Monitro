// Monitro Flutter UI — Main Entry Point
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/dashboard.dart';
import 'screens/screens.dart'; // processes, connections, users, api_monitor, alerts, settings
import 'screens/cpu_cores_screen.dart';
import 'theme/app_theme.dart';
import 'services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const MonitroApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/',           builder: (c, s) => const DashboardScreen()),
        GoRoute(path: '/processes',  builder: (c, s) => const ProcessesScreen()),
        GoRoute(path: '/cpu-cores',  builder: (c, s) => const CpuCoresScreen()),
        GoRoute(path: '/connections', builder: (c, s) => const ConnectionsScreen()),
        GoRoute(path: '/users',      builder: (c, s) => const UsersScreen()),
        GoRoute(path: '/api-calls',  builder: (c, s) => const ApiMonitorScreen()),
        GoRoute(path: '/alerts',     builder: (c, s) => const AlertsScreen()),
        GoRoute(path: '/settings',   builder: (c, s) => const SettingsScreen()),
      ],
    ),
  ],
);

class MonitroApp extends StatelessWidget {
  const MonitroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Monitro',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// App shell with sidebar navigation
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            backgroundColor: AppTheme.surface,
            selectedIndex: _navIndex(location),
            onDestinationSelected: (i) => _navigate(context, i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Icon(Icons.monitor_heart, color: AppTheme.accent, size: 32),
                const SizedBox(height: 4),
                Text('Monitro',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  )),
              ]),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.memory_outlined),
                selectedIcon: Icon(Icons.memory),
                label: Text('Processes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('CPU Cores'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cable_outlined),
                selectedIcon: Icon(Icons.cable),
                label: Text('Connections'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.api_outlined),
                selectedIcon: Icon(Icons.api),
                label: Text('API Calls'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Alerts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _navIndex(String location) {
    const routes = ['/', '/processes', '/cpu-cores', '/connections', '/users', '/api-calls', '/alerts', '/settings'];
    final i = routes.indexOf(location);
    return i < 0 ? 0 : i;
  }

  void _navigate(BuildContext context, int index) {
    const routes = ['/', '/processes', '/cpu-cores', '/connections', '/users', '/api-calls', '/alerts', '/settings'];
    context.go(routes[index]);
  }
}
