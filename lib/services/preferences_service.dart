import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provides the initialized instance of SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

// Settings state object
class AppSettings {
  final String selectedNetworkInterface;
  final bool showPerCoreCpu;
  final int refreshIntervalSeconds;
  
  // MariaDB config
  final String? mariadbHost;
  final int? mariadbPort;
  final String? mariadbUser;
  final String? mariadbPass;
  final String? mariadbDb;

  const AppSettings({
    this.selectedNetworkInterface = 'All',
    this.showPerCoreCpu = false,
    this.refreshIntervalSeconds = 5,
    this.mariadbHost,
    this.mariadbPort,
    this.mariadbUser,
    this.mariadbPass,
    this.mariadbDb,
  });

  bool get hasDatabaseConfig => mariadbHost != null && mariadbUser != null && mariadbPass != null;

  AppSettings copyWith({
    String? selectedNetworkInterface,
    bool? showPerCoreCpu,
    int? refreshIntervalSeconds,
    String? mariadbHost,
    int? mariadbPort,
    String? mariadbUser,
    String? mariadbPass,
    String? mariadbDb,
  }) {
    return AppSettings(
      selectedNetworkInterface: selectedNetworkInterface ?? this.selectedNetworkInterface,
      showPerCoreCpu: showPerCoreCpu ?? this.showPerCoreCpu,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      mariadbHost: mariadbHost ?? this.mariadbHost,
      mariadbPort: mariadbPort ?? this.mariadbPort,
      mariadbUser: mariadbUser ?? this.mariadbUser,
      mariadbPass: mariadbPass ?? this.mariadbPass,
      mariadbDb: mariadbDb ?? this.mariadbDb,
    );
  }
}

// Controller to manage settings state
class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  SettingsController(this._prefs) : super(_loadSettings(_prefs));

  static AppSettings _loadSettings(SharedPreferences prefs) {
    return AppSettings(
      selectedNetworkInterface: prefs.getString('selectedNetworkInterface') ?? 'All',
      showPerCoreCpu: prefs.getBool('showPerCoreCpu') ?? false,
      refreshIntervalSeconds: prefs.getInt('refreshIntervalSeconds') ?? 5,
      mariadbHost: prefs.getString('mariadbHost'),
      mariadbPort: prefs.getInt('mariadbPort'),
      mariadbUser: prefs.getString('mariadbUser'),
      mariadbPass: prefs.getString('mariadbPass'),
      mariadbDb: prefs.getString('mariadbDb'),
    );
  }

  void setNetworkInterface(String interface) {
    _prefs.setString('selectedNetworkInterface', interface);
    state = state.copyWith(selectedNetworkInterface: interface);
  }

  void togglePerCoreCpu(bool show) {
    _prefs.setBool('showPerCoreCpu', show);
    state = state.copyWith(showPerCoreCpu: show);
  }

  void setRefreshInterval(int seconds) {
    _prefs.setInt('refreshIntervalSeconds', seconds);
    state = state.copyWith(refreshIntervalSeconds: seconds);
  }

  void setDatabaseConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) {
    _prefs.setString('mariadbHost', host);
    _prefs.setInt('mariadbPort', port);
    _prefs.setString('mariadbUser', user);
    _prefs.setString('mariadbPass', pass);
    _prefs.setString('mariadbDb', db);
    
    state = state.copyWith(
      mariadbHost: host,
      mariadbPort: port,
      mariadbUser: user,
      mariadbPass: pass,
      mariadbDb: db,
    );
  }
}

// Provider for the settings controller
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});
