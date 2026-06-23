// Monitro HTTPS API Server
// Serves the collector's live data to the Flutter UI over localhost HTTPS.

import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import '../collectors/collector_manager.dart';
import '../storage/mariadb_service.dart';
import '../version.dart';

final _log = Logger('MonitroApiServer');

/// Pure authorization decision (testable without a running server).
///
/// Returns true if the request should be allowed. `/health` and CORS preflight
/// are always allowed; every other endpoint requires `Authorization: Bearer
/// <apiKey>`.
bool isRequestAuthorized({
  required String method,
  required String path,
  required String? authHeader,
  required String apiKey,
}) {
  if (method == 'OPTIONS') return true;
  // shelf strips the leading slash from request.url.path.
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  if (normalized == 'api/v1/health') return true;
  return authHeader == 'Bearer $apiKey';
}

/// shelf HTTP/HTTPS server orchestrating UI metric endpoints.
///
/// Binds routing pathways to fetch real-time memory metrics, database historical logs,
/// and execute administrative signals (e.g. process termination). Binds CORS and Auth middleware.
class MonitroApiServer {
  /// Raw configuration Map containing host and port specifications.
  final YamlMap config;

  /// Absolute directory path used to resolve SSL file resource scopes.
  final String configDir;

  /// Database helper class mapping historical queries.
  final MariaDbService dbService;

  /// System metrics manager containing caching state references.
  final CollectorManager collectorManager;

  HttpServer? _server;

  /// Creates a [MonitroApiServer] instance.
  MonitroApiServer({
    required this.config,
    required this.configDir,
    required this.dbService,
    required this.collectorManager,
  });

  /// Configure shelf pipelines, bind SSL contexts, and spin up the server.
  Future<void> start() async {
    final host = config['host'] as String? ?? '127.0.0.1';
    final port = config['port'] as int? ?? 8443;
    final certRelPath = config['cert'] as String? ?? 'certs/server.crt';
    final keyRelPath  = config['key']  as String? ?? 'certs/server.key';
    // Resolve relative to config file's directory, so running from backend/ works correctly
    final certPath = certRelPath.startsWith('/') ? certRelPath : '$configDir/$certRelPath';
    final keyPath  = keyRelPath.startsWith('/')  ? keyRelPath  : '$configDir/$keyRelPath';
    final apiKey   = config['api_key'] as String?;

    // Security: the api_key is the only thing standing between a local web
    // origin and the process-kill endpoint. Refuse to start without one rather
    // than silently exposing every endpoint (P1-4).
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Refusing to start: no api_key configured. Set api_key in the collector '
        'config (the desktop app generates one automatically). Starting without '
        'a key would expose system telemetry and DELETE /processes to any local '
        'web origin.',
      );
    }

    final router = Router()
      ..get('/api/v1/health',              _handleHealth)
      ..get('/api/v1/metrics/current',     _handleCurrentMetrics)
      ..get('/api/v1/metrics/history',     _handleMetricHistory)
      ..get('/api/v1/processes',           _handleProcesses)
      ..delete('/api/v1/processes/<pid>',  _handleKillProcess)
      ..get('/api/v1/connections',         _handleConnections)
      ..get('/api/v1/users',               _handleUsers)
      ..get('/api/v1/api-calls',           _handleApiCalls)
      ..get('/api/v1/alerts',              _handleAlerts);

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware(apiKey))
        .addMiddleware(logRequests())
        .addHandler(router.call);

    // Load SSL context
    SecurityContext? context;
    final certFile = File(certPath);
    final keyFile  = File(keyPath);

    if (certFile.existsSync() && keyFile.existsSync()) {
      context = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);
      _log.info('SSL certificates loaded: $certPath');
    } else {
      _log.warning('SSL certs not found — starting HTTP (run certs/gen_certs.sh first)');
    }

    _server = await shelf_io.serve(
      handler,
      host,
      port,
      securityContext: context,
    );

    final scheme = context != null ? 'https' : 'http';
    _log.info('Monitro API server started: $scheme://$host:$port');
  }

  /// Close the listening shelf httpServer.
  Future<void> stop() async {
    await _server?.close(force: true);
    _log.info('API server stopped.');
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Health check ping endpoint.
  Response _handleHealth(Request request) {
    return _json({'status': 'ok', 'version': monitroVersion});
  }

  /// Expose the current metrics snapshot cache.
  Response _handleCurrentMetrics(Request request) {
    return _json(collectorManager.latestSnapshot);
  }

  /// Query historical records logged in MariaDB tables.
  Future<Response> _handleMetricHistory(Request request) async {
    final params = request.url.queryParameters;
    final metric  = params['metric'] ?? 'cpu.busy_pct';
    final label   = params['label'];
    final minutes = int.tryParse(params['minutes'] ?? '60') ?? 60;

    final data = await dbService.queryMetricHistory(
      metricName: metric,
      label: label,
      minutes: minutes,
    );
    return _json({'metric': metric, 'minutes': minutes, 'data': data});
  }

  /// Query top processes list. Bypasses database queries if live cached stats exist.
  Future<Response> _handleProcesses(Request request) async {
    final limit = int.tryParse(
      request.url.queryParameters['limit'] ?? '20',
    ) ?? 20;
    // Return live snapshot for lowest latency, fall back to DB
    final snapshot = collectorManager.latestSnapshot;
    final procData = snapshot['processes'];
    if (procData != null && procData['error'] == null) {
      final processes = (procData['processes'] as List? ?? []).take(limit).toList();
      return _json({'processes': processes, 'source': 'live'});
    }
    final dbData = await dbService.queryTopProcesses(limit: limit);
    return _json({'processes': dbData, 'source': 'db'});
  }

  /// Terminate a running system process by PID. Tries a graceful SIGTERM first
  /// and only escalates to SIGKILL if the process is still alive (P1-5).
  Future<Response> _handleKillProcess(Request request, String pidStr) async {
    final pid = int.tryParse(pidStr);
    if (pid == null) return Response.badRequest(body: 'Invalid PID');
    // Guard against killing init/kernel/critical low PIDs.
    if (pid <= 1) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Refusing to kill protected PID $pid'}),
      );
    }

    try {
      if (Platform.isWindows) {
        // Try a graceful close first, then force.
        await Process.run('taskkill', ['/PID', '$pid', '/T']);
        await Future.delayed(const Duration(seconds: 2));
        if (await _pidAlive(pid)) {
          await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
        }
      } else {
        await Process.run('kill', ['-TERM', pid.toString()]);
        await Future.delayed(const Duration(seconds: 2));
        if (await _pidAlive(pid)) {
          _log.warning('PID $pid survived SIGTERM; escalating to SIGKILL');
          await Process.run('kill', ['-KILL', pid.toString()]);
        }
      }
      _log.warning('Terminated process $pid via API request');
      return _json({'status': 'killed', 'pid': pid});
    } catch (e) {
      log('Exception caught', error: e);
      _log.severe('Failed to kill process $pid', e);
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Whether [pid] is still alive (signal-0 probe / tasklist on Windows).
  Future<bool> _pidAlive(int pid) async {
    if (Platform.isWindows) {
      final r = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
      return r.stdout.toString().contains('$pid');
    }
    final r = await Process.run('kill', ['-0', pid.toString()]);
    return r.exitCode == 0;
  }

  /// Retrieve live network socket logs.
  Response _handleConnections(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['netstat'] ?? {'error': 'no data'});
  }

  /// Retrieve current user sessions list.
  Response _handleUsers(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['users'] ?? {'error': 'no data'});
  }

  /// Retrieve API usage statistics.
  Response _handleApiCalls(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['api_calls'] ?? {'error': 'no data'});
  }

  /// Query recent warning alerts recorded in MariaDB.
  Future<Response> _handleAlerts(Request request) async {
    final limit = int.tryParse(
      request.url.queryParameters['limit'] ?? '50',
    ) ?? 50;
    final alerts = await dbService.queryRecentAlerts(limit: limit);
    return _json({'alerts': alerts});
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Helper to convert dynamic Maps into HTTP application/json responses.
  Response _json(dynamic data) {
    return Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// CORS middleware.
  ///
  /// The Monitro desktop UI talks to this server via dart:io (not a browser),
  /// so it needs no cross-origin access. We therefore do NOT emit a permissive
  /// `Access-Control-Allow-Origin: *` — that header would let any web page the
  /// user has open read their telemetry and call DELETE /processes (P1-4).
  /// Browser preflights are answered without an allow-origin, so browsers block
  /// cross-origin reads.
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response(204);
        }
        return await innerHandler(request);
      };
    };
  }

  /// Middleware checking API key authorization (delegates to the pure
  /// [isRequestAuthorized] so the decision is unit-testable). [apiKey] is
  /// guaranteed non-empty because start() refuses to run without it.
  Middleware _authMiddleware(String apiKey) {
    return (Handler innerHandler) {
      return (Request request) async {
        final ok = isRequestAuthorized(
          method: request.method,
          path: request.url.path,
          authHeader: request.headers['authorization'],
          apiKey: apiKey,
        );
        if (!ok) {
          return Response.forbidden(
              jsonEncode({'error': 'Unauthorized: Invalid API Key'}));
        }
        return await innerHandler(request);
      };
    };
  }
}

