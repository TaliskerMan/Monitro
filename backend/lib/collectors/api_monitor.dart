// API / Outbound HTTP Call Monitor — cross-platform
// Identifies which local processes are making outbound HTTP/HTTPS connections
// by correlating netstat/lsof connections on ports 80 and 443 with process names.
import 'dart:developer';
import 'dart:io';

/// Monitor for identifying active outbound HTTP/HTTPS connections.
///
/// Correlates active TCP sockets with ports commonly utilized by Web APIs
/// (e.g. 80, 443, 8080) to count connections grouped by process name.
class ApiMonitor {
  /// Ports considered as outbound HTTP/HTTPS/API calls.
  static const _httpPorts = {80, 443, 8080, 8443, 8000, 3000, 4000, 5000};

  /// Dispatches collector processes to identify outbound API connection metrics based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  /// Linux: use 'ss -tnp state established' to find outbound HTTP connections per process
  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final result = await Process.run(
        'ss',
        ['-tnp', 'state', 'established'],
        runInShell: true,
      );
      return _parseSsApiCalls(result.stdout.toString(), 'linux');
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  /// macOS: lsof -i tcp -n -P -s TCP:ESTABLISHED
  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      final result = await Process.run(
        'lsof',
        ['-i', 'tcp', '-n', '-P', '-s', 'TCP:ESTABLISHED'],
        runInShell: true,
      );
      return _parseLsofApiCalls(result.stdout.toString(), 'macos');
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'netstat',
        ['-anob'],
        runInShell: true,
      );
      return _parseWindowsNetstatApiCalls(result.stdout.toString());
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers (count outbound calls per process name, filtered to HTTP ports)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _parseSsApiCalls(String output, String platform) {
    // Build a map: process_name -> call_count
    final callers = <String, int>{};
    for (final line in output.split('\n')) {
      // Filter to HTTP ports in the remote address
      var isHttpPort = false;
      for (final port in _httpPorts) {
        if (line.contains(':$port ') || line.contains(':$port\t')) {
          isHttpPort = true;
          break;
        }
      }
      if (!isHttpPort) continue;

      // Extract process name from ss output: users:(("curl",pid=1234,fd=5))
      final m = RegExp(r'users:\(\("?([^"]+)"?,').firstMatch(line);
      if (m != null) {
        final name = m.group(1)!;
        callers[name] = (callers[name] ?? 0) + 1;
      }
    }
    return {
      'platform': platform,
      'api_callers': callers.entries
          .map((entry) => {'process': entry.key, 'connections': entry.value})
          .toList()
        ..sort((a, b) =>
            (b['connections']! as int).compareTo(a['connections']! as int)),
    };
  }

  static Map<String, dynamic> _parseLsofApiCalls(
      String output, String platform) {
    final callers = <String, int>{};
    for (final line in output.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 9) continue;
      final processName = parts[0];
      final network = parts[8]; // e.g. "192.168.1.1:52345->1.2.3.4:443"
      var isHttpPort = false;
      for (final port in _httpPorts) {
        if (network.endsWith(':$port') || network.contains(':$port (')) {
          isHttpPort = true;
          break;
        }
      }
      if (isHttpPort) {
        callers[processName] = (callers[processName] ?? 0) + 1;
      }
    }
    return {
      'platform': platform,
      'api_callers': callers.entries
          .map((entry) => {'process': entry.key, 'connections': entry.value})
          .toList()
        ..sort((a, b) =>
            (b['connections']! as int).compareTo(a['connections']! as int)),
    };
  }

  static Map<String, dynamic> _parseWindowsNetstatApiCalls(String output) {
    final callers = <String, int>{};
    for (final line in output.split('\n')) {
      if (!line.trim().startsWith('TCP')) continue;
      var isHttpPort = false;
      for (final port in _httpPorts) {
        if (line.contains(':$port ')) {
          isHttpPort = true;
          break;
        }
      }
      if (isHttpPort) {
        // Windows netstat -anob shows process name on line after connection
        // This is approximate — actual correlation requires multi-line parsing
        callers['unknown'] = (callers['unknown'] ?? 0) + 1;
      }
    }
    return {
      'platform': 'windows',
      'api_callers': callers.entries
          .map((entry) => {'process': entry.key, 'connections': entry.value})
          .toList(),
    };
  }
}
