import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';

class ProcessesScreen extends StatelessWidget {
  const ProcessesScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
      title: 'Top Processes',
      loader: ApiService.getProcesses,
      builder: (data) =>
          _ProcessTable(processes: (data['processes'] as List? ?? [])));
}

class _ProcessTable extends StatefulWidget {
  final List processes;
  const _ProcessTable({required this.processes});

  @override
  State<_ProcessTable> createState() => _ProcessTableState();
}

class _ProcessTableState extends State<_ProcessTable> {
  int _sortColumnIndex = 3; // Default CPU
  bool _sortAscending = false;
  late List _sortedProcesses;

  @override
  void initState() {
    super.initState();
    _sortedProcesses = List.from(widget.processes);
    _sortData(_sortColumnIndex, _sortAscending);
  }

  @override
  void didUpdateWidget(covariant _ProcessTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sortedProcesses = List.from(widget.processes);
    _sortData(_sortColumnIndex, _sortAscending);
  }

  void _sortData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      _sortedProcesses.sort((a, b) {
        final aVal = _getSortValue(a as Map, columnIndex);
        final bVal = _getSortValue(b as Map, columnIndex);
        return ascending
            ? Comparable.compare(aVal, bVal)
            : Comparable.compare(bVal, aVal);
      });
    });
  }

  Comparable _getSortValue(Map p, int columnIndex) {
    switch (columnIndex) {
      case 0:
        return p['pid'] as int? ?? 0;
      case 1:
        return _parseName(p['cmdline'] as String? ?? '');
      case 2:
        return p['user'] as String? ?? '';
      case 3:
        return (p['cpu_pct'] as num?)?.toDouble() ?? 0.0;
      case 4:
        return (p['mem_pct'] as num?)?.toDouble() ?? 0.0;
      case 5:
        return p['rss_kb'] as int? ?? 0;
      default:
        return 0;
    }
  }

  String _parseName(String cmdline) {
    final parts = cmdline.trim().split(' ');
    if (parts.isEmpty) return 'Unknown';
    final bin = parts.first.split('/').last;
    return bin;
  }

  String _mapState(String state) {
    final s = state.toUpperCase();
    if (s.startsWith('R')) return 'RUN';
    if (s.startsWith('S') || s.startsWith('I')) return 'INACT';
    if (s.startsWith('Z')) return 'Z';
    if (s.contains('LISTEN')) {
      return 'LSTN'; // mostly for netstat, but maybe proc
    }
    return s; // fallback
  }

  Future<void> _killProcess(int pid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: const Text('Kill Process?',
            style: TextStyle(color: AppTheme.onSurface)),
        content: Text(
            'Are you sure you want to terminate $name (PID $pid)? This could destabilize the system.',
            style: const TextStyle(color: AppTheme.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kill',
                  style: TextStyle(
                      color: AppTheme.danger, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiService.killProcess(pid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['error'] ?? 'Process $pid killed.'),
          backgroundColor:
              res['error'] == null ? AppTheme.success : AppTheme.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        headingTextStyle: const TextStyle(
            color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
        dataTextStyle: const TextStyle(color: AppTheme.onSurface, fontSize: 12),
        columns: [
          DataColumn(label: const Text('PID'), onSort: _sortData),
          DataColumn(label: const Text('NAME'), onSort: _sortData),
          DataColumn(label: const Text('USER'), onSort: _sortData),
          DataColumn(
              label: const Text('CPU %'), onSort: _sortData, numeric: true),
          DataColumn(
              label: const Text('MEM %'), onSort: _sortData, numeric: true),
          DataColumn(
              label: const Text('RSS KB'), onSort: _sortData, numeric: true),
          const DataColumn(label: Text('STATE')),
          const DataColumn(label: Text('ACTION')),
        ],
        rows: _sortedProcesses.map<DataRow>((p) {
          final mappedP = p as Map;
          final pid = mappedP['pid'] as int? ?? 0;
          final cpuPct = (mappedP['cpu_pct'] as num?)?.toDouble() ?? 0;
          final name = _parseName(mappedP['cmdline'] as String? ?? '');

          return DataRow(cells: [
            DataCell(Text('$pid')),
            DataCell(Text(name.take(30),
                style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text('${mappedP['user'] ?? ''}')),
            DataCell(Text(
              cpuPct.toStringAsFixed(1),
              style: TextStyle(
                  color: cpuPct >= 50 ? AppTheme.danger : AppTheme.onSurface,
                  fontWeight:
                      cpuPct > 10 ? FontWeight.bold : FontWeight.normal),
            )),
            DataCell(
                Text(((mappedP['mem_pct'] as num?)?.toStringAsFixed(1)) ?? '')),
            DataCell(Text('${mappedP['rss_kb'] ?? ''}')),
            DataCell(Text(_mapState(mappedP['state'] as String? ?? ''),
                style: const TextStyle(color: AppTheme.muted))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 18),
                tooltip: 'Kill Process',
                onPressed: () => _killProcess(pid, name),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

// Connections Screen
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
      title: 'Network Connections',
      loader: ApiService.getConnections,
      builder: (data) => _ConnectionTables(data: data));
}

class _ConnectionTables extends StatelessWidget {
  final Map data;
  const _ConnectionTables({required this.data});

  @override
  Widget build(BuildContext context) {
    final conns = data['connections'] as List? ?? [];

    // Split into Inbound (listening/bound) and Outbound (active to external)
    final inbound = conns.where((c) {
      final state = c['state']?.toString().toUpperCase() ?? '';
      final remote = c['remote']?.toString() ?? '';
      return state == 'LISTEN' ||
          state == 'BOUND' ||
          remote == '*' ||
          remote == '0.0.0.0:*';
    }).toList();

    final outbound = conns.where((c) => !inbound.contains(c)).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.accent,
            tabs: [
              Tab(text: 'Inbound / Listening'),
              Tab(text: 'Outbound / Active'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTable(inbound, isInbound: true),
                _buildTable(outbound, isInbound: false),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTable(List connections, {required bool isInbound}) {
    if (connections.isEmpty) {
      return const Center(
          child:
              Text('No connections', style: TextStyle(color: AppTheme.muted)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
              color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
          dataTextStyle:
              const TextStyle(color: AppTheme.onSurface, fontSize: 12),
          columns: [
            if (isInbound) ...[
              const DataColumn(label: Text('PROCESS')),
              const DataColumn(label: Text('LOCAL PORT')),
              const DataColumn(label: Text('REMOTE IP')),
              const DataColumn(label: Text('REMOTE DOMAIN')),
              const DataColumn(label: Text('STATE')),
            ] else ...[
              const DataColumn(label: Text('PROCESS')),
              const DataColumn(label: Text('REMOTE DOMAIN')),
              const DataColumn(label: Text('REMOTE IP')),
              const DataColumn(label: Text('STATE')),
            ]
          ],
          rows: connections.map<DataRow>((c) {
            final process = c['process']?.toString().isNotEmpty == true
                ? c['process']
                : 'Unnamed (${c['pid'] ?? '?'})';
            final domain = c['remote_domain']?.toString() ?? '';
            final remote = c['remote']?.toString() ?? '';
            final state = c['state']?.toString() ?? '';

            if (isInbound) {
              return DataRow(cells: [
                DataCell(Text(process.toString(),
                    style: const TextStyle(
                        color: AppTheme.accent, fontWeight: FontWeight.w500))),
                DataCell(Text(c['local']?.toString() ?? '')),
                DataCell(Text(remote)),
                DataCell(Text(domain,
                    style: const TextStyle(color: AppTheme.muted))),
                DataCell(Text(state)),
              ]);
            } else {
              return DataRow(cells: [
                DataCell(Text(process.toString(),
                    style: const TextStyle(
                        color: AppTheme.accent, fontWeight: FontWeight.w500))),
                DataCell(Text(domain.isNotEmpty ? domain : '-',
                    style: const TextStyle(color: AppTheme.onSurface))),
                DataCell(Text(remote,
                    style: const TextStyle(color: AppTheme.muted))),
                DataCell(Text(state,
                    style: TextStyle(
                        color: state.toUpperCase() == 'ESTABLISHED'
                            ? AppTheme.success
                            : AppTheme.muted))),
              ]);
            }
          }).toList(),
        ),
      ),
    );
  }
}

// Users Screen
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
      title: 'User Sessions',
      loader: ApiService.getUsers,
      builder: (data) =>
          _UserList(sessions: (data['sessions'] as List? ?? [])));
}

class _UserList extends StatelessWidget {
  final List sessions;
  const _UserList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
          child: Text('No active sessions',
              style: TextStyle(color: AppTheme.muted)));
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (ctx, i) {
        final s = sessions[i] as Map;
        return ListTile(
          leading: const Icon(Icons.person, color: AppTheme.accent),
          title: Text('${s['username']}',
              style: const TextStyle(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${s['tty']} · from ${s['from_host']} · idle ${s['idle']}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          trailing: Text(s['current_cmd'] as String? ?? '',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        );
      },
    );
  }
}

// API Monitor Screen
class ApiMonitorScreen extends StatelessWidget {
  const ApiMonitorScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
      title: 'API Call Monitor',
      loader: ApiService.getApiCalls,
      builder: (data) =>
          _ApiCallerList(callers: (data['api_callers'] as List? ?? [])));
}

class _ApiCallerList extends StatelessWidget {
  final List callers;
  const _ApiCallerList({required this.callers});

  @override
  Widget build(BuildContext context) {
    if (callers.isEmpty) {
      return const Center(
          child: Text('No outbound HTTP connections detected',
              style: TextStyle(color: AppTheme.muted)));
    }
    return ListView.builder(
      itemCount: callers.length,
      itemBuilder: (ctx, i) {
        final c = callers[i] as Map;
        final count = (c['connections'] as int?) ?? 0;
        return ListTile(
          leading: Icon(Icons.api,
              color: count > 10 ? AppTheme.danger : AppTheme.accent),
          title: Text('${c['process']}',
              style: const TextStyle(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          trailing: Chip(
            label: Text('$count connections',
                style: TextStyle(
                    color: count > 10 ? AppTheme.danger : AppTheme.accent,
                    fontSize: 12)),
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
  @override
  Widget build(BuildContext context) => _DataScreen(
      title: 'Alert Events',
      loader: ApiService.getAlerts,
      builder: (data) => _AlertList(alerts: (data['alerts'] as List? ?? [])));
}

class _AlertList extends StatelessWidget {
  final List alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, color: AppTheme.success, size: 48),
        SizedBox(height: 12),
        Text('No alerts — all systems nominal',
            style: TextStyle(color: AppTheme.muted)),
      ]));
    }
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (ctx, i) {
        final a = alerts[i] as Map;
        final severity = a['severity'] as String? ?? 'info';
        final color = severity == 'critical'
            ? AppTheme.danger
            : severity == 'warning'
                ? AppTheme.warning
                : AppTheme.accent;
        return ListTile(
          leading: Icon(Icons.warning_amber, color: color),
          title: Text('${a['metric_name']}',
              style: const TextStyle(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text('${a['message']}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          trailing: Text('${a['triggered_at']}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        );
      },
    );
  }
}

// Settings Screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<String> _interfaces = ['All'];
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInterfaces() async {
    try {
      final metrics = await ApiService.getCurrentMetrics();
      final netstat = metrics['netstat'] as Map?;
      final interfacesRaw = netstat?['interfaces'] as Map? ?? {};
      if (mounted) {
        setState(() {
          _interfaces = ['All', ...interfacesRaw.keys.cast<String>()];
        });
      }
    } catch (e) {
      // Ignore if backend isn't up
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const _SectionHeader('Dashboard Configuration'),
        const SizedBox(height: 16),
        const Text('Monitored Network Interface',
            style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _interfaces.contains(settings.selectedNetworkInterface)
              ? settings.selectedNetworkInterface
              : 'All',
          dropdownColor: AppTheme.surfaceAlt,
          style: const TextStyle(color: AppTheme.onSurface),
          items: _interfaces
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (val) {
            if (val != null) notifier.setNetworkInterface(val);
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Per-Core CPU Stats',
              style: TextStyle(color: AppTheme.onSurface, fontSize: 15)),
          subtitle: const Text(
              'Display individual CPU cores instead of an aggregate gauge',
              style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          activeThumbColor: AppTheme.accent,
          value: settings.showPerCoreCpu,
          onChanged: notifier.togglePerCoreCpu,
        ),
        const Divider(height: 48),
        const _SectionHeader('Backend Connection'),
        const _SettingTile(label: 'API Host', value: '127.0.0.1'),
        const _SettingTile(label: 'API Port', value: '8443'),
        const _SettingTile(label: 'SSL', value: 'Enabled (local CA)'),
        const Divider(height: 32),
        const _SectionHeader('Data Collection'),
        const Text('Refresh Interval (Seconds)',
            style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        Slider(
          value: settings.refreshIntervalSeconds.toDouble(),
          min: 1,
          max: 60,
          divisions: 59,
          activeColor: AppTheme.accent,
          label: '${settings.refreshIntervalSeconds} s',
          onChanged: (val) => notifier.setRefreshInterval(val.toInt()),
        ),
        const Divider(height: 32),
        const _SectionHeader('About'),
        _SettingTile(label: 'Version', value: _version),
        const _SettingTile(label: 'License', value: 'MIT (Chuck Talk)'),
        const _SettingTile(
            label: 'Repository', value: 'github.com/TaliskerMan/Monitro'),
        const SizedBox(height: 16),
        const Text(
            'Note: Core connection settings must be edited in config/monitro.yaml and require a collector restart.',
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
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8)),
      );
}

class _SettingTile extends StatelessWidget {
  final String label, value;
  const _SettingTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13))),
          Text(value,
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
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

  const _DataScreen(
      {required this.title, required this.loader, required this.builder});

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
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('No data'))
                : widget.builder(_data!),
      );
}

extension _StringTake on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
