// Monitro: CollectorManager
// Orchestrates all platform-aware metric collectors and persists results to MariaDB.

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:monitro_collector/collectors/api_monitor.dart';
import 'package:monitro_collector/collectors/cpu_collector.dart';
import 'package:monitro_collector/collectors/disk_collector.dart';
import 'package:monitro_collector/collectors/fs_collector.dart';
import 'package:monitro_collector/collectors/memory_collector.dart';
import 'package:monitro_collector/collectors/netstat_collector.dart';
import 'package:monitro_collector/collectors/network_collector.dart';
import 'package:monitro_collector/collectors/process_collector.dart';
import 'package:monitro_collector/collectors/system_collector.dart';
import 'package:monitro_collector/collectors/user_collector.dart';
import 'package:monitro_collector/storage/mariadb_service.dart';
import 'package:yaml/yaml.dart';

final _log = Logger('CollectorManager');

/// Coordinates and schedules all metric collection cycles.
///
/// Drives the execution of system, cpu, memory, disk, network, netstat, processes,
/// users, and API monitor collectors, caches the latest snapshot, and dispatches
/// snapshots to the MariaDB storage layer.
class CollectorManager {
  /// Instantiates a new [CollectorManager] using config specifications and database references.
  CollectorManager({
    required this.config,
    required this.dbService,
  });

  /// Configuration mapping details parsed from monitro.yaml.
  final YamlMap config;

  /// Database persistence service reference.
  final MariaDbService dbService;

  /// Internal recurring timer scheduling collection loops.
  Timer? _timer;

  /// Holds the latest snapshot of all metrics (for real-time API responses).
  Map<String, dynamic> latestSnapshot = {};

  /// Starts the periodic system metrics collection loop with the specified [interval].
  void start(Duration interval) {
    _log.info('Collector loop started (platform: ${Platform.operatingSystem})');
    _timer = Timer.periodic(interval, (_) => _collect());
    // Immediately collect on first tick
    _collect();
  }

  /// Cancels the running collection timer loop.
  void stop() {
    _timer?.cancel();
    _log.info('Collector loop stopped.');
  }

  Future<void> _collect() async {
    final now = DateTime.now();
    try {
      // Run all collectors in parallel
      final results = await Future.wait([
        SystemCollector.collect(),
        CpuCollector.collect(),
        MemoryCollector.collect(),
        DiskCollector.collect(),
        FsCollector.collect(),
        NetworkCollector.collect(),
        NetstatCollector.collect(),
        ProcessCollector.collect(),
        UserCollector.collect(),
        ApiMonitor.collect(),
      ]);

      // Merge network interfaces into netstat for the UI
      final networkData = results[5];
      final netstatData = results[6];
      if (networkData['interfaces'] is List) {
        final uiInterfaces = <String, Map<String, dynamic>>{};
        for (final iface in networkData['interfaces'] as List) {
          uiInterfaces[iface['interface'] as String] = {
            'bytes_recv': iface['rx_bytes'],
            'bytes_sent': iface['tx_bytes'],
          };
        }
        netstatData['interfaces'] = uiInterfaces;
      }

      // Flatten into a single snapshot map
      final snapshot = <String, dynamic>{
        'collected_at': now.toIso8601String(),
        'system': results[0],
        'cpu': results[1],
        'memory': results[2],
        'disk': results[3],
        'filesystem': results[4],
        'network': results[5],
        'netstat': results[6],
        'processes': results[7],
        'users': results[8],
        'api_calls': results[9],
      };

      latestSnapshot = snapshot;

      // Persist to MariaDB asynchronously
      await dbService.storeSnapshot(snapshot);
    } catch (error, st) {
      log('Exception caught', error: error, stackTrace: st);
      _log.warning('Collection cycle error: $error', error, st);
    }
  }
}
