// Netstat Collector — active TCP/UDP connections, cross-platform
import 'dart:io';

class NetstatCollector {
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  /// Linux: use 'ss -tnup' (socket statistics, human-readable)
  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final result = await Process.run(
        'ss', ['-tnup', '--no-header'], runInShell: true,
      );
      final connections = _parseSSOutput(result.stdout.toString());
      final summary = _summarize(connections);
      return {'platform': 'linux', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// macOS: use 'netstat -anv -p tcp' and 'netstat -anv -p udp'
  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      final tcpResult = await Process.run(
        'netstat', ['-anv', '-p', 'tcp'], runInShell: true,
      );
      final udpResult = await Process.run(
        'netstat', ['-anv', '-p', 'udp'], runInShell: true,
      );
      final connections = [
        ..._parseNetstatOutput(tcpResult.stdout.toString(), 'tcp'),
        ..._parseNetstatOutput(udpResult.stdout.toString(), 'udp'),
      ];
      final summary = _summarize(connections);
      return {'platform': 'macos', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'netstat', ['-ano'], runInShell: true,
      );
      final connections = _parseWindowsNetstat(result.stdout.toString());
      final summary = _summarize(connections);
      return {'platform': 'windows', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseSSOutput(String output) {
    final connections = <Map<String, dynamic>>[];
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      connections.add({
        'protocol': parts[0].toLowerCase(),
        'state':    parts[1],
        'local':    parts[4],
        'remote':   parts.length > 5 ? parts[5] : '',
      });
    }
    return connections;
  }

  static List<Map<String, dynamic>> _parseNetstatOutput(String output, String proto) {
    final connections = <Map<String, dynamic>>[];
    for (final line in output.split('\n')) {
      if (!line.startsWith(proto)) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      connections.add({
        'protocol': parts[0].toLowerCase(),
        'local':    parts[3],
        'remote':   parts[4],
        'state':    parts.length > 5 ? parts[5] : '',
      });
    }
    return connections;
  }

  static List<Map<String, dynamic>> _parseWindowsNetstat(String output) {
    final connections = <Map<String, dynamic>>[];
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      if (parts[0] != 'TCP' && parts[0] != 'UDP') continue;
      connections.add({
        'protocol': parts[0].toLowerCase(),
        'local':    parts[1],
        'remote':   parts[2],
        'state':    parts.length > 3 ? parts[3] : '',
      });
    }
    return connections;
  }

  static Map<String, int> _summarize(List<Map<String, dynamic>> connections) {
    final summary = <String, int>{};
    for (final conn in connections) {
      final state = (conn['state'] as String? ?? 'UNKNOWN').toUpperCase();
      summary[state] = (summary[state] ?? 0) + 1;
    }
    return summary;
  }
}
