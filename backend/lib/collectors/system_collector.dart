// System info collector — hostname, uptime, load average
import 'dart:developer';
import 'dart:io';

class SystemCollector {
  static Future<Map<String, dynamic>> collect() async {
    final hostname = Platform.localHostname;
    final os = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;

    double? load1, load5, load15;
    String? uptimeStr;

    if (Platform.isLinux || Platform.isMacOS) {
      // Load averages from uptime command
      try {
        final result = await Process.run('uptime', [], runInShell: true);
        final output = result.stdout.toString();
        // Matches "load averages: 0.52 0.48 0.40" (macOS) or "load average: 0.52, 0.48, 0.40" (Linux)
        final m = RegExp(r'load averages?:\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)')
            .firstMatch(output);
        if (m != null) {
          load1  = double.tryParse(m.group(1)!);
          load5  = double.tryParse(m.group(2)!);
          load15 = double.tryParse(m.group(3)!);
        }
        uptimeStr = output.trim();
      } catch (_) {
      log('Exception caught', error: _);}
    }

    if (Platform.isWindows) {
      // No native uptime command; use WMI LastBootUpTime
      try {
        final result = await Process.run(
          'powershell', [
            '-NonInteractive', '-Command',
            r'(Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime | Select-Object -ExpandProperty TotalSeconds',
          ],
        );
        final seconds = double.tryParse(result.stdout.toString().trim());
        if (seconds != null) {
          final dur = Duration(seconds: seconds.toInt());
          uptimeStr = '${dur.inDays}d ${dur.inHours % 24}h ${dur.inMinutes % 60}m';
        }
      } catch (_) {
      log('Exception caught', error: _);}
    }

    return {
      'hostname':   hostname,
      'os':         os,
      'os_version': osVersion,
      'load_1':     load1,
      'load_5':     load5,
      'load_15':    load15,
      'uptime':     uptimeStr,
    };
  }
}
