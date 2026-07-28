// Memory Collector — cross-platform
import 'dart:developer';
import 'dart:io';

/// Collector for querying and parsing system memory utilization metrics.
///
/// Retrieves physical memory limits, active page caching, and swap metrics
/// on Linux (via `/proc/meminfo`), macOS (via `sysctl` and `vm_stat`), and Windows (via PowerShell).
class MemoryCollector {
  /// Gathers active physical and swap memory metrics based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final content = await File('/proc/meminfo').readAsString();
      final map = <String, int>{};
      for (final line in content.split('\n')) {
        final parts = line.split(':');
        if (parts.length < 2) continue;
        final key = parts[0].trim();
        final valStr = parts[1].trim().split(' ')[0];
        map[key] = int.tryParse(valStr) ?? 0;
      }

      final totalKb = map['MemTotal'] ?? 0;
      final freeKb = map['MemFree'] ?? 0;
      final availableKb = map['MemAvailable'] ?? 0;
      final buffersKb = map['Buffers'] ?? 0;
      final cachedKb = map['Cached'] ?? 0;
      final usedKb = totalKb - availableKb;
      final swapTotalKb = map['SwapTotal'] ?? 0;
      final swapFreeKb = map['SwapFree'] ?? 0;
      final swapUsedKb = swapTotalKb - swapFreeKb;

      return {
        'platform': 'linux',
        'total_kb': totalKb,
        'free_kb': freeKb,
        'available_kb': availableKb,
        'used_kb': usedKb,
        'buffers_kb': buffersKb,
        'cached_kb': cachedKb,
        'swap_total_kb': swapTotalKb,
        'swap_free_kb': swapFreeKb,
        'swap_used_kb': swapUsedKb,
        'used_pct': totalKb > 0 ? (usedKb / totalKb * 100) : 0.0,
        'swap_used_pct':
            swapTotalKb > 0 ? (swapUsedKb / swapTotalKb * 100) : 0.0,
      };
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      // Get physical memory via sysctl
      final memResult = await Process.run(
        'sysctl',
        ['-n', 'hw.memsize'],
        runInShell: true,
      );
      final totalBytes = int.tryParse(memResult.stdout.toString().trim()) ?? 0;

      // vm_stat for page breakdown
      final vmResult = await Process.run('vm_stat', [], runInShell: true);
      final vmOutput = vmResult.stdout.toString();

      var pageSize = 4096;
      final pageSizeLine = vmOutput
          .split('\n')
          .firstWhere((l) => l.contains('page size of'), orElse: () => '');
      if (pageSizeLine.isNotEmpty) {
        final m = RegExp(r'(\d+) bytes').firstMatch(pageSizeLine);
        if (m != null) pageSize = int.tryParse(m.group(1)!) ?? 4096;
      }

      int getPages(String key) {
        final line = vmOutput
            .split('\n')
            .firstWhere((l) => l.startsWith(key), orElse: () => '');
        if (line.isEmpty) return 0;
        final m = RegExp(r'(\d+)').firstMatch(line.split(':').last);
        return int.tryParse(m?.group(1) ?? '0') ?? 0;
      }

      final freePages = getPages('Pages free');
      final activePages = getPages('Pages active');
      final inactivePages = getPages('Pages inactive');
      final wiredPages = getPages('Pages wired down');

      final usedBytes = (wiredPages + activePages) * pageSize;
      final freeBytes = freePages * pageSize;

      return {
        'platform': 'macos',
        'total_bytes': totalBytes,
        'used_bytes': usedBytes,
        'free_bytes': freeBytes,
        'active_bytes': activePages * pageSize,
        'inactive_bytes': inactivePages * pageSize,
        'wired_bytes': wiredPages * pageSize,
        'used_pct': totalBytes > 0 ? (usedBytes / totalBytes * 100) : 0.0,
      };
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
          r'$os = Get-CimInstance Win32_OperatingSystem; '
              r'[PSCustomObject]@{Total=$os.TotalVisibleMemorySize;Free=$os.FreePhysicalMemory} | ConvertTo-Json',
        ],
      );
      // Parse JSON from PowerShell
      final output = result.stdout.toString().trim();
      // Simple regex parse (avoid json dependency in stub)
      final totalMatch = RegExp(r'"Total"\s*:\s*(\d+)').firstMatch(output);
      final freeMatch = RegExp(r'"Free"\s*:\s*(\d+)').firstMatch(output);
      final totalKb = int.tryParse(totalMatch?.group(1) ?? '0') ?? 0;
      final freeKb = int.tryParse(freeMatch?.group(1) ?? '0') ?? 0;
      final usedKb = totalKb - freeKb;
      return {
        'platform': 'windows',
        'total_kb': totalKb,
        'free_kb': freeKb,
        'used_kb': usedKb,
        'used_pct': totalKb > 0 ? (usedKb / totalKb * 100) : 0.0,
      };
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }
}
