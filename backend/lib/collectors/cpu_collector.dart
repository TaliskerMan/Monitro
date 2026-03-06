// CPU Collector — cross-platform
// Reads CPU utilization for macOS, Linux, and Windows.

import 'dart:io';

class CpuCollector {
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform: ${Platform.operatingSystem}'};
  }

  // -------------------------------------------------------------------------
  // Linux: parse /proc/stat
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final content = await File('/proc/stat').readAsString();
      final lines = content.split('\n');
      final coreStats = <Map<String, dynamic>>[];

      for (final line in lines) {
        if (!line.startsWith('cpu')) continue;
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 8) continue;

        final name = parts[0]; // 'cpu', 'cpu0', 'cpu1', ...
        final user    = int.tryParse(parts[1]) ?? 0;
        final nice    = int.tryParse(parts[2]) ?? 0;
        final system  = int.tryParse(parts[3]) ?? 0;
        final idle    = int.tryParse(parts[4]) ?? 0;
        final iowait  = int.tryParse(parts[5]) ?? 0;
        final irq     = int.tryParse(parts[6]) ?? 0;
        final softirq = int.tryParse(parts[7]) ?? 0;
        final steal   = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;

        final total = user + nice + system + idle + iowait + irq + softirq + steal;
        final busyTime = total - idle - iowait;

        coreStats.add({
          'core':    name,
          'user':    user,
          'nice':    nice,
          'system':  system,
          'idle':    idle,
          'iowait':  iowait,
          'irq':     irq,
          'softirq': softirq,
          'steal':   steal,
          'total':   total,
          'busy':    busyTime,
          // Percent values require two samples to compute (delta). 
          // The MariaDB service uses the delta between successive readings.
        });
      }
      
      num sysTotal = 0;
      num sysBusy = 0;
      for (var core in coreStats) {
        if (core['core'] != 'cpu') continue; 
        sysTotal = core['total'] as num;
        sysBusy = core['busy'] as num;
        break;
      }

      // If 'cpu' total line exists, busy_pct will be calculated as a delta by mariadb,
      // but the API consumer just looks for busy_pct. The MariaDb expects `busy` and `total` at root level.
      return {
        'platform': 'linux', 
        'cores': coreStats,
        'busy': sysBusy,
        'total': sysTotal,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // -------------------------------------------------------------------------
  // macOS: use sysctl + top -l 1 -n 0
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      final result = await Process.run(
        'top', ['-l', '1', '-n', '0', '-stats', 'cpu'],
        runInShell: true,
      );
      final output = result.stdout.toString();

      // Parse "CPU usage: 12.5% user, 8.2% sys, 79.2% idle"
      final cpuLine = output.split('\n').firstWhere(
        (l) => l.startsWith('CPU usage:'),
        orElse: () => '',
      );

      double user = 0, sys = 0, idle = 0;
      if (cpuLine.isNotEmpty) {
        final userMatch = RegExp(r'([\d.]+)% user').firstMatch(cpuLine);
        final sysMatch  = RegExp(r'([\d.]+)% sys').firstMatch(cpuLine);
        final idleMatch = RegExp(r'([\d.]+)% idle').firstMatch(cpuLine);
        user = double.tryParse(userMatch?.group(1) ?? '0') ?? 0;
        sys  = double.tryParse(sysMatch?.group(1)  ?? '0') ?? 0;
        idle = double.tryParse(idleMatch?.group(1) ?? '0') ?? 0;
      }

      // Core count via sysctl
      final sysctlResult = await Process.run(
        'sysctl', ['-n', 'hw.logicalcpu'],
        runInShell: true,
      );
      final coreCount = int.tryParse(sysctlResult.stdout.toString().trim()) ?? 1;
      
      // macOS does not expose per-core load without root privileges (powermetrics)
      // We simulate the output structure using the aggregate load so the UI visualizer works.
      final cores = List.generate(coreCount, (i) => {
        'core': 'cpu$i',
        'busy_pct': user + sys, 
      });

      return {
        'platform':    'macos',
        'user_pct':    user,
        'sys_pct':     sys,
        'idle_pct':    idle,
        'busy_pct':    user + sys,
        'logical_cores': coreCount,
        'cores': cores,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // -------------------------------------------------------------------------
  // Windows: use wmic or PowerShell Get-CimInstance
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'powershell', [
          '-NonInteractive', '-Command',
          '(Get-CimInstance -ClassName Win32_Processor | '
          'Measure-Object -Property LoadPercentage -Average).Average',
        ],
      );
      final loadPct = double.tryParse(result.stdout.toString().trim()) ?? 0;
      return {
        'platform': 'windows',
        'busy_pct': loadPct,
        'idle_pct': 100.0 - loadPct,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
