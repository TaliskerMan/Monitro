import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:monitro/services/api_service.dart';
import 'package:path/path.dart' as p;

/// Control service managing the lifecycle of the local Monitro daemon collector.
///
/// Starts, monitors, and stops the `monitro_collector` subprocess, piping its stdout/stderr
/// logs to local files, and handles windows/unix process cleanup signals.
class BackendService {
  static Process? _process;

  /// Boot the backend daemon collector if not already running.
  ///
  /// Checks local API health first. If not listening, kills any zombie processes and spawns
  /// the system-specific collector executable, passing the config YAML path arguments.
  ///
  /// Args:
  ///   configPath: Path to the generated YAML configuration file.
  static Future<bool> start(String configPath) async {
    if (_process != null) {
      return true; // Already running locally mapped by Flutter
    }

    // Check if another backend instance is already listening
    if (await ApiService.isBackendHealthy()) {
      debugPrint('Backend is already running and healthy.');
      return true;
    }

    await _killExistingProcess();

    final exePath = _getCollectorPath();

    if (!File(exePath).existsSync()) {
      debugPrint('Collector binary not found at $exePath');
      // On Linux or during dev, it might be running already, so returning true lets the app continue
      return true;
    }

    try {
      debugPrint('Starting collector at $exePath with config $configPath');
      final logFile = File(p.join(File(configPath).parent.path, 'out.txt'));
      if (logFile.existsSync()) logFile.deleteSync();

      _process = await Process.start(exePath, ['--config', configPath]);
      _process!.stdout.listen((data) {
        logFile.writeAsBytesSync(data, mode: FileMode.append);
      });
      _process!.stderr.listen((data) {
        logFile.writeAsBytesSync(data, mode: FileMode.append);
      });
      return true;
    } catch (error) {
      log('Exception caught', error: error);
      debugPrint('Failed to start collector: $error');
      return false;
    }
  }

  /// Clean up existing collector processes on the system to avoid address bind errors.
  static Future<void> _killExistingProcess() async {
    try {
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-Command',
          'Stop-Process -Name monitro_collector -Force -ErrorAction SilentlyContinue'
        ]);
        await Process.run('powershell', [
          '-Command',
          'Stop-Process -Name monitro_collector.exe -Force -ErrorAction SilentlyContinue'
        ]);
      } else {
        await Process.run('pkill', ['-f', 'monitro_collector']);
      }
      debugPrint('Cleaned up any existing backend collector processes.');
    } catch (error) {
      log('Exception caught', error: error);
      debugPrint('Failed to clean up old processes: $error');
    }
  }

  /// Stop the background daemon subprocess.
  static void stop() {
    if (_process != null) {
      _process!.kill();
      _process = null;
      debugPrint('Stopped backend collector.');
    }
  }

  /// Resolve the absolute path to the collector binary across dev runs AND
  /// installed packages. Returns the first candidate that exists, else the dev
  /// fallback. The previous Linux code only resolved `Directory.current/backend`
  /// which is wrong for an installed .deb (binary lives under /usr or /opt).
  static String _getCollectorPath() {
    final exeLoc = Platform.resolvedExecutable;
    final exeDir = File(exeLoc).parent.path;
    final bin =
        Platform.isWindows ? 'monitro_collector.exe' : 'monitro_collector';
    debugPrint('App Executable: $exeLoc');

    final candidates = <String>[
      // Explicit override.
      if (Platform.environment['MONITRO_COLLECTOR'] != null)
        Platform.environment['MONITRO_COLLECTOR']!,
    ];

    if (Platform.isMacOS && exeLoc.contains('.app/Contents/MacOS/')) {
      final appDir = File(exeLoc).parent.parent.path;
      candidates.add(p.join(appDir, 'MacOS', bin));
    }
    if (Platform.isWindows) {
      candidates.add(p.join(exeDir, 'backend', bin));
    }
    if (Platform.isLinux) {
      // Common installed layouts for a Flutter Linux .deb.
      candidates.addAll([
        p.join(exeDir, bin),
        p.join(exeDir, 'backend', bin),
        p.join(exeDir, 'lib', bin),
        '/opt/monitro/backend/$bin',
        '/usr/lib/monitro/$bin',
        '/usr/lib/monitro/backend/$bin',
      ]);
    }

    // Dev fallback (running from source via `flutter run`).
    candidates.add(p.join(Directory.current.path, 'backend', bin));

    for (final candidate in candidates) {
      if (candidate.isNotEmpty && File(candidate).existsSync()) {
        return candidate;
      }
    }
    return candidates.last; // dev fallback path (may not exist; caller handles)
  }
}
