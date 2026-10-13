// User Session Collector — cross-platform
import 'dart:developer';
import 'dart:io';

/// Collector for querying and parsing logged-in user sessions on POSIX machines (via `w`).
class UserCollector {
  /// Gathers lists of active interactive user sessions based on the host OS.
  static Future<Map<String, dynamic>> collect() async {
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
          'username': parts[0],
          'tty': parts[1],
          'from_host': parts[2],
          'login_time': parts[3],
          'idle': parts[4],
          'cpu_time': parts.length > 5 ? parts[5] : '',
          'current_cmd': parts.length > 6 ? parts.sublist(6).join(' ') : '',
        });
      }
      return {
        'platform': Platform.operatingSystem,
        'sessions': sessions,
        'count': sessions.length,
      };
    } catch (error) {
      log('Exception caught', error: error);
      return {'error': error.toString()};
    }
  }
}
