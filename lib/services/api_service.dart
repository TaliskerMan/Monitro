// Monitro API Service — talks to the backend collector over localhost HTTPS
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

/// Client service that wraps API endpoints hosted by the local Monitro daemon collector.
///
/// Implements secure HTTPS requests using custom trust validations that permit local
/// connections, automatically injecting Authorization bearer headers when set.
class ApiService {
  /// Unique security token needed to authenticate requests to the collector API.
  static String? apiKey;
  static String _baseUrl = 'https://127.0.0.1:8443/api/v1';

  /// Standard headers containing bearer authorization tokens.
  static Map<String, String> get _headers {
    final h = <String, String>{};
    if (apiKey != null) h['Authorization'] = 'Bearer $apiKey';
    return h;
  }

  /// HTTP client that trusts the local Monitro CA certificate.
  static http.Client get _client {
    // On desktop, we use a custom HttpClient that bypasses cert validation for localhost.
    // In production, load the local CA cert instead.
    final ioClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        // Only allow self-signed certs from localhost / 127.0.0.1
        return host == '127.0.0.1' || host == 'localhost';
      };
    return IOClient(ioClient);
  }

  /// Query the health endpoint to determine if the backend is actively listening.
  ///
  /// Automatically falls back from HTTPS to HTTP if HTTPS TLS handshakes fail.
  static Future<bool> isBackendHealthy() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/health'), headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      log('Exception caught', error: e);
      if (_baseUrl.startsWith('https://')) {
        // Fallback to HTTP and retry
        _baseUrl = 'http://127.0.0.1:8443/api/v1';
        try {
          final fallbackResponse = await _client.get(Uri.parse('$_baseUrl/health'), headers: _headers);
          return fallbackResponse.statusCode == 200;
        } catch (e) {
      log('Exception caught', error: e);
          return false;
        }
      }
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
      final response = await _client.delete(Uri.parse('$_baseUrl/processes/$pid'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
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
      final response = await _client.get(Uri.parse('$_baseUrl$path'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }
}

