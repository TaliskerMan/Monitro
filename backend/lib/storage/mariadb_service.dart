// Monitro MariaDB Service
// Handles connection, schema migrations, and data persistence.
//
// NOTE: mysql_client uses NAMED parameters with :name syntax (Map<String,dynamic>),
// NOT positional ? placeholders with a List. All execute() calls must pass a Map.

import 'dart:developer';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:yaml/yaml.dart';

final _log = Logger('MariaDbService');

/// MariaDB database service layer.
///
/// Coordinates connection lifecycles, schema structure migrations, and
/// persistent time-series metrics logging routines for system state snapshots.
class MariaDbService {
  /// Instantiates a new [MariaDbService] with configuration directives.
  MariaDbService(this.config);

  /// YAML dynamic configuration mapping database connection parameters.
  final YamlMap config;

  /// Internal MySQL active connection reference pool.
  MySQLConnection? _conn;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------
  /// Connects to the MariaDB server using parameters specified in the configuration.
  Future<void> connect() async {
    _conn = await MySQLConnection.createConnection(
      host: config['host'] as String? ?? '127.0.0.1',
      port: config['port'] as int? ?? 3306,
      databaseName: config['name'] as String? ?? 'monitro',
      userName: config['user'] as String? ?? 'monitro_user',
      password: config['password'] as String? ?? '',
      secure: false,
    );
    await _conn!.connect();
    _log.info('Connected to MariaDB at ${config['host']}:${config['port']}');
  }

  /// Closes the active MySQL/MariaDB database connection pool.
  Future<void> disconnect() async {
    await _conn?.close();
    _log.info('MariaDB connection closed.');
  }

  // ---------------------------------------------------------------------------
  // Schema Migration — reads SQL files and runs each statement
  // ---------------------------------------------------------------------------
  /// Performs database schema migrations by identifying, parsing, and running
  /// all `.sql` migration files located inside the application installation directories.
  Future<void> runMigrations() async {
    _log.info('Running schema migrations...');

    // Resolve migrations directory.
    // Platform.resolvedExecutable gives the actual binary path (works in AOT).
    // The binary lives at e.g. /opt/monitro/backend/monitro_collector,
    // so we go up one level to the install root, then into db/migrations/.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final installRoot = File(exeDir).parent.path; // /opt/monitro

    // Try relative to install root first, then fall back to well-known path
    Directory? migrationsDir;
    for (final candidate in [
      Directory('$installRoot/db/migrations'),
      Directory('/opt/monitro/db/migrations'),
    ]) {
      if (candidate.existsSync()) {
        migrationsDir = candidate;
        break;
      }
    }

    if (migrationsDir == null) {
      _log.warning(
          'Migrations directory not found. Checked: $installRoot/db/migrations and /opt/monitro/db/migrations');
      return;
    }

    _log.info('Using migrations from: ${migrationsDir.path}');

    // Ledger so each migration runs exactly once, and a failure is loud.
    await _conn!.execute(
      'CREATE TABLE IF NOT EXISTS schema_migrations ('
      '  filename VARCHAR(255) PRIMARY KEY,'
      '  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
      ')',
    );
    final appliedRows =
        await _conn!.execute('SELECT filename FROM schema_migrations');
    final applied = <String>{
      for (final row in appliedRows.rows) row.colByName('filename') ?? '',
    };

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (applied.contains(name)) {
        _log.fine('Skipping already-applied migration: $name');
        continue;
      }
      _log.info('Applying migration: $name');
      try {
        final sql = file.readAsStringSync();
        for (final stmt in sql.split(';')) {
          final clean = stmt.trim();
          if (clean.isEmpty) continue;
          final nonComment = clean
              .split('\n')
              .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('--'))
              .join(' ')
              .trim();
          if (nonComment.isNotEmpty) {
            await _conn!.execute(nonComment);
          }
        }
        await _conn!.execute(
          'INSERT INTO schema_migrations (filename) VALUES (:f)',
          {'f': name},
        );
      } catch (e) {
        // A failed migration is fatal: stop rather than silently leaving the
        // schema in an unknown/half-applied state.
        log('Migration failed', error: e);
        _log.severe('Migration FAILED ($name): $e');
        rethrow;
      }
    }
    _log.info('Migrations complete.');
  }

  // ---------------------------------------------------------------------------
  // Store Snapshot — called every collection cycle
  // ---------------------------------------------------------------------------
  /// Persists a system collector state snapshot packet to MariaDB tables.
  ///
  /// Dispatches sub-queries to log CPU, Memory, Disk, Netstat, processes, users,
  /// and API usage calls associated with the given timestamp.
  Future<void> storeSnapshot(Map<String, dynamic> snapshot) async {
    if (_conn == null) return;
    final ts = snapshot['collected_at'] as String;

    await _storeSystemMetrics(snapshot['system'], ts);
    await _storeCpuMetrics(snapshot['cpu'], ts);
    await _storeMemoryMetrics(snapshot['memory'], ts);
    await _storeDiskMetrics(snapshot['disk'], ts);
    await _storeNetworkMetrics(snapshot['network'], ts);
    await _storeProcesses(snapshot['processes'], ts);
    await _storeUsers(snapshot['users'], ts);
    await _storeConnections(snapshot['netstat'], ts);
    await _storeApiCalls(snapshot['api_calls'], ts);
  }

  // ---------------------------------------------------------------------------
  // Individual store methods
  // ---------------------------------------------------------------------------

  Future<void> _storeSystemMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final rows = <List<dynamic>>[
      if (m['load_1'] != null) ['system.load.1', m['load_1'], null],
      if (m['load_5'] != null) ['system.load.5', m['load_5'], null],
      if (m['load_15'] != null) ['system.load.15', m['load_15'], null],
    ];
    await _batchInsertMetrics(rows, ts);
  }

  Future<void> _storeCpuMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    if (m['busy_pct'] != null) {
      await _batchInsertMetrics(
        [
          ['cpu.busy_pct', m['busy_pct'], null],
          [
            'cpu.idle_pct',
            m['idle_pct'] ?? (100.0 - (m['busy_pct'] as num)),
            null
          ],
        ],
        ts,
      );
    }
    if (m['cores'] != null) {
      for (final core in m['cores'] as List) {
        final name = core['core'] as String;
        await _batchInsertMetrics(
          [
            ['cpu.ticks.total', core['total'], name],
            ['cpu.ticks.busy', core['busy'], name],
          ],
          ts,
        );
      }
    }
  }

  Future<void> _storeMemoryMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final m = data as Map;
    final rows = <List<dynamic>>[];
    if (m['used_pct'] != null) rows.add(['mem.used_pct', m['used_pct'], null]);
    if (m['total_kb'] != null) rows.add(['mem.total_kb', m['total_kb'], null]);
    if (m['used_kb'] != null) rows.add(['mem.used_kb', m['used_kb'], null]);
    if (m['total_bytes'] != null) {
      rows.add(['mem.total_bytes', m['total_bytes'], null]);
    }
    if (m['used_bytes'] != null) {
      rows.add(['mem.used_bytes', m['used_bytes'], null]);
    }
    if (m['swap_used_pct'] != null) {
      rows.add(['swap.used_pct', m['swap_used_pct'], null]);
    }
    await _batchInsertMetrics(rows, ts);
  }

  Future<void> _storeDiskMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final devices = (data as Map)['devices'] as List? ?? [];
    for (final dev in devices) {
      final label = dev['device'] as String;
      final rows = <List<dynamic>>[];
      if (dev['mb_per_sec'] != null) {
        rows.add(['disk.mb_per_sec', dev['mb_per_sec'], label]);
      }
      if (dev['sectors_read'] != null) {
        rows.add(['disk.sectors_read', dev['sectors_read'], label]);
      }
      if (dev['sectors_written'] != null) {
        rows.add(['disk.sectors_written', dev['sectors_written'], label]);
      }
      await _batchInsertMetrics(rows, ts);
    }
  }

  Future<void> _storeNetworkMetrics(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final interfaces = (data as Map)['interfaces'] as List? ?? [];
    for (final iface in interfaces) {
      final label = iface['interface'] as String;
      if (label == 'lo' || label.startsWith('Loopback')) continue;
      await _batchInsertMetrics(
        [
          ['net.rx_bytes', iface['rx_bytes'] ?? 0, label],
          ['net.tx_bytes', iface['tx_bytes'] ?? 0, label],
          ['net.rx_packets', iface['rx_packets'] ?? 0, label],
          ['net.tx_packets', iface['tx_packets'] ?? 0, label],
        ],
        ts,
      );
    }
  }

  Future<void> _storeProcesses(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final processes = (data as Map)['processes'] as List? ?? [];
    for (final proc in processes.take(50)) {
      try {
        final name =
            (proc['cmdline'] as String? ?? '').split('/').last.split(' ').first;
        await _conn!.execute(
          'INSERT INTO processes '
          '(collected_at, pid, ppid, name, username, cpu_pct, mem_pct, mem_rss_kb, state, num_threads, cmdline) '
          'VALUES (:ts, :pid, :ppid, :name, :user, :cpu, :mem, :rss, :state, :threads, :cmd)',
          {
            'ts': ts,
            'pid': proc['pid'],
            'ppid': proc['ppid'],
            'name': name,
            'user': proc['user'] ?? '',
            'cpu': proc['cpu_pct'] ?? 0.0,
            'mem': proc['mem_pct'] ?? 0.0,
            'rss': proc['rss_kb'] ?? 0,
            'state': proc['state'] ?? '',
            'threads': proc['threads'] ?? 1,
            'cmd': proc['cmdline'] ?? '',
          },
        );
      } catch (e) {
        log('Exception caught', error: e);
        _log.fine('Process insert error: $e');
      }
    }
  }

  Future<void> _storeUsers(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final sessions = (data as Map)['sessions'] as List? ?? [];
    for (final s in sessions) {
      try {
        await _conn!.execute(
          'INSERT INTO user_sessions (collected_at, username, tty, from_host, idle_time, current_cmd) '
          'VALUES (:ts, :user, :tty, :host, :idle, :cmd)',
          {
            'ts': ts,
            'user': s['username'] ?? '',
            'tty': s['tty'] ?? '',
            'host': s['from_host'] ?? '',
            'idle': s['idle'] ?? '',
            'cmd': s['current_cmd'] ?? '',
          },
        );
      } catch (e) {
        log('Exception caught', error: e);
        _log.fine('User session insert error: $e');
      }
    }
  }

  Future<void> _storeConnections(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final summary = (data as Map)['summary'] as Map? ?? {};
    final rows = summary.entries
        .map((e) => ['netstat.${e.key.toLowerCase()}', e.value, null])
        .toList();
    await _batchInsertMetrics(rows, ts);
  }

  Future<void> _storeApiCalls(dynamic data, String ts) async {
    if (data == null || data['error'] != null) return;
    final callers = (data as Map)['api_callers'] as List? ?? [];
    for (final caller in callers) {
      try {
        await _conn!.execute(
          'INSERT INTO api_calls (collected_at, process_name, call_count) '
          'VALUES (:ts, :proc, :count)',
          {
            'ts': ts,
            'proc': caller['process'] ?? '',
            'count': caller['connections'] ?? 0,
          },
        );
      } catch (e) {
        log('Exception caught', error: e);
        _log.fine('API call insert error: $e');
      }
    }
  }

  /// Batch-inserts metric rows. Each row is [metric_name, value, label?].
  Future<void> _batchInsertMetrics(List<List<dynamic>> rows, String ts) async {
    for (final row in rows) {
      try {
        await _conn!.execute(
          'INSERT INTO metrics (collected_at, metric_name, value, label) '
          'VALUES (:ts, :name, :val, :label)',
          {
            'ts': ts,
            'name': row[0],
            'val': row[1],
            'label': row.length > 2 ? row[2] : null,
          },
        );
      } catch (e) {
        log('Exception caught', error: e);
        _log.fine('Metric insert error (${row[0]}): $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Query helpers — used by the API server
  // ---------------------------------------------------------------------------

  /// Queries historical metrics logged in the database within a minutes threshold.
  ///
  /// Filters rows matching [metricName] and an optional [label].
  Future<List<Map<String, dynamic>>> queryMetricHistory({
    required String metricName,
    String? label,
    int minutes = 60,
  }) async {
    if (_conn == null) return [];
    try {
      IResultSet result;
      if (label != null) {
        result = await _conn!.execute(
          'SELECT collected_at, value FROM metrics '
          'WHERE metric_name = :name AND label = :label '
          'AND collected_at >= DATE_SUB(NOW(), INTERVAL :mins MINUTE) '
          'ORDER BY collected_at ASC',
          {'name': metricName, 'label': label, 'mins': minutes},
        );
      } else {
        result = await _conn!.execute(
          'SELECT collected_at, value FROM metrics '
          'WHERE metric_name = :name '
          'AND collected_at >= DATE_SUB(NOW(), INTERVAL :mins MINUTE) '
          'ORDER BY collected_at ASC',
          {'name': metricName, 'mins': minutes},
        );
      }
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      log('Exception caught', error: e);
      _log.warning('queryMetricHistory error: $e');
      return [];
    }
  }

  /// Queries recently captured system process details, ordered by CPU utilization.
  Future<List<Map<String, dynamic>>> queryTopProcesses({int limit = 20}) async {
    if (_conn == null) return [];
    try {
      // mysql_client doesn't support :param in LIMIT — use interpolation for safe integer
      final result = await _conn!.execute(
        'SELECT * FROM processes '
        'WHERE collected_at >= DATE_SUB(NOW(), INTERVAL 30 SECOND) '
        'ORDER BY cpu_pct DESC LIMIT $limit',
      );
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      log('Exception caught', error: e);
      _log.warning('queryTopProcesses error: $e');
      return [];
    }
  }

  /// Queries recent warning alert events triggered on the node.
  Future<List<Map<String, dynamic>>> queryRecentAlerts({int limit = 50}) async {
    if (_conn == null) return [];
    try {
      final result = await _conn!.execute(
        'SELECT * FROM alert_events ORDER BY triggered_at DESC LIMIT $limit',
      );
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      log('Exception caught', error: e);
      _log.warning('queryRecentAlerts error: $e');
      return [];
    }
  }

  /// Deletes logs older than [retentionDays] to prevent disk overflow.
  Future<void> runRetentionCleanup(int retentionDays) async {
    _log.info(
        'Running retention cleanup (keeping last $retentionDays days)...');
    final tables = [
      'metrics',
      'processes',
      'connections',
      'user_sessions',
      'api_calls'
    ];
    for (final table in tables) {
      try {
        await _conn!.execute(
          'DELETE FROM $table WHERE collected_at < DATE_SUB(NOW(), INTERVAL $retentionDays DAY)',
        );
      } catch (e) {
        log('Exception caught', error: e);
        _log.warning('Retention cleanup error on $table: $e');
      }
    }
    _log.info('Retention cleanup complete.');
  }
}
