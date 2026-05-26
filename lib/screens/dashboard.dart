import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupTimer();
  }

  void _setupTimer() {
    _refreshTimer?.cancel();
    final interval = ref.read(settingsProvider).refreshIntervalSeconds;
    _refreshTimer =
        Timer.periodic(Duration(seconds: interval), (_) => _loadMetrics());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final data = await ApiService.getCurrentMetrics();
      if (mounted) {
        setState(() {
          _metrics = data;
          _loading = false;
          _error = data['error'] as String?;
        });
      }
    } catch (e) {
      log('Exception caught', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild timer if interval changed
    ref.listen<AppSettings>(settingsProvider, (oldVal, newVal) {
      if (oldVal?.refreshIntervalSeconds != newVal.refreshIntervalSeconds) {
        _setupTimer();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshTimer?.cancel();
              _loadMetrics();
              _setupTimer();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _metrics == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _metrics == null
              ? _buildError()
              : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Cannot connect to Monitro backend',
            style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start the collector: ./backend/bin/monitro_collector --config config/monitro.yaml',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(_error ?? '',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final system = _metrics?['system'] as Map?;
    final cpu = _metrics?['cpu'] as Map?;
    final memory = _metrics?['memory'] as Map?;
    final netstat = _metrics?['netstat'] as Map?;

    final settings = ref.watch(settingsProvider);

    // Build the grid items dynamically based on settings
    final List<Widget> cards = [];

    // CPU Cards
    if (settings.showPerCoreCpu && cpu?['cores'] != null) {
      final cores = cpu!['cores'] as List;
      for (int i = 0; i < cores.length; i++) {
        final corePct = cores[i]['busy_pct'];
        cards.add(_MetricCard(
          title: 'CPU Core $i',
          icon: Icons.memory,
          value: '${((corePct ?? 0.0) as num).toStringAsFixed(1)}%',
          subtitle: 'utilization',
          color: _pctColor(corePct),
        ));
      }
    } else {
      cards.add(_MetricCard(
        title: 'CPU',
        icon: Icons.memory,
        value: '${((cpu?['busy_pct'] ?? 0.0) as num).toStringAsFixed(1)}%',
        subtitle: 'utilization',
        color: _pctColor(cpu?['busy_pct']),
      ));
    }

    // Memory
    cards.add(_MetricCard(
      title: 'Memory',
      value: '${((memory?['used_pct'] ?? 0.0) as num).toStringAsFixed(1)}%',
      icon: Icons.storage,
      subtitle: 'used',
      color: _pctColor(memory?['used_pct']),
    ));

    // Load
    cards.add(_MetricCard(
      title: 'Load 1m',
      value: '${system?['load_1'] ?? '?'}',
      icon: Icons.show_chart,
      subtitle:
          '5m: ${system?['load_5'] ?? '?'}  15m: ${system?['load_15'] ?? '?'}',
      color: AppTheme.accent,
    ));

    // Network Interface filtering
    final interfaces = netstat?['interfaces'] as Map? ?? {};
    if (settings.selectedNetworkInterface == 'All') {
      cards.add(_MetricCard(
        title: 'Connections',
        value: '${netstat?['summary']?['ESTABLISHED'] ?? 0}',
        icon: Icons.cable,
        subtitle: 'established (All)',
        color: AppTheme.success,
      ));
    } else {
      final ifaceData = interfaces[settings.selectedNetworkInterface] as Map?;
      final bytesIn = ifaceData?['bytes_recv'] ?? 0;
      final bytesOut = ifaceData?['bytes_sent'] ?? 0;
      cards.add(_MetricCard(
        title: 'Network (${settings.selectedNetworkInterface})',
        value: '${(bytesIn / 1024 / 1024).toStringAsFixed(1)} MB',
        icon: Icons.wifi,
        subtitle: 'recv (total)',
        color: AppTheme.accent,
      ));
      cards.add(_MetricCard(
        title: 'Network (${settings.selectedNetworkInterface})',
        value: '${(bytesOut / 1024 / 1024).toStringAsFixed(1)} MB',
        icon: Icons.wifi,
        subtitle: 'sent (total)',
        color: AppTheme.accent,
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (system != null) _buildSystemHeader(system),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 1200
                ? 5
                : constraints.maxWidth > 800
                    ? 4
                    : constraints.maxWidth > 500
                        ? 2
                        : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: cards,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSystemHeader(Map system) {
    return Row(children: [
      const Icon(Icons.computer, color: AppTheme.accent, size: 20),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          system['hostname'] ?? 'Unknown',
          style: const TextStyle(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          system['os_version'] ?? '',
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          'Up ${system['uptime_days']}d  |  ${system['load_1']}',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
    ]);
  }

  Color _pctColor(dynamic val) {
    final pct = (val as num?)?.toDouble() ?? 0;
    if (pct >= 90) return AppTheme.danger;
    if (pct >= 70) return AppTheme.warning;
    return AppTheme.success;
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style:
                          const TextStyle(fontSize: 13, color: AppTheme.muted),
                      overflow: TextOverflow.ellipsis)),
            ]),
            Text(value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
