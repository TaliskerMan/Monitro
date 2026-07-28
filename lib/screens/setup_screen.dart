import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monitro/services/api_service.dart';
import 'package:monitro/services/backend_service.dart';
import 'package:monitro/services/config_generator.dart';
import 'package:monitro/services/preferences_service.dart';
import 'package:monitro/theme/app_theme.dart';

/// Screen widget hosting the initial setup credentials wizard.
///
/// Prompts users to configure host addresses, port binds, username, database names,
/// and credentials targeting the MariaDB storage.
class SetupScreen extends ConsumerStatefulWidget {
  /// Creates a [SetupScreen] instance.
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _host = TextEditingController(text: '127.0.0.1');
  final _port = TextEditingController(text: '3306');
  final _user = TextEditingController(text: 'monitro_user');
  final _pass = TextEditingController();
  final _db = TextEditingController(text: 'monitro');

  bool _testing = false;
  String? _error;
  bool _obscurePass = true; // State for password visibility toggle

  /// Test connection parameters by writing a temporary config file and starting the backend.
  Future<void> _testAndSave() async {
    setState(() {
      _testing = true;
      _error = null;
    });

    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 3306;
    final user = _user.text.trim();
    final pass = _pass.text;
    final db = _db.text.trim();

    // Temporarily save to generate config
    ref.read(settingsProvider.notifier).setDatabaseConfig(
          host: host,
          port: port,
          user: user,
          pass: pass,
          db: db,
        );
    final settings = ref.read(settingsProvider);

    // Generate configuration file
    final configPath = await ConfigGenerator.generateConfig(settings);

    // Start background collector process
    await BackendService.start(configPath);

    // Wait for the backend to spin up and connect to MariaDB
    await Future.delayed(const Duration(seconds: 3));

    // Test API health
    try {
      final metrics = await ApiService.getCurrentMetrics();
      if (metrics.containsKey('error')) {
        setState(() => _error = metrics['error'].toString());
      } else {
        // Success
        if (mounted) context.go('/');
      }
    } catch (error) {
      log('Exception caught', error: error);
      setState(() => _error =
          'Cannot connect to backend or database. Ensure MariaDB is running and credentials are correct.');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Ensure clicking anywhere but a text field drops focus (and the Secure Input lock on macOS)
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.monitor_heart,
                    color: AppTheme.accent, size: 48),
                const SizedBox(height: 16),
                const Text('Monitro Setup',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your MariaDB credentials. The collector requires a database to store historical metrics.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                    controller: _host,
                    decoration: const InputDecoration(
                        labelText: 'Host (IP)', border: OutlineInputBorder()),
                    style: const TextStyle(color: AppTheme.onSurface)),
                const SizedBox(height: 12),
                TextField(
                    controller: _port,
                    decoration: const InputDecoration(
                        labelText: 'Port', border: OutlineInputBorder()),
                    style: const TextStyle(color: AppTheme.onSurface)),
                const SizedBox(height: 12),
                TextField(
                    controller: _user,
                    decoration: const InputDecoration(
                        labelText: 'Username', border: OutlineInputBorder()),
                    style: const TextStyle(color: AppTheme.onSurface)),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppTheme.muted),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                      tooltip: 'Toggle visibility to release secure input lock',
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.onSurface),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _db,
                    decoration: const InputDecoration(
                        labelText: 'Database Name',
                        border: OutlineInputBorder()),
                    style: const TextStyle(color: AppTheme.onSurface)),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 13)),
                  ),
                ElevatedButton(
                  onPressed: _testing ? null : _testAndSave,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(20)),
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Connect & Start',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
