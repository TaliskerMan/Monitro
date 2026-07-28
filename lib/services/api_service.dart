// Monitro API Service — talks to the backend collector over localhost HTTPS
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Client service that wraps API endpoints hosted by the local Monitro daemon collector.
///
/// Implements secure HTTPS requests using custom trust validations that permit local
/// connections, automatically injecting Authorization bearer headers when set.
class ApiService {
  /// Unique security token needed to authenticate requests to the collector API.
  static String? apiKey;

  /// Absolute path to the Monitro CA certificate (`ca.crt`). When set (e.g. by
  /// startup code that knows the app-support certs dir), the HTTPS client pins
  /// this CA instead of blindly trusting any localhost certificate.
  static String? caCertPath;

  static const String _baseUrl = 'https://127.0.0.1:8443/api/v1';

  /// Standard headers containing bearer authorization tokens.
  static Map<String, String> get _headers {
    final h = <String, String>{};
    if (apiKey != null) h['Authorization'] = 'Bearer $apiKey';
    return h;
  }

  static SecurityContext? _pinnedContext;
  static bool _contextResolved = false;

  /// Resolve the CA cert path: explicit override, then common locations.
  static String? _resolveCaCert() {
    final candidates = <String>[
      if (caCertPath != null) caCertPath!,
      if (Platform.environment['MONITRO_CA_CERT'] != null)
        Platform.environment['MONITRO_CA_CERT']!,
      // Packaged macOS bundle: <App>.app/Contents/Resources/certs/ca.crt
      '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/certs/ca.crt',
      // Dev tree.
      '${Directory.current.path}/certs/ca.crt',
    ];
    for (final candidate in candidates) {
      if (candidate.isNotEmpty && File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  /// HTTPS client. Pins the local Monitro CA when it can be found (the server
  /// cert is then validated against it); otherwise falls back to accepting only
  /// localhost self-signed certs, with a warning logged (P1-4).
  static http.Client get _client {
    if (!_contextResolved) {
      _contextResolved = true;
      final ca = _resolveCaCert();
      if (ca != null) {
        try {
          _pinnedContext = SecurityContext()..setTrustedCertificates(ca);
        } catch (error) {
          log('Failed to load pinned CA; falling back', error: error);
          _pinnedContext = null;
        }
      } else {
        log('Monitro CA cert not found — TLS is not pinned (localhost-only trust).');
      }
    }

    final HttpClient ioClient;
    if (_pinnedContext != null) {
      // Validate the server cert against the pinned CA (no blanket bypass).
      ioClient = HttpClient(context: _pinnedContext);
    } else {
      ioClient = HttpClient()
        ..badCertificateCallback =
            (cert, host, port) => host == '127.0.0.1' || host == 'localhost';
    }
    return IOClient(ioClient);
  }

  /// Query the health endpoint to determine if the backend is actively listening.
  static Future<bool> isBackendHealthy() async {
    try {
      final response =
          await _client.get(Uri.parse('$_baseUrl/health'), headers: _headers);
      return response.statusCode == 200;
    } catch (error) {
      // The server listens with TLS on 8443; there is no HTTP fallback to try
      // (an http:// request to a TLS port cannot succeed), so report unhealthy.
      log('Backend health check failed', error: error);
      return false;
    }
  }

  /// Fetch the latest snapshot of system metrics (CPU, RAM, Disk, Load).
  static Future<Map<String, dynamic>> getCurrentMetrics() async {
    return _get('/metrics/current');
  }

  /// Retrieve historically logged values for a specific metric over a time window.
  ///
  /// Args:
  ///   metric: Key name of the metric query (e.g. cpu, memory).
  ///   label: Optional descriptor targeting a single core or partition.
  ///   minutes: Length of historical window, defaulting to 60 minutes.
  static Future<Map<String, dynamic>> getMetricHistory({
    required String metric,
    String? label,
    int minutes = 60,
  }) async {
    final q = label != null
        ? '?metric=$metric&label=$label&minutes=$minutes'
        : '?metric=$metric&minutes=$minutes';
    return _get('/metrics/history$q');
  }

  /// Fetch active processes sorted by current resources usage.
  static Future<Map<String, dynamic>> getProcesses({int limit = 20}) async {
    return _get('/processes?limit=$limit');
  }

  /// Send a delete command to terminate a running system process by PID.
  ///
  /// Args:
  ///   pid: Unique process identifier.
  static Future<Map<String, dynamic>> killProcess(int pid) async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/processes/$pid'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  /// Retrieve active network connections and socket states.
  static Future<Map<String, dynamic>> getConnections() async {
    return _get('/connections');
  }

  /// Retrieve current system logged-in users list.
  static Future<Map<String, dynamic>> getUsers() async {
    return _get('/users');
  }

  /// Retrieve historical API usage statistics logged by the collector.
  static Future<Map<String, dynamic>> getApiCalls() async {
    return _get('/api-calls');
  }

  /// Retrieve active or historical metric warning alerts.
  static Future<Map<String, dynamic>> getAlerts({int limit = 50}) async {
    return _get('/alerts?limit=$limit');
  }

  /// Run a GET request against the local daemon collector and deserialize the response.
  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response =
          await _client.get(Uri.parse('$_baseUrl$path'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }
}
