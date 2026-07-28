// Process Monitor Collector — cross-platform
// Returns the top N processes by CPU and memory usage.
import 'dart:io';

/// Collector for querying and parsing system process statistics.
///
/// Filters and sorts active node processes to isolate the top resources consumers
/// by CPU and memory usage. Supports Linux/macOS (via `ps`) and Windows (via PowerShell).
class ProcessCollector {
  /// The maximum number of top resource-consuming processes to record.
  static const int _topN = 50;

  /// Gathers lists of top processes running on the machine based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  /// Linux: parse /proc/[pid]/stat and /proc/[pid]/status for each process
  static Future<Map<String, dynamic>> _collectLinux() async {
    final result = await Process.run(
      'ps',
      [
        '-eo',
        'pid,ppid,user,pcpu,pmem,rss,nlwp,stat,args',
        '--no-headers',
        '--sort=-pcpu',
      ],
      runInShell: true,
    );
    return _parsePsOutput(result.stdout.toString(), 'linux');
  }

  /// macOS: ps with similar options
  static Future<Map<String, dynamic>> _collectMacOS() async {
    final result = await Process.run(
      'ps',
      [
        '-eo',
        'pid,ppid,user,pcpu,pmem,rss,nlwp,stat,args',
        '-r',
      ], // -r: sort by CPU
      runInShell: true,
    );
    return _parsePsOutput(result.stdout.toString(), 'macos');
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    final result = await Process.run(
      'powershell',
      [
        '-NonInteractive',
        '-Command',
        'Get-Process | Sort-Object CPU -Descending | '
            'Select-Object -First $_topN Id,Name,CPU,WorkingSet,Threads | ConvertTo-Json',
      ],
    );
    return {'platform': 'windows', 'raw': result.stdout.toString()};
  }

  static Map<String, dynamic> _parsePsOutput(String output, String platform) {
    final processes = <Map<String, dynamic>>[];
    var count = 0;
    for (final line in output.split('\n')) {
      if (line.trim().isEmpty) continue;

      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 8) continue;

      // Skip header row (PID is not a number)
      final pid = int.tryParse(parts[0]);
      if (pid == null) continue;

      if (count++ >= _topN) break;

      processes.add({
        'pid': pid,
        'ppid': int.tryParse(parts[1]),
        'user': parts[2],
        'cpu_pct': double.tryParse(parts[3]) ?? 0.0,
        'mem_pct': double.tryParse(parts[4]) ?? 0.0,
        'rss_kb': int.tryParse(parts[5]) ?? 0,
        'threads': int.tryParse(parts[6]) ?? 1,
        'state': parts[7],
        'cmdline': parts.sublist(8).join(' '),
      });
    }
    return {'platform': platform, 'processes': processes};
  }
}
