import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class BackendService {
  static Process? _process;

  static Future<bool> start(String configPath) async {
    await _killExistingProcess();
    if (_process != null) return true; // Already running

    String exePath = _getCollectorPath();

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
    } catch (e) {
      debugPrint('Failed to start collector: $e');
      return false;
    }
  }

  static Future<void> _killExistingProcess() async {
    try {
      if (Platform.isWindows) {
        await Process.run('powershell', ['-Command', 'Stop-Process -Name monitro_collector -Force -ErrorAction SilentlyContinue']);
        await Process.run('powershell', ['-Command', 'Stop-Process -Name monitro_collector.exe -Force -ErrorAction SilentlyContinue']);
      } else {
        await Process.run('pkill', ['-f', 'monitro_collector']);
      }
      debugPrint('Cleaned up any existing backend collector processes.');
    } catch (e) {
      debugPrint('Failed to clean up old processes: $e');
    }
  }

  static void stop() {
    if (_process != null) {
      _process!.kill();
      _process = null;
      debugPrint('Stopped backend collector.');
    }
  }

  static String _getCollectorPath() {
    final exeLoc = Platform.resolvedExecutable;
    debugPrint('App Executable: $exeLoc');

    // On macOS packaged app, it is Contents/MacOS/monitro
    // Resource dir is Contents/MacOS/monitro_collector (Required for Sandbox execution)
    if (Platform.isMacOS && exeLoc.contains('.app/Contents/MacOS/')) {
      final appDir = File(exeLoc).parent.parent.path;
      return p.join(appDir, 'MacOS', 'monitro_collector');
    }
    
    // On Windows, it is Monitro\monitro.exe
    // Resource dir is Monitro\backend\monitro_collector.exe
    if (Platform.isWindows && p.basename(exeLoc).toLowerCase() == 'monitro.exe') {
      final appDir = File(exeLoc).parent.path;
      return p.join(appDir, 'backend', 'monitro_collector.exe');
    }

    // Fallback for running locally from source 'flutter run'
    if (Platform.isWindows) {
      return p.join(Directory.current.path, 'backend', 'monitro_collector.exe');
    }
    return p.join(Directory.current.path, 'backend', 'monitro_collector');
  }
}
