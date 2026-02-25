// Netstat Collector — active TCP/UDP connections, cross-platform
import 'dart:io';

class NetstatCollector {
  // Simple cache for resolved IPs
  static final Map<String, String> _dnsCache = {};

  static Future<Map<String, dynamic>> collect() async {
    if (Platform.isLinux) return _collectLinux();
    if (Platform.isMacOS) return _collectMacOS();
    if (Platform.isWindows) return _collectWindows();
    return {'error': 'Unsupported platform'};
  }

  /// Linux: use 'ss -tnup' (socket statistics) -> users:(("process",pid=...,fd=...))
  static Future<Map<String, dynamic>> _collectLinux() async {
    try {
      final result = await Process.run(
        'ss', ['-tnup', '--no-header'], runInShell: true,
      );
      final connections = _parseSSOutput(result.stdout.toString());
      await _enrichWithDomains(connections);
      final summary = _summarize(connections);
      return {'platform': 'linux', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// macOS: use 'lsof -i -n -P' for detailed process + connection mappings
  static Future<Map<String, dynamic>> _collectMacOS() async {
    try {
      final result = await Process.run(
        'lsof', ['-i', '-n', '-P'], runInShell: true,
      );
      final connections = _parseLsofOutput(result.stdout.toString());
      await _enrichWithDomains(connections);
      final summary = _summarize(connections);
      return {'platform': 'macos', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _collectWindows() async {
    try {
      final result = await Process.run(
        'netstat', ['-ano'], runInShell: true,
      );
      final connections = _parseWindowsNetstat(result.stdout.toString());
      await _enrichWithDomains(connections);
      final summary = _summarize(connections);
      return {'platform': 'windows', 'connections': connections, 'summary': summary};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // Domain Enrichment
  // ---------------------------------------------------------------------------
  
  static Future<void> _enrichWithDomains(List<Map<String, dynamic>> connections) async {
    // Resolve domains concurrently for efficiency
    await Future.wait(connections.map((c) async {
      String remoteIp = '';
      final remote = c['remote'] as String;
      
      // Extract IP from address string
      if (remote.isNotEmpty && remote != '*') {
        if (remote.contains('->')) {
           // lsof format IP->IP:PORT
           final remPart = remote.split('->').last;
           remoteIp = remPart.substring(0, remPart.lastIndexOf(':'));
        } else {
           final lastColon = remote.lastIndexOf(':');
           if (lastColon > 0) {
             remoteIp = remote.substring(0, lastColon);
             if (remoteIp.startsWith('[') && remoteIp.endsWith(']')) {
               remoteIp = remoteIp.substring(1, remoteIp.length - 1);
             }
           }
        }
      }

      if (remoteIp.isEmpty || remoteIp == '*' || remoteIp == '0.0.0.0' || remoteIp == '127.0.0.1' || remoteIp == '::' || remoteIp == '::1') {
        c['remote_domain'] = '';
        return;
      }

      if (_dnsCache.containsKey(remoteIp)) {
        c['remote_domain'] = _dnsCache[remoteIp];
        return;
      }

      try {
        final addrs = await InternetAddress.lookup(remoteIp).timeout(const Duration(milliseconds: 150));
        if (addrs.isNotEmpty && addrs.first.host != remoteIp) {
          _dnsCache[remoteIp] = addrs.first.host;
          c['remote_domain'] = addrs.first.host;
        } else {
          _dnsCache[remoteIp] = '';
          c['remote_domain'] = '';
        }
      } catch (_) {
        _dnsCache[remoteIp] = '';
        c['remote_domain'] = '';
      }
    }));
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseSSOutput(String output) {
    final connections = <Map<String, dynamic>>[];
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      
      String process = '';
      int? pid;
      
      // Try to extract process from users:(("process",pid=...,fd=...))
      for (final p in parts) {
        if (p.startsWith('users:((')) {
          final pMatch = RegExp(r'"([^"]+)"').firstMatch(p);
          if (pMatch != null) process = pMatch.group(1) ?? '';
          
          final pidMatch = RegExp(r'pid=(\d+)').firstMatch(p);
          if (pidMatch != null) pid = int.tryParse(pidMatch.group(1) ?? '');
        }
      }

      connections.add({
        'protocol': parts[0].toLowerCase(),
        'state':    parts[1],
        'local':    parts[4],
        'remote':   parts.length > 5 ? parts[5] : '',
        'process':  process,
        'pid':      pid,
      });
    }
    return connections;
  }

  static List<Map<String, dynamic>> _parseLsofOutput(String output) {
    final connections = <Map<String, dynamic>>[];
    // Skip header line
    final lines = output.split('\n').skip(1);
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Split preserving some format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 9) continue;

      final processName = parts[0];
      final pid = int.tryParse(parts[1]);
      final protocol = parts[7].toLowerCase(); // TCP or UDP
      
      String local = '';
      String remote = '';
      String state = '';

      final namePart = parts.sublist(8).join(' '); // Could be *:49152 (LISTEN) or 10.0.0.2:123->1.2.3.4:443 (ESTABLISHED)
      
      // Extract state
      final stateMatch = RegExp(r'\(([^)]+)\)$').firstMatch(namePart);
      if (stateMatch != null) {
        state = stateMatch.group(1) ?? '';
      } else {
        if (protocol == 'udp') state = 'UDP';
      }

      // Clean name
      String addressStr = namePart.replaceAll(RegExp(r'\s*\([^)]+\)$'), '').trim();
      
      if (addressStr.contains('->')) {
        final pair = addressStr.split('->');
        local = pair[0];
        remote = pair[1];
      } else {
        local = addressStr;
        remote = '*';
      }

      if (state.isEmpty) state = 'UNKNOWN';

      connections.add({
        'protocol': protocol,
        'local':    local,
        'remote':   remote,
        'process':  processName,
        'pid':      pid,
        'state':    state,
      });
    }
    return connections;
  }

  static List<Map<String, dynamic>> _parseWindowsNetstat(String output) {
    final connections = <Map<String, dynamic>>[];
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      if (parts[0] != 'TCP' && parts[0] != 'UDP') continue;
      
      String process = '';
      int? pid;
      
      // On Windows netstat -ano, PID is the last column (Column 4 for UDP, 5 for TCP)
      if (parts[0] == 'TCP' && parts.length >= 5) {
        pid = int.tryParse(parts[4]);
      } else if (parts[0] == 'UDP' && parts.length >= 4) {
        pid = int.tryParse(parts[3]);
      }
      
      connections.add({
        'protocol': parts[0].toLowerCase(),
        'local':    parts[1],
        'remote':   parts[2],
        'state':    parts[0] == 'TCP' ? parts[3] : 'UDP',
        'process':  process,
        'pid':      pid,
      });
    }
    return connections;
  }

  static Map<String, int> _summarize(List<Map<String, dynamic>> connections) {
    final summary = <String, int>{};
    for (final conn in connections) {
      final state = (conn['state'] as String? ?? 'UNKNOWN').toUpperCase();
      summary[state] = (summary[state] ?? 0) + 1;
    }
    return summary;
  }
}
