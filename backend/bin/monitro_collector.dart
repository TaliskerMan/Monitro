// Monitro Collector Daemon — Entry Point
// =============================================================================
// This Dart executable is compiled to a native binary and runs as a background
// service. It:
//   1. Reads monitro.yaml configuration
//   2. Starts the metric collection loop (configurable interval)
//   3. Serves a local HTTPS REST API for the Flutter UI to consume
//   4. Persists all metrics to MariaDB
// =============================================================================

import 'dart:io';
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import 'package:monitro_collector/api/server.dart';
import 'package:monitro_collector/collectors/collector_manager.dart';
import 'package:monitro_collector/storage/mariadb_service.dart';

final _log = Logger('monitro_collector');

Future<void> main(List<String> args) async {
  // ---------------------------------------------------------------------------
  // Parse command-line arguments
  // ---------------------------------------------------------------------------
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      defaultsTo: 'config/monitro.yaml',
      help: 'Path to the monitro.yaml configuration file',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Enable verbose debug logging',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      negatable: false,
      help: 'Show this help message',
    );

  final results = parser.parse(args);
  if (results['help'] as bool) {
    print('Monitro Collector Daemon v0.1.0\n');
    print(parser.usage);
    exit(0);
  }

  // ---------------------------------------------------------------------------
  // Set up logging
  // ---------------------------------------------------------------------------
  Logger.root.level = (results['verbose'] as bool) ? Level.ALL : Level.INFO;

  final logFile = File('/var/log/monitro-collector.log');
  // ignore: close_sinks
  IOSink? logSink;
  try {
    logSink = logFile.openWrite(mode: FileMode.append);
  } catch (e) {
    print(
        'Warning: Cannot open /var/log/monitro-collector.log for writing. Falling back to stdout string.');
  }

  Logger.root.onRecord.listen((record) {
    final ts = record.time.toIso8601String();
    final level = record.level.name.padRight(7);
    final msg = '[$ts] $level ${record.loggerName}: ${record.message}';

    print(msg);
    logSink?.writeln(msg);

    if (record.error != null) {
      print('  ERROR: ${record.error}');
      logSink?.writeln('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  STACK: ${record.stackTrace}');
      logSink?.writeln('  STACK: ${record.stackTrace}');
    }
  });

  // ---------------------------------------------------------------------------
  // Load configuration
  // ---------------------------------------------------------------------------
  final configPath = results['config'] as String;
  _log.info('Loading configuration from: $configPath');

  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    _log.severe('Configuration file not found: $configPath');
    _log.info(
        'Copy config/monitro.example.yaml to config/monitro.yaml and edit it.');
    exit(1);
  }

  final configContent = configFile.readAsStringSync();
  final config = loadYaml(configContent) as YamlMap;
  // configDir is the config file's directory (e.g. /Monitro/config).
  // Cert paths in monitro.yaml are relative to the repo root (e.g. certs/server.crt),
  // so we go one level up to get the repo root.
  final configFileDir = configFile.absolute.parent.path;
  final configDir = File(configFileDir).parent.path; // repo root

  // ---------------------------------------------------------------------------
  // Connect to MariaDB
  // ---------------------------------------------------------------------------
  _log.info('Connecting to MariaDB...');
  final dbService = MariaDbService(config['database'] as YamlMap);
  await dbService.connect();
  await dbService.runMigrations();
  _log.info('MariaDB connection established.');

  // ---------------------------------------------------------------------------
  // Start the metric collection loop
  // ---------------------------------------------------------------------------
  final collectorConfig = config['collector'] as YamlMap;
  final intervalSeconds = (collectorConfig['interval_seconds'] as int?) ?? 5;
  _log.info('Starting collector loop (interval: ${intervalSeconds}s)...');

  final manager = CollectorManager(
    config: collectorConfig,
    dbService: dbService,
  );
  manager.start(Duration(seconds: intervalSeconds));

  // ---------------------------------------------------------------------------
  // Start the HTTPS API server
  // ---------------------------------------------------------------------------
  final serverConfig = config['server'] as YamlMap;
  final apiServer = MonitroApiServer(
    config: serverConfig,
    configDir: configDir,
    dbService: dbService,
    collectorManager: manager,
  );
  await apiServer.start();

  // ---------------------------------------------------------------------------
  // Handle signals for graceful shutdown
  // ---------------------------------------------------------------------------
  _log.info('Monitro collector running. Press Ctrl+C to stop.');
  ProcessSignal.sigint.watch().listen((_) async {
    _log.info('Received SIGINT — shutting down...');
    manager.stop();
    await apiServer.stop();
    await dbService.disconnect();
    exit(0);
  });

  // Handle SIGTERM on POSIX systems
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      _log.info('Received SIGTERM — shutting down...');
      manager.stop();
      await apiServer.stop();
      await dbService.disconnect();
      exit(0);
    });
  }
}
