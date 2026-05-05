// Monitro: CollectorManager
// Orchestrates all platform-aware metric collectors and persists results to MariaDB.

import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import '../storage/mariadb_service.dart';
import 'system_collector.dart';
import 'cpu_collector.dart';
import 'memory_collector.dart';
import 'disk_collector.dart';
import 'fs_collector.dart';
import 'network_collector.dart';
import 'netstat_collector.dart';
import 'process_collector.dart';
import 'user_collector.dart';
import 'api_monitor.dart';

final _log = Logger('CollectorManager');

class CollectorManager {
  final YamlMap config;
  final MariaDbService dbService;
  Timer? _timer;

  /// Holds the latest snapshot of all metrics (for real-time API responses).
  Map<String, dynamic> latestSnapshot = {};

  CollectorManager({
    required this.config,
    required this.dbService,
  });

  void start(Duration interval) {
    _log.info('Collector loop started (platform: ${Platform.operatingSystem})');
    _timer = Timer.periodic(interval, (_) => _collect());
    // Immediately collect on first tick
    _collect();
  }

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
    } catch (e, st) {
      _log.warning('Collection cycle error: $e', e, st);
    }
  }
}
