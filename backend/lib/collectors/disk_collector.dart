// Disk I/O Collector — cross-platform
import 'dart:developer';
import 'dart:io';

class DiskCollector {
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  /// Linux: parse /proc/diskstats
  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final content = await File('/proc/diskstats').readAsString();
      final devices = <Map<String, dynamic>>[];
      for (final line in content.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 14) continue;
        final name = parts[2];
        // Skip partition entries (sda1, sdb2, etc.) — keep major devices
        if (RegExp(r'\d$').hasMatch(name) && !name.startsWith('nvme')) continue;
        devices.add({
          'device':      name,
          'reads':       int.tryParse(parts[3]) ?? 0,
          'reads_merged': int.tryParse(parts[4]) ?? 0,
          'sectors_read': int.tryParse(parts[5]) ?? 0,
          'read_ms':     int.tryParse(parts[6]) ?? 0,
          'writes':      int.tryParse(parts[7]) ?? 0,
          'sectors_written': int.tryParse(parts[9]) ?? 0,
          'write_ms':    int.tryParse(parts[10]) ?? 0,
        });
      }
      return {'platform': 'linux', 'devices': devices};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }

  /// macOS: use iostat -d -c 1
  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      final result = await Process.run('iostat', ['-d', '-c', '1'], runInShell: true);
      final lines = result.stdout.toString().split('\n');
      final devices = <Map<String, dynamic>>[];
      // iostat output: "          disk0"
      // lines[0]: header with device names
      // lines[1]: "      KB/t  tps  MB/s"
      // lines[2]: values
      if (lines.length >= 3) {
        final devNames = lines[0].trim().split(RegExp(r'\s+'));
        final values = lines[2].trim().split(RegExp(r'\s+'));
        // 3 values per device: KB/t, tps, MB/s
        for (int i = 0; i < devNames.length && i * 3 + 2 < values.length; i++) {
          devices.add({
            'device': devNames[i],
            'kb_per_transfer': double.tryParse(values[i * 3]) ?? 0,
            'transfers_per_sec': double.tryParse(values[i * 3 + 1]) ?? 0,
            'mb_per_sec': double.tryParse(values[i * 3 + 2]) ?? 0,
          });
        }
      }
      return {'platform': 'macos', 'devices': devices};
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
          'Get-PhysicalDisk | Select-Object FriendlyName, MediaType | ConvertTo-Json',
        ],
      );
      return {'platform': 'windows', 'raw': result.stdout.toString()};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }
}
