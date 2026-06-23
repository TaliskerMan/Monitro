// CPU Collector — cross-platform
// Reads CPU utilization for macOS, Linux, and Windows.

import 'dart:developer';
import 'dart:io';

/// Collector for querying and parsing CPU utilization metrics.
///
/// Handles multi-core queries across Linux (via `/proc/stat`), macOS (via `top` and `sysctl`),
/// and Windows (via PowerShell WMI class queries). Computes relative delta utilization.
class CpuCollector {
  /// Historical total CPU ticks cache mapped by core identifier.
  static final Map<String, int> _lastTotal = {};

  /// Historical active CPU ticks cache mapped by core identifier.
  static final Map<String, int> _lastBusy = {};

  /// Gathers CPU utilization metrics and core stats based on the host OS.
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
      double rootBusyPct = 0.0;
      double rootIdlePct = 100.0;

      for (final line in lines) {
        if (!line.startsWith('cpu')) continue;
        final parts = line.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
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

        double busyPct = 0.0;
        if (_lastTotal.containsKey(name)) {
          final dTotal = total - _lastTotal[name]!;
          final dBusy = busyTime - _lastBusy[name]!;
          if (dTotal > 0) busyPct = (dBusy / dTotal) * 100.0;
        }
        _lastTotal[name] = total;
        _lastBusy[name] = busyTime;

        if (name == 'cpu') {
          rootBusyPct = busyPct;
          rootIdlePct = 100.0 - busyPct;
        } else {
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
            'busy_pct': busyPct,
          });
        }
      }

      return {'platform': 'linux', 'busy_pct': rootBusyPct, 'idle_pct': rootIdlePct, 'cores': coreStats};
    } catch (e) {
      log('Exception caught', error: e);
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
        // macOS per-core figures are the aggregate value repeated (real per-core
        // needs powermetrics/root). Flag it so the UI can label it honestly.
        'per_core_real': false,
      };
    } catch (e) {
      log('Exception caught', error: e);
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
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }
}
