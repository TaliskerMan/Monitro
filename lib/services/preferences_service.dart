import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';

/// Provider exposing the initialized SharedPreferences database instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

/// Immutable configuration data model storing application preferences and database configs.
class AppSettings {
  /// Selected physical or virtual network interface name (e.g. eth0, wlan0).
  final String selectedNetworkInterface;

  /// Whether to render resource graphs per core rather than an aggregated sum.
  final bool showPerCoreCpu;

  /// Time interval in seconds between metric polls.
  final int refreshIntervalSeconds;
  
  /// Target host address of the MariaDB relational metrics store.
  final String? mariadbHost;

  /// Listening port of the MariaDB metrics store.
  final int? mariadbPort;

  /// Username utilized to authenticate database mutations.
  final String? mariadbUser;

  /// Password credentials corresponding to the database user.
  final String? mariadbPass;

  /// Target database namespace.
  final String? mariadbDb;

  /// Secure API authorization bearer key.
  final String? apiKey;

  /// Creates an [AppSettings] instance.
  const AppSettings({
    this.selectedNetworkInterface = 'All',
    this.showPerCoreCpu = false,
    this.refreshIntervalSeconds = 5,
    this.mariadbHost,
    this.mariadbPort,
    this.mariadbUser,
    this.mariadbPass,
    this.mariadbDb,
    this.apiKey,
  });

  /// Check whether the database configs are fully populated.
  bool get hasDatabaseConfig => mariadbHost != null && mariadbUser != null && mariadbPass != null;

  /// Create a cloned instance with modified properties.
  AppSettings copyWith({
    String? selectedNetworkInterface,
    bool? showPerCoreCpu,
    int? refreshIntervalSeconds,
    String? mariadbHost,
    int? mariadbPort,
    String? mariadbUser,
    String? mariadbPass,
    String? mariadbDb,
    String? apiKey,
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
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

/// State notifier class managing runtime updates of [AppSettings].
///
/// Automatically writes modified settings to local SharedPreferences persistent storage.
class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  /// Creates a [SettingsController] loading values from shared preferences.
  SettingsController(this._prefs) : super(_loadSettings(_prefs));

  /// Expose the current loaded settings.
  AppSettings get settings => state;

  /// Load settings from SharedPreferences storage, generating a random API key if not yet set.
  static AppSettings _loadSettings(SharedPreferences prefs) {
    String? apiKey = prefs.getString('apiKey');
    if (apiKey == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      apiKey = base64UrlEncode(values);
      prefs.setString('apiKey', apiKey);
    }

    return AppSettings(
      selectedNetworkInterface: prefs.getString('selectedNetworkInterface') ?? 'All',
      showPerCoreCpu: prefs.getBool('showPerCoreCpu') ?? false,
      refreshIntervalSeconds: prefs.getInt('refreshIntervalSeconds') ?? 5,
      mariadbHost: prefs.getString('mariadbHost'),
      mariadbPort: prefs.getInt('mariadbPort'),
      mariadbUser: prefs.getString('mariadbUser'),
      mariadbPass: prefs.getString('mariadbPass'),
      mariadbDb: prefs.getString('mariadbDb'),
      apiKey: prefs.getString('apiKey'),
    );
  }

  /// Update the target network interface setting.
  void setNetworkInterface(String interface) {
    _prefs.setString('selectedNetworkInterface', interface);
    state = state.copyWith(selectedNetworkInterface: interface);
  }

  /// Toggle between aggregated and per-core CPU dashboard displays.
  void togglePerCoreCpu(bool show) {
    _prefs.setBool('showPerCoreCpu', show);
    state = state.copyWith(showPerCoreCpu: show);
  }

  /// Set the refresh poll interval rate.
  void setRefreshInterval(int seconds) {
    _prefs.setInt('refreshIntervalSeconds', seconds);
    state = state.copyWith(refreshIntervalSeconds: seconds);
  }

  /// Update the MariaDB connection configurations.
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

  /// Set a new API key value.
  void setApiKey(String key) {
    _prefs.setString('apiKey', key);
    state = state.copyWith(apiKey: key);
  }
}

/// Provider exposing the global [SettingsController] notifier.
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});

