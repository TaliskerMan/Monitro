// Network Interface Collector — cross-platform
import 'dart:developer';
import 'dart:io';

/// Collector for querying and parsing network interface metrics.
///
/// Gathers bandwidth usage, packet counts, errors, and drop statistics across
/// physical and virtual interfaces on Linux (via `/proc/net/dev`), macOS (via `netstat -ib`),
/// and Windows (via PowerShell NetAdapter cmdlets).
class NetworkCollector {
  /// Gathers active network interface metrics and throughput states based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final content = await File('/proc/net/dev').readAsString();
      final lines = content.split('\n').skip(2); // skip header lines
      final interfaces = <Map<String, dynamic>>[];
      for (final line in lines) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        final iface = line.substring(0, colon).trim();
        final parts = line
            .substring(colon + 1)
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length < 16) continue;
        interfaces.add({
          'interface': iface,
          'rx_bytes': int.tryParse(parts[0]) ?? 0,
          'rx_packets': int.tryParse(parts[1]) ?? 0,
          'rx_errors': int.tryParse(parts[2]) ?? 0,
          'rx_dropped': int.tryParse(parts[3]) ?? 0,
          'tx_bytes': int.tryParse(parts[8]) ?? 0,
          'tx_packets': int.tryParse(parts[9]) ?? 0,
          'tx_errors': int.tryParse(parts[10]) ?? 0,
          'tx_dropped': int.tryParse(parts[11]) ?? 0,
        });
      }
      return {'platform': 'linux', 'interfaces': interfaces};
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      // Use `netstat -ib` to get stats for all interfaces
      final allResult = await Process.run('netstat', ['-ib'], runInShell: true);
      final lines = allResult.stdout.toString().split('\n');
      final interfaces = <Map<String, dynamic>>[];
      for (var index = 1; index < lines.length; index++) {
        final parts = lines[index].trim().split(RegExp(r'\s+'));
        if (parts.length < 10) continue;
        interfaces.add({
          'interface': parts[0],
          'rx_packets': int.tryParse(parts[4]) ?? 0,
          'rx_errors': int.tryParse(parts[5]) ?? 0,
          'rx_bytes': int.tryParse(parts[6]) ?? 0,
          'tx_packets': int.tryParse(parts[7]) ?? 0,
          'tx_errors': int.tryParse(parts[8]) ?? 0,
          'tx_bytes': int.tryParse(parts[9]) ?? 0,
        });
      }
      return {'platform': 'macos', 'interfaces': interfaces};
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NonInteractive',
          '-Command',
          'Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes | ConvertTo-Json',
        ],
      );
      return {'platform': 'windows', 'raw': result.stdout.toString()};
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }
}
