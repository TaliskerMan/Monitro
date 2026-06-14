// Filesystem Usage Collector — cross-platform (df -P)
import 'dart:developer';
import 'dart:io';

/// Collector for querying and parsing filesystem mount capacity details.
///
/// Executes native mount queries across POSIX systems (via `df -P -k`)
/// and Windows (via PowerShell PSDrive cmdlets).
class FsCollector {
  /// Gathers active partition storage boundaries and usage percentages based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isWindows) return _collectWindows();
    return _collectPosix();
  }

  static Future<Map<String, dynamic>> _collectPosix() async {
    try {
      final result = await Process.run('df', ['-P', '-k'], runInShell: true);
      final lines = result.stdout.toString().split('\n');
      final mounts = <Map<String, dynamic>>[];
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].trim().split(RegExp(r'\s+'));
        if (parts.length < 6) continue;
        final totalKb = int.tryParse(parts[1]) ?? 0;
        final usedKb  = int.tryParse(parts[2]) ?? 0;
        final availKb = int.tryParse(parts[3]) ?? 0;
        mounts.add({
          'filesystem': parts[0],
          'total_kb':   totalKb,
          'used_kb':    usedKb,
          'avail_kb':   availKb,
          'use_pct':    totalKb > 0 ? (usedKb / totalKb * 100) : 0.0,
          'mount':      parts[5],
        });
      }
      return {'platform': Platform.operatingSystem, 'mounts': mounts};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'powershell', [
          '-NonInteractive', '-Command',
          'Get-PSDrive -PSProvider FileSystem | '
          'Select-Object Name, Used, Free | ConvertTo-Json',
        ],
      );
      return {'platform': 'windows', 'raw': result.stdout.toString()};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }
}
