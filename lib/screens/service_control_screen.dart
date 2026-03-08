import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ServiceControlScreen extends StatefulWidget {
  const ServiceControlScreen({super.key});

  @override
  State<ServiceControlScreen> createState() => _ServiceControlScreenState();
}

class _ServiceControlScreenState extends State<ServiceControlScreen> {
  bool _isServiceOn = false;
  bool _isLoading = true;
  String _logContent = '';

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      // Read the last 50 lines from the persistent log file
      final result = await Process.run('tail', ['-n', '50', '/var/log/monitro-collector.log']);
      if (mounted) {
        setState(() {
          _logContent = result.stdout.toString().trim();
          if (_logContent.isEmpty) {
            _logContent = '(No log entries yet)';
          }
        });
      }
    } catch (e) {
      // Fall back to journalctl if the log file doesn't exist yet
      try {
        final result = await Process.run('journalctl', ['-u', 'monitro-collector.service', '--no-pager', '-n', '50', '--output=short']);
        if (mounted) {
          setState(() {
            _logContent = result.stdout.toString().trim();
            if (_logContent.isEmpty) {
              _logContent = '(No log entries yet)';
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _logContent = '(Unable to read logs)';
          });
        }
      }
    }
  }

  Future<void> _checkServiceStatus() async {
    try {
      final result = await Process.run('systemctl', ['is-active', 'monitro-collector.service']);
      if (mounted) {
        setState(() {
          _isServiceOn = result.stdout.toString().trim() == 'active';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServiceOn = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleService(bool turnOn) async {
    // Pre-check: is the service already in the desired state?
    final preCheck = await Process.run('/usr/bin/systemctl', ['is-active', 'monitro-collector.service']);
    final alreadyActive = preCheck.stdout.toString().trim() == 'active';

    if (turnOn && alreadyActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collector service is already running.'), backgroundColor: AppTheme.success),
        );
      }
      return;
    }
    if (!turnOn && !alreadyActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collector service is already stopped.'), backgroundColor: AppTheme.muted),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      ProcessResult result;

      if (turnOn) {
        result = await Process.run('pkexec', [
          '/usr/bin/bash', '-c',
          '/usr/bin/systemctl reset-failed monitro-collector.service 2>/dev/null; /usr/bin/systemctl start monitro-collector.service',
        ]);
      } else {
        result = await Process.run('pkexec', [
          '/usr/bin/systemctl', 'stop', 'monitro-collector.service',
        ]);
      }

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${stderr.isNotEmpty ? stderr : "Authentication cancelled or error occurred."}'),
              backgroundColor: AppTheme.danger,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        final checkResult = await Process.run('/usr/bin/systemctl', ['is-active', 'monitro-collector.service']);
        final isActive = checkResult.stdout.toString().trim() == 'active';

        setState(() {
          _isServiceOn = isActive;
          _isLoading = false;
        });

        Process.run('canberra-gtk-play', ['-i', 'button-pressed']);

        // Refresh the log viewer
        _loadLog();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Backend Service Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh log',
            onPressed: () {
              _checkServiceStatus();
              _loadLog();
            },
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            // ── Service toggle section ──
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    _isServiceOn ? Icons.cloud_done : Icons.cloud_off,
                    size: 64,
                    color: _isServiceOn ? AppTheme.success : AppTheme.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isServiceOn ? 'Collector service is ON' : 'Collector service is OFF',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _isServiceOn ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('OFF', style: TextStyle(color: AppTheme.danger, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Transform.scale(
                        scale: 1.5,
                        child: Switch(
                          value: _isServiceOn,
                          activeTrackColor: AppTheme.success,
                          inactiveThumbColor: AppTheme.danger,
                          inactiveTrackColor: AppTheme.surfaceAlt,
                          onChanged: (value) => _toggleService(value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('ON', style: TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toggling requires admin privileges. You will be prompted for your password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.surfaceAlt),
            // ── Log viewer section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Service Log', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Text(
                    '/var/log/monitro-collector.log',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceAlt, width: 1),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    _logContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFC9D1D9),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
