// User Session Collector — cross-platform
import 'dart:developer';
import 'dart:io';

class UserCollector {
  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isWindows) return _collectWindows();
    return _collectPosix();
  }

  /// POSIX (macOS + Linux): use 'w' command for detailed session info
  static Future<Map<String, dynamic>> _collectPosix() async {
    try {
      final result = await Process.run('w', ['-h'], runInShell: true);
      final sessions = <Map<String, dynamic>>[];
      for (final line in result.stdout.toString().split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 5) continue;
        sessions.add({
          'username':    parts[0],
          'tty':         parts[1],
          'from_host':   parts[2],
          'login_time':  parts[3],
          'idle':        parts[4],
          'cpu_time':    parts.length > 5 ? parts[5] : '',
          'current_cmd': parts.length > 6 ? parts.sublist(6).join(' ') : '',
        });
      }
      return {
        'platform': Platform.operatingSystem,
        'sessions': sessions,
        'count':    sessions.length,
      };
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'query', ['user'], runInShell: true,
      );
      // quser output is space-delimited, skip header
      final lines = result.stdout.toString().split('\n').skip(1);
      final sessions = <Map<String, dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.trim().split(RegExp(r'\s{2,}'));
        if (parts.isEmpty) continue;
        sessions.add({'raw': line.trim()});
      }
      return {'platform': 'windows', 'sessions': sessions, 'count': sessions.length};
    } catch (e) {
      log('Exception caught', error: e);
      return {'error': e.toString()};
    }
  }
}
