import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'preferences_service.dart';


/// Service class responsible for creating and writing the collector daemon's configuration file.
///
/// Converts application settings into a standard YAML configuration file loaded by the backend.
class ConfigGenerator {
  /// Resolves the absolute path to the SSL certificates resource directory.
  static String _getCertsDir() {
    final exeLoc = Platform.resolvedExecutable;
    if (Platform.isMacOS && exeLoc.contains('.app/Contents/MacOS/')) {
      final appDir = File(exeLoc).parent.parent.path;
      return p.join(appDir, 'Resources', 'certs');
    }
    if (Platform.isWindows && p.basename(exeLoc).toLowerCase() == 'monitro.exe') {
      final appDir = File(exeLoc).parent.path;
      return p.join(appDir, 'certs');
    }
    return p.join(Directory.current.path, 'certs');
  }

  /// Generate a valid `monitro.yaml` configuration file from settings values.
  ///
  /// Writes the output file to the system-specific application support directory.
  ///
  /// Args:
  ///   settings: The current AppSettings holding database parameters.
  ///
  /// Returns:
  ///   The absolute file path to the generated yaml configuration.
  static Future<String> generateConfig(AppSettings settings) async {
    final supportDir = await getApplicationSupportDirectory();
    final configDir = Directory(p.join(supportDir.path, 'config'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    
    final certDir = _getCertsDir();
    final certPath = p.join(certDir, 'server.crt').replaceAll('\\', '/');
    final keyPath = p.join(certDir, 'server.key').replaceAll('\\', '/');

    // Default configuration template containing server parameters, thresholds, and port maps
    final yaml = '''
server:
  host: 127.0.0.1
  port: 8443
  require_client_ca: false
  cert: "$certPath"
  key: "$keyPath"
  api_key: "${settings.apiKey}"

database:
  host: ${settings.mariadbHost ?? '127.0.0.1'}
  port: ${settings.mariadbPort ?? 3306}
  name: ${settings.mariadbDb ?? 'monitro'}
  user: ${settings.mariadbUser ?? 'monitro_user'}
  password: "${settings.mariadbPass ?? ''}"

collector:
  interval_seconds: ${settings.refreshIntervalSeconds}
  retention_days: 30
  enable_process_monitor: true
  enable_user_sessions: true
  enable_api_monitor: true

alerts:
  load_avg_enabled: true
  load_avg_threshold: 5.0
  load_avg_script: ""
  cpu_enabled: true
  cpu_threshold: 90.0
  mem_enabled: true
  mem_threshold: 90.0
  disk_enabled: true
  disk_threshold: 85.0
  min_interval_seconds: 300

monitored_ports:
  - port: 22
    name: SSH
    protocol: tcp
  - port: 80
    name: HTTP
    protocol: tcp
  - port: 443
    name: HTTPS
    protocol: tcp
  - port: 3306
    name: MySQL/MariaDB
    protocol: tcp
  - port: 8443
    name: Monitro
    protocol: tcp
''';

    final configFile = File(p.join(configDir.path, 'monitro.yaml'));
    await configFile.writeAsString(yaml);
    return configFile.path;
  }
}

