// Dashboard Screen — Main observability overview
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    // Refresh every 5 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      await _loadMetrics();
      return mounted;
    });
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
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
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
          Icon(Icons.error_outline, color: AppTheme.danger, size: 64),
          const SizedBox(height: 16),
          Text(
            'Cannot connect to Monitro backend',
            style: TextStyle(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the collector: ./backend/bin/monitro_collector --config config/monitro.yaml',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(_error ?? '', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final system  = _metrics?['system']  as Map?;
    final cpu     = _metrics?['cpu']     as Map?;
    final memory  = _metrics?['memory']  as Map?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System info row
          if (system != null) _buildSystemHeader(system),
          const SizedBox(height: 20),

          // Metric cards grid
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 1200 ? 4
                       : constraints.maxWidth > 800  ? 3
                       : constraints.maxWidth > 500  ? 2
                       : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _MetricCard(
                  title: 'CPU',
                  icon: Icons.memory,
                  value: '${((cpu?['busy_pct'] ?? 0.0) as num).toStringAsFixed(1)}%',
                  subtitle: 'utilization',
                  color: _pctColor(cpu?['busy_pct']),
                ),
                _MetricCard(
                  title: 'Memory',
                  value: '${((memory?['used_pct'] ?? 0.0) as num).toStringAsFixed(1)}%',
                  icon: Icons.storage,
                  subtitle: 'used',
                  color: _pctColor(memory?['used_pct']),
                ),
                _MetricCard(
                  title: 'Load 1m',
                  value: '${system?['load_1'] ?? '?'}',
                  icon: Icons.show_chart,
                  subtitle: '5m: ${system?['load_5'] ?? '?'}  15m: ${system?['load_15'] ?? '?'}',
                  color: AppTheme.accent,
                ),
                _MetricCard(
                  title: 'Connections',
                  value: '${(_metrics?['netstat'] as Map?)?['summary']?['ESTABLISHED'] ?? 0}',
                  icon: Icons.cable,
                  subtitle: 'established',
                  color: AppTheme.success,
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text('More detailed panels coming as Flutter + backend are wired up.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSystemHeader(Map system) {
    return Row(children: [
      Icon(Icons.computer, color: AppTheme.accent, size: 20),
      const SizedBox(width: 8),
      Text(system['hostname'] ?? 'Unknown', style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(width: 16),
      Text(system['os_version'] ?? '', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      const Spacer(),
      Text('Uptime: ${system['uptime'] ?? ''}', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
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
              Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ]),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}
