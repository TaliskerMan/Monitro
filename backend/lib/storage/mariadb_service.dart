// Monitro MariaDB Service
// Handles connection, schema migrations, and data persistence.

import 'package:mysql_client/mysql_client.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';

final _log = Logger('MariaDbService');

class MariaDbService {
  final YamlMap config;
  MySQLConnection? _conn;

  MariaDbService(this.config);

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------
  Future<void> connect() async {
    _conn = await MySQLConnection.createConnection(
      host:     config['host']     as String? ?? '127.0.0.1',
      port:     config['port']     as int?    ?? 3306,
      databaseName: config['name'] as String? ?? 'monitro',
      userName: config['user']     as String? ?? 'monitro_user',
      password: config['password'] as String? ?? '',
      secure:   false,
    );
    await _conn!.connect();
    _log.info('Connected to MariaDB at ${config['host']}:${config['port']}');
  }

  Future<void> disconnect() async {
    await _conn?.close();
    _log.info('MariaDB connection closed.');
  }

  // ---------------------------------------------------------------------------
  // Schema Migration
  // ---------------------------------------------------------------------------
  Future<void> runMigrations() async {
    _log.info('Running schema migrations...');
    // Find migration files relative to the executable location  
    final execDir = File(Platform.resolvedExecutable).parent.parent.path;
    final migrationsDir = Directory('$execDir/../db/migrations');
    
    if (!migrationsDir.existsSync()) {
      _log.warning('Migrations directory not found: ${migrationsDir.path}');
      return;
    }

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      _log.info('Applying migration: ${file.path}');
      try {
        final sql = file.readAsStringSync();
        // Split on semicolons and execute each statement
        for (final stmt in sql.split(';')) {
          final clean = stmt.trim();
          if (clean.isNotEmpty && !clean.startsWith('--')) {
            await _conn!.execute(clean);
          }
        }
      } catch (e) {
        _log.warning('Migration warning (may already exist): $e');
      }
    }
    _log.info('Migrations complete.');
  }

  // ---------------------------------------------------------------------------
  // Store Snapshot
  // ---------------------------------------------------------------------------
  Future<void> storeSnapshot(Map<String, dynamic> snapshot) async {
    if (_conn == null) return;
    final collectedAt = snapshot['collected_at'] as String;

    // --- System / Load metrics ---
    await _storeSystemMetrics(snapshot['system'], collectedAt);
    await _storeCpuMetrics(snapshot['cpu'], collectedAt);
    await _storeMemoryMetrics(snapshot['memory'], collectedAt);
    await _storeDiskMetrics(snapshot['disk'], collectedAt);
    await _storeNetworkMetrics(snapshot['network'], collectedAt);
    await _storeProcesses(snapshot['processes'], collectedAt);
    await _storeUsers(snapshot['users'], collectedAt);
    await _storeConnections(snapshot['netstat'], collectedAt);
    await _storeApiCalls(snapshot['api_calls'], collectedAt);
  }

  Future<void> _storeSystemMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final metrics = <List<dynamic>>[
      if (m['load_1'] != null)  ['system.load.1',  m['load_1'],  null],
      if (m['load_5'] != null)  ['system.load.5',  m['load_5'],  null],
      if (m['load_15'] != null) ['system.load.15', m['load_15'], null],
    ];
    await _batchInsertMetrics(metrics, ts);
  }

  Future<void> _storeCpuMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    if (m['busy_pct'] != null) {
      await _batchInsertMetrics([
        ['cpu.busy_pct', m['busy_pct'], null],
        ['cpu.idle_pct', m['idle_pct'] ?? (100.0 - (m['busy_pct'] as num)), null],
      ], ts);
    }
    // Linux per-core raw counts stored for delta calculation
    if (m['cores'] != null) {
      final cores = m['cores'] as List;
      for (final core in cores) {
        final name = core['core'] as String;
        await _batchInsertMetrics([
          ['cpu.ticks.total', core['total'], name],
          ['cpu.ticks.busy',  core['busy'],  name],
        ], ts);
      }
    }
  }

  Future<void> _storeMemoryMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final metrics = <List<dynamic>>[];
    if (m['used_pct'] != null) metrics.add(['mem.used_pct', m['used_pct'], null]);
    if (m['total_kb'] != null) metrics.add(['mem.total_kb', m['total_kb'], null]);
    if (m['used_kb'] != null)  metrics.add(['mem.used_kb', m['used_kb'], null]);
    if (m['total_bytes'] != null) {
      metrics.add(['mem.total_bytes', m['total_bytes'], null]);
      metrics.add(['mem.used_bytes',  m['used_bytes'], null]);
    }
    if (m['swap_used_pct'] != null) metrics.add(['swap.used_pct', m['swap_used_pct'], null]);
    await _batchInsertMetrics(metrics, ts);
  }

  Future<void> _storeDiskMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final devices = m['devices'] as List? ?? [];
    for (final dev in devices) {
      final label = dev['device'] as String;
      final metrics = <List<dynamic>>[];
      if (dev['mb_per_sec'] != null) metrics.add(['disk.mb_per_sec', dev['mb_per_sec'], label]);
      if (dev['sectors_read'] != null) {
        metrics.add(['disk.sectors_read', dev['sectors_read'], label]);
        metrics.add(['disk.sectors_written', dev['sectors_written'], label]);
      }
      await _batchInsertMetrics(metrics, ts);
    }
  }

  Future<void> _storeNetworkMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final interfaces = m['interfaces'] as List? ?? [];
    for (final iface in interfaces) {
      final label = iface['interface'] as String;
      if (label == 'lo' || label == 'Loopback_Pseudo-Interface_1') continue;
      await _batchInsertMetrics([
        ['net.rx_bytes', iface['rx_bytes'] ?? 0, label],
        ['net.tx_bytes', iface['tx_bytes'] ?? 0, label],
        ['net.rx_packets', iface['rx_packets'] ?? 0, label],
        ['net.tx_packets', iface['tx_packets'] ?? 0, label],
      ], ts);
    }
  }

  Future<void> _storeProcesses(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final processes = (data as Map)['processes'] as List? ?? [];
    for (final proc in processes.take(50)) {
      try {
        await _conn!.execute(
          'INSERT INTO processes (collected_at, pid, ppid, name, username, '
          'cpu_pct, mem_pct, mem_rss_kb, state, num_threads, cmdline) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            ts,
            proc['pid'],
            proc['ppid'],
            (proc['cmdline'] as String? ?? '').split(' ').first,
            proc['user'],
            proc['cpu_pct'],
            proc['mem_pct'],
            proc['rss_kb'],
            proc['state'],
            proc['threads'],
            proc['cmdline'],
          ],
        );
      } catch (e) {
        _log.fine('Process insert error: $e');
      }
    }
  }

  Future<void> _storeUsers(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final sessions = (data as Map)['sessions'] as List? ?? [];
    for (final session in sessions) {
      try {
        await _conn!.execute(
          'INSERT INTO user_sessions (collected_at, username, tty, from_host, idle_time, current_cmd) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            ts,
            session['username'] ?? '',
            session['tty'] ?? '',
            session['from_host'] ?? '',
            session['idle'] ?? '',
            session['current_cmd'] ?? '',
          ],
        );
      } catch (e) {
        _log.fine('User session insert error: $e');
      }
    }
  }

  Future<void> _storeConnections(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final summary = (data as Map)['summary'] as Map? ?? {};
    // Store connection state summary as metrics
    final metrics = summary.entries
        .map((e) => ['netstat.${e.key.toLowerCase()}', e.value, null])
        .toList();
    await _batchInsertMetrics(metrics.cast<List<dynamic>>(), ts);
  }

  Future<void> _storeApiCalls(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final callers = (data as Map)['api_callers'] as List? ?? [];
    for (final caller in callers) {
      try {
        await _conn!.execute(
          'INSERT INTO api_calls (collected_at, process_name, call_count) VALUES (?, ?, ?)',
          [ts, caller['process'], caller['connections']],
        );
      } catch (e) {
        _log.fine('API call insert error: $e');
      }
    }
  }

  Future<void> _batchInsertMetrics(
    List<List<dynamic>> metrics, String ts,
  ) async {
    for (final m in metrics) {
      try {
        await _conn!.execute(
          'INSERT INTO metrics (collected_at, metric_name, value, label) VALUES (?, ?, ?, ?)',
          [ts, m[0], m[1], m[2]],
        );
      } catch (e) {
        _log.fine('Metric insert error (${m[0]}): $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Query helpers for the API server
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> queryMetricHistory({
    required String metricName,
    String? label,
    int minutes = 60,
  }) async {
    if (_conn == null) return [];
    final stmt = label != null
        ? 'SELECT collected_at, value FROM metrics '
          'WHERE metric_name = ? AND label = ? '
          'AND collected_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) '
          'ORDER BY collected_at ASC'
        : 'SELECT collected_at, value FROM metrics '
          'WHERE metric_name = ? '
          'AND collected_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) '
          'ORDER BY collected_at ASC';
    final args = label != null
        ? [metricName, label, minutes]
        : [metricName, minutes];
    final result = await _conn!.execute(stmt, args);
    return result.rows.map((r) => r.assoc()).toList();
  }

  Future<List<Map<String, dynamic>>> queryTopProcesses({int limit = 20}) async {
    if (_conn == null) return [];
    final result = await _conn!.execute(
      'SELECT * FROM processes '
      'WHERE collected_at >= DATE_SUB(NOW(), INTERVAL 30 SECOND) '
      'ORDER BY cpu_pct DESC LIMIT ?',
      [limit],
    );
    return result.rows.map((r) => r.assoc()).toList();
  }

  Future<List<Map<String, dynamic>>> queryRecentAlerts({int limit = 50}) async {
    if (_conn == null) return [];
    final result = await _conn!.execute(
      'SELECT * FROM alert_events ORDER BY triggered_at DESC LIMIT ?',
      [limit],
    );
    return result.rows.map((r) => r.assoc()).toList();
  }

  Future<void> runRetentionCleanup(int retentionDays) async {
    _log.info('Running retention cleanup (keeping last $retentionDays days)...');
    final tables = ['metrics', 'processes', 'connections', 'user_sessions', 'api_calls'];
    for (final table in tables) {
      await _conn!.execute(
        'DELETE FROM $table WHERE collected_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        [retentionDays],
      );
    }
    _log.info('Retention cleanup complete.');
  }
}
