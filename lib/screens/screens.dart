// Processes Screen
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ProcessesScreen extends StatelessWidget {
  const ProcessesScreen({super.key});
  @override Widget build(BuildContext context) =>
    _DataScreen(title: 'Top Processes', loader: ApiService.getProcesses,
      builder: (data) => _ProcessTable(processes: (data['processes'] as List? ?? [])));
}

class _ProcessTable extends StatelessWidget {
  final List processes;
  const _ProcessTable({required this.processes});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
        dataTextStyle: const TextStyle(color: AppTheme.onSurface, fontSize: 12),
        columns: const [
          DataColumn(label: Text('PID')),
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('USER')),
          DataColumn(label: Text('CPU %')),
          DataColumn(label: Text('MEM %')),
          DataColumn(label: Text('RSS KB')),
          DataColumn(label: Text('STATE')),
        ],
        rows: processes.map<DataRow>((p) {
          final cpuPct = (p['cpu_pct'] as num?)?.toDouble() ?? 0;
          return DataRow(cells: [
            DataCell(Text('${p['pid'] ?? ''}')),
            DataCell(Text(
              (p['cmdline'] as String? ?? '').split('/').last.split(' ').first.take(30),
            )),
            DataCell(Text('${p['user'] ?? ''}')),
            DataCell(Text(
              cpuPct.toStringAsFixed(1),
              style: TextStyle(color: cpuPct >= 50 ? AppTheme.danger : AppTheme.onSurface),
            )),
            DataCell(Text('${((p['mem_pct'] as num?)?.toStringAsFixed(1)) ?? ''}')),
            DataCell(Text('${p['rss_kb'] ?? ''}')),
            DataCell(Text('${p['state'] ?? ''}')),
          ]);
        }).toList(),
      ),
    );
  }
}

// Connections Screen
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});
  @override Widget build(BuildContext context) =>
    _DataScreen(title: 'Network Connections', loader: ApiService.getConnections,
      builder: (data) => _ConnectionSummary(data: data));
}

class _ConnectionSummary extends StatelessWidget {
  final Map data;
  const _ConnectionSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map? ?? {};
    return ListView(children: [
      ...summary.entries.map((e) => ListTile(
        leading: Icon(Icons.circle, size: 8, color: e.key == 'ESTABLISHED' ? AppTheme.success : AppTheme.muted),
        title: Text('${e.key}', style: const TextStyle(color: AppTheme.onSurface)),
        trailing: Text('${e.value}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
      )),
    ]);
  }
}

// Users Screen
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});
  @override Widget build(BuildContext context) =>
    _DataScreen(title: 'User Sessions', loader: ApiService.getUsers,
      builder: (data) => _UserList(sessions: (data['sessions'] as List? ?? [])));
}

class _UserList extends StatelessWidget {
  final List sessions;
  const _UserList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(child: Text('No active sessions', style: TextStyle(color: AppTheme.muted)));
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (ctx, i) {
        final s = sessions[i] as Map;
        return ListTile(
          leading: Icon(Icons.person, color: AppTheme.accent),
          title: Text('${s['username']}', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text('${s['tty']} · from ${s['from_host']} · idle ${s['idle']}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          trailing: Text(s['current_cmd'] as String? ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        );
      },
    );
  }
}

// API Monitor Screen
class ApiMonitorScreen extends StatelessWidget {
  const ApiMonitorScreen({super.key});
  @override Widget build(BuildContext context) =>
    _DataScreen(title: 'API Call Monitor', loader: ApiService.getApiCalls,
      builder: (data) => _ApiCallerList(callers: (data['api_callers'] as List? ?? [])));
}

class _ApiCallerList extends StatelessWidget {
  final List callers;
  const _ApiCallerList({required this.callers});

  @override
  Widget build(BuildContext context) {
    if (callers.isEmpty) {
      return Center(child: Text('No outbound HTTP connections detected', style: TextStyle(color: AppTheme.muted)));
    }
    return ListView.builder(
      itemCount: callers.length,
      itemBuilder: (ctx, i) {
        final c = callers[i] as Map;
        final count = (c['connections'] as int?) ?? 0;
        return ListTile(
          leading: Icon(Icons.api, color: count > 10 ? AppTheme.danger : AppTheme.accent),
          title: Text('${c['process']}', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          trailing: Chip(
            label: Text('$count connections', style: TextStyle(color: count > 10 ? AppTheme.danger : AppTheme.accent, fontSize: 12)),
            backgroundColor: AppTheme.surfaceAlt,
          ),
        );
      },
    );
  }
}

// Alerts Screen
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override Widget build(BuildContext context) =>
    _DataScreen(title: 'Alert Events', loader: ApiService.getAlerts,
      builder: (data) => _AlertList(alerts: (data['alerts'] as List? ?? [])));
}

class _AlertList extends StatelessWidget {
  final List alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, color: AppTheme.success, size: 48),
        const SizedBox(height: 12),
        Text('No alerts — all systems nominal', style: TextStyle(color: AppTheme.muted)),
      ]));
    }
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (ctx, i) {
        final a = alerts[i] as Map;
        final severity = a['severity'] as String? ?? 'info';
        final color = severity == 'critical' ? AppTheme.danger
                    : severity == 'warning'  ? AppTheme.warning
                    : AppTheme.accent;
        return ListTile(
          leading: Icon(Icons.warning_amber, color: color),
          title: Text('${a['metric_name']}', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text('${a['message']}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          trailing: Text('${a['triggered_at']}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        );
      },
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _SectionHeader('Backend Connection'),
        _SettingTile(label: 'API Host',     value: '127.0.0.1'),
        _SettingTile(label: 'API Port',     value: '8443'),
        _SettingTile(label: 'SSL',          value: 'Enabled (local CA)'),
        const Divider(height: 32),
        _SectionHeader('Database'),
        _SettingTile(label: 'Host',    value: '127.0.0.1:3306'),
        _SettingTile(label: 'Name',    value: 'monitro'),
        _SettingTile(label: 'User',    value: 'monitro_user'),
        const Divider(height: 32),
        _SectionHeader('Collection'),
        _SettingTile(label: 'Interval',     value: '5 seconds'),
        _SettingTile(label: 'Retention',    value: '30 days'),
        const Divider(height: 32),
        _SectionHeader('About'),
        _SettingTile(label: 'Version',      value: '0.1.0'),
        _SettingTile(label: 'Repository',   value: 'github.com/TaliskerMan/Monitro'),
        const SizedBox(height: 16),
        Text('Edit config/monitro.yaml to change settings and restart the backend.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
  );
}

class _SettingTile extends StatelessWidget {
  final String label, value;
  const _SettingTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 160, child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13))),
      Text(value, style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Generic data-loading screen wrapper
// ---------------------------------------------------------------------------
class _DataScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, dynamic>> Function() loader;
  final Widget Function(Map<String, dynamic>) builder;

  const _DataScreen({required this.title, required this.loader, required this.builder});

  @override
  State<_DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<_DataScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      await _load();
      return mounted;
    });
  }

  Future<void> _load() async {
    final data = await widget.loader();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.surface,
    appBar: AppBar(title: Text(widget.title),
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : _data == null ? const Center(child: Text('No data'))
        : widget.builder(_data!),
  );
}

extension _StringTake on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
