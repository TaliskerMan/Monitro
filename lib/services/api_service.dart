// Monitro API Service — talks to the backend collector over localhost HTTPS
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class ApiService {
  static String _baseUrl = 'https://127.0.0.1:8443/api/v1';

  /// HTTP client that trusts the local Monitro CA certificate
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

  static Future<bool> isBackendHealthy() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      if (_baseUrl.startsWith('https://')) {
        // Fallback to HTTP and retry
        _baseUrl = 'http://127.0.0.1:8443/api/v1';
        try {
          final fallbackResponse = await _client.get(Uri.parse('$_baseUrl/health'));
          return fallbackResponse.statusCode == 200;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>> getCurrentMetrics() async {
    return _get('/metrics/current');
  }

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

  static Future<Map<String, dynamic>> getProcesses({int limit = 20}) async {
    return _get('/processes?limit=$limit');
  }

  static Future<Map<String, dynamic>> killProcess(int pid) async {
    try {
      final response = await _client.delete(Uri.parse('$_baseUrl/processes/$pid'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getConnections() async {
    return _get('/connections');
  }

  static Future<Map<String, dynamic>> getUsers() async {
    return _get('/users');
  }

  static Future<Map<String, dynamic>> getApiCalls() async {
    return _get('/api-calls');
  }

  static Future<Map<String, dynamic>> getAlerts({int limit = 50}) async {
    return _get('/alerts?limit=$limit');
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl$path'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
