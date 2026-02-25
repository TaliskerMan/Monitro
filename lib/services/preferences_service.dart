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

  const AppSettings({
    this.selectedNetworkInterface = 'All',
    this.showPerCoreCpu = false,
    this.refreshIntervalSeconds = 5,
  });

  AppSettings copyWith({
    String? selectedNetworkInterface,
    bool? showPerCoreCpu,
    int? refreshIntervalSeconds,
  }) {
    return AppSettings(
      selectedNetworkInterface: selectedNetworkInterface ?? this.selectedNetworkInterface,
      showPerCoreCpu: showPerCoreCpu ?? this.showPerCoreCpu,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
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
}

// Provider for the settings controller
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});
