import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/setup_screen.dart';
import 'screens/dashboard.dart';
import 'screens/screens.dart'; // processes, connections, users, api_monitor, alerts, settings
import 'screens/cpu_cores_screen.dart';
import 'screens/service_control_screen.dart';
import 'screens/about_screen.dart';
import 'theme/app_theme.dart';
import 'services/preferences_service.dart';
import 'services/backend_service.dart';
import 'services/config_generator.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main execution entrypoint for the Monitro desktop frontend application.
/// 
/// Initializes SharedPreferences storage, performs early configuration verification
/// to boot the collector service if available, and runs the root MaterialApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();

  // If already configured, boot the system metrics collection daemon
  final dbUser = sharedPrefs.getString('mariadbUser');
  if (dbUser != null) {
    // Read the settings from local shared preferences storage
    final settings = SettingsController.loadSettings(sharedPrefs);
    // Build a collector configuration file with details from settings
    final configPath = await ConfigGenerator.generateConfig(settings);
    // Boot the collector service daemon using the built config path
    await BackendService.start(configPath);
  }

  // Initialize the ApiService base security headers
  final settings = SettingsController.loadSettings(sharedPrefs);
  ApiService.apiKey = settings.apiKey;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: MonitroApp(hasConfig: dbUser != null),
    ),
  );
}


/// The root application widget for Monitro.
/// Handles routing and overall application state initialization.
class MonitroApp extends StatelessWidget {
  /// Whether the database parameters have been successfully configured.
  final bool hasConfig;

  /// Creates a [MonitroApp] instance.
  const MonitroApp({super.key, required this.hasConfig});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: hasConfig ? '/' : '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          builder: (c, s) => const SetupScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
            GoRoute(
                path: '/processes', builder: (c, s) => const ProcessesScreen()),
            GoRoute(
                path: '/cpu-cores', builder: (c, s) => const CpuCoresScreen()),
            GoRoute(
                path: '/connections',
                builder: (c, s) => const ConnectionsScreen()),
            GoRoute(path: '/users', builder: (c, s) => const UsersScreen()),
            GoRoute(
                path: '/api-calls',
                builder: (c, s) => const ApiMonitorScreen()),
            GoRoute(path: '/alerts', builder: (c, s) => const AlertsScreen()),
            GoRoute(
                path: '/service-control',
                builder: (c, s) => const ServiceControlScreen()),
            GoRoute(
                path: '/settings', builder: (c, s) => const SettingsScreen()),
            GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Monitro',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Scaffold layout housing the navigation sidebar and content space.
class AppShell extends StatelessWidget {
  /// Active nested subpage layout displayed inside the main content frame.
  final Widget child;

  /// Creates an [AppShell] instance.
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
                Image.asset('assets/images/monitro_icon.png',
                    width: 48, height: 48),
                const SizedBox(height: 8),
                const Text('Monitro',
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
                label: Text('Cpu Cores'),
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
                icon: Icon(Icons.build_circle_outlined),
                selectedIcon: Icon(Icons.build_circle),
                label: Text('Service'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: Text('About'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// List of absolute path routing endpoints matching sidebar indexes.
  List<String> get _navRoutes => [
        '/',
        '/processes',
        '/cpu-cores',
        '/connections',
        '/users',
        '/api-calls',
        '/alerts',
        '/service-control',
        '/settings',
        '/about'
      ];

  /// Find sidebar destination index corresponding to the current active location path.
  int _navIndex(String location) {
    final i = _navRoutes.indexOf(location);
    return i < 0 ? 0 : i;
  }

  /// Route navigation helper.
  void _navigate(BuildContext context, int index) {
    context.go(_navRoutes[index]);
  }
}

