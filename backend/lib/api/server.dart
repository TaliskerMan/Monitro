// Monitro HTTPS API Server
// Serves the collector's live data to the Flutter UI over localhost HTTPS.

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import '../collectors/collector_manager.dart';
import '../storage/mariadb_service.dart';

final _log = Logger('MonitroApiServer');

class MonitroApiServer {
  final YamlMap config;
  final String configDir;   // Directory of monitro.yaml — used to resolve relative paths
  final MariaDbService dbService;
  final CollectorManager collectorManager;
  HttpServer? _server;

  MonitroApiServer({
    required this.config,
    required this.configDir,
    required this.dbService,
    required this.collectorManager,
  });

  Future<void> start() async {
    final host = config['host'] as String? ?? '127.0.0.1';
    final port = config['port'] as int? ?? 8443;
    final certRelPath = config['cert'] as String? ?? 'certs/server.crt';
    final keyRelPath  = config['key']  as String? ?? 'certs/server.key';
    // Resolve relative to config file's directory, so running from backend/ works correctly
    final certPath = certRelPath.startsWith('/') ? certRelPath : '$configDir/$certRelPath';
    final keyPath  = keyRelPath.startsWith('/')  ? keyRelPath  : '$configDir/$keyRelPath';

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

  Future<void> stop() async {
    await _server?.close(force: true);
    _log.info('API server stopped.');
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Response _handleHealth(Request request) {
    return _json({'status': 'ok', 'version': '0.1.0'});
  }

  Response _handleCurrentMetrics(Request request) {
    return _json(collectorManager.latestSnapshot);
  }

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

  Future<Response> _handleKillProcess(Request request, String pidStr) async {
    final pid = int.tryParse(pidStr);
    if (pid == null) return Response.badRequest(body: 'Invalid PID');
    
    try {
      if (Platform.isWindows) {
        await Process.run('powershell', ['-Command', 'Stop-Process -Id $pid -Force']);
      } else {
        await Process.run('kill', ['-9', pid.toString()]);
      }
      _log.warning('Killed process $pid via API request');
      return _json({'status': 'killed', 'pid': pid});
    } catch (e) {
      _log.severe('Failed to kill process $pid', e);
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Response _handleConnections(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['netstat'] ?? {'error': 'no data'});
  }

  Response _handleUsers(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['users'] ?? {'error': 'no data'});
  }

  Response _handleApiCalls(Request request) {
    final snapshot = collectorManager.latestSnapshot;
    return _json(snapshot['api_calls'] ?? {'error': 'no data'});
  }

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

  Response _json(dynamic data) {
    return Response.ok(
      jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          });
        }
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
        });
      };
    };
  }
}
