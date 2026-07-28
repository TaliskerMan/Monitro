import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitro/services/api_service.dart';
import 'package:monitro/services/preferences_service.dart';
import 'package:monitro/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Screen widget displaying top running processes on the system.
class ProcessesScreen extends StatelessWidget {
  /// Creates a [ProcessesScreen] instance.
  const ProcessesScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
        title: 'Top Processes',
        loader: ApiService.getProcesses,
        builder: (data) =>
            _ProcessTable(processes: data['processes'] as List? ?? []),
      );
}

/// Data table widget listing process statistics.
class _ProcessTable extends StatefulWidget {
  /// Creates a [_ProcessTable] instance.
  const _ProcessTable({required this.processes});

  /// Raw list of active process maps.
  final List processes;

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

  /// Sort process rows based on column properties.
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

  /// Resolve process property values matching target sorting column indexes.
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

  /// Parse binary program filename from full cmdline parameters list.
  String _parseName(String cmdline) {
    final parts = cmdline.trim().split(' ');
    if (parts.isEmpty) return 'Unknown';
    final bin = parts.first.split('/').last;
    return bin;
  }

  /// Standardize raw system process states into short readable status labels.
  String _mapState(String state) {
    final s = state.toUpperCase();
    if (s.startsWith('R')) return 'RUN';
    if (s.startsWith('S') || s.startsWith('I')) return 'INACT';
    if (s.startsWith('Z')) return 'Z';
    if (s.contains('LISTEN')) {
      return 'LSTN';
    }
    return s; // fallback
  }

  /// Prompt the user with a confirmation warning dialog and call the kill process endpoint.
  Future<void> _killProcess(int pid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Kill Process',
          style: TextStyle(color: AppTheme.onSurface),
        ),
        content: Text(
          'Terminate $name (PID: $pid)?',
          style: const TextStyle(color: AppTheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text(
              'Kill',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiService.killProcess(pid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Process $pid killed.'),
            backgroundColor:
                res['error'] == null ? AppTheme.success : AppTheme.danger,
          ),
        );
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
          color: AppTheme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: const TextStyle(color: AppTheme.onSurface, fontSize: 12),
        columns: [
          DataColumn(label: const Text('PID'), onSort: _sortData),
          DataColumn(label: const Text('NAME'), onSort: _sortData),
          DataColumn(label: const Text('USER'), onSort: _sortData),
          DataColumn(
            label: const Text('CPU %'),
            onSort: _sortData,
            numeric: true,
          ),
          DataColumn(
            label: const Text('MEM %'),
            onSort: _sortData,
            numeric: true,
          ),
          DataColumn(
            label: const Text('RSS KB'),
            onSort: _sortData,
            numeric: true,
          ),
          const DataColumn(label: Text('STATE')),
          const DataColumn(label: Text('ACTION')),
        ],
        rows: _sortedProcesses
            .map<DataRow>((p) => _buildProcessRow(p as Map))
            .toList(),
      ),
    );
  }

  DataRow _buildProcessRow(Map mappedP) {
    final pid = mappedP['pid'] as int? ?? 0;
    final cpuPct = (mappedP['cpu_pct'] as num?)?.toDouble() ?? 0;
    final name = _parseName(mappedP['cmdline'] as String? ?? '');

    return DataRow(
      cells: [
        DataCell(Text('$pid')),
        DataCell(
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text('${mappedP['user'] ?? ''}')),
        DataCell(
          Text(
            cpuPct.toStringAsFixed(1),
            style: TextStyle(
              color: cpuPct >= 50 ? AppTheme.danger : AppTheme.onSurface,
              fontWeight: cpuPct > 10 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        DataCell(Text((mappedP['mem_pct'] as num?)?.toStringAsFixed(1) ?? '')),
        DataCell(Text('${mappedP['rss_kb'] ?? ''}')),
        DataCell(
          Text(
            _mapState(mappedP['state'] as String? ?? ''),
            style: const TextStyle(color: AppTheme.muted),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.danger,
              size: 18,
            ),
            tooltip: 'Kill Process',
            onPressed: () => _killProcess(pid, name),
          ),
        ),
      ],
    );
  }
}

/// Screen widget displaying active system network connections.
class ConnectionsScreen extends StatelessWidget {
  /// Creates a [ConnectionsScreen] instance.
  const ConnectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
        title: 'Network Connections',
        loader: ApiService.getConnections,
        builder: (data) => _ConnectionTables(data: data),
      );
}

/// Tab layout displaying inbound (listening) and outbound (established) connections.
class _ConnectionTables extends StatelessWidget {
  /// Creates a [_ConnectionTables] instance.
  const _ConnectionTables({required this.data});

  /// Raw connection statistics map returned from the API.
  final Map data;

  @override
  Widget build(BuildContext context) {
    final conns = data['connections'] as List? ?? [];

    // Split into Inbound (listening/bound) and Outbound (active to external)
    final inbound = conns.where((connection) {
      final state = connection['state']?.toString().toUpperCase() ?? '';
      final remote = connection['remote']?.toString() ?? '';
      return state == 'LISTEN' ||
          state == 'BOUND' ||
          remote == '*' ||
          remote == '0.0.0.0:*';
    }).toList();

    final outbound =
        conns.where((connection) => !inbound.contains(connection)).toList();

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
          ),
        ],
      ),
    );
  }

  /// Construct the connection data table.
  Widget _buildTable(List connections, {required bool isInbound}) {
    if (connections.isEmpty) {
      return const Center(
        child: Text('No connections', style: TextStyle(color: AppTheme.muted)),
      );
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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
            ],
          ],
          rows: connections.map<DataRow>((connection) {
            final process = connection['process']?.toString().isNotEmpty == true
                ? connection['process']
                : 'Unnamed (${connection['pid'] ?? '?'})';
            final domain = connection['remote_domain']?.toString() ?? '';
            final remote = connection['remote']?.toString() ?? '';
            final state = connection['state']?.toString() ?? '';

            if (isInbound) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      process.toString(),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(Text(connection['local']?.toString() ?? '')),
                  DataCell(Text(remote)),
                  DataCell(
                    Text(
                      domain,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                  DataCell(Text(state)),
                ],
              );
            } else {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      process.toString(),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      domain.isNotEmpty ? domain : '-',
                      style: const TextStyle(color: AppTheme.onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      remote,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                  DataCell(
                    Text(
                      state,
                      style: TextStyle(
                        color: state.toUpperCase() == 'ESTABLISHED'
                            ? AppTheme.success
                            : AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              );
            }
          }).toList(),
        ),
      ),
    );
  }
}

/// Screen widget displaying current user login sessions.
class UsersScreen extends StatelessWidget {
  /// Creates a [UsersScreen] instance.
  const UsersScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
        title: 'User Sessions',
        loader: ApiService.getUsers,
        builder: (data) => _UserList(sessions: data['sessions'] as List? ?? []),
      );
}

/// List builder presenting user session telemetry details.
class _UserList extends StatelessWidget {
  /// Creates a [_UserList] instance.
  const _UserList({required this.sessions});

  /// Raw user sessions list map.
  final List sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'No active sessions',
          style: TextStyle(color: AppTheme.muted),
        ),
      );
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index] as Map;
        return ListTile(
          leading: const Icon(Icons.person, color: AppTheme.accent),
          title: Text(
            '${session['username']}',
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${session['tty']} · from ${session['from_host']} · idle ${session['idle']}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          trailing: Text(
            session['current_cmd'] as String? ?? '',
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        );
      },
    );
  }
}

/// Screen widget displaying API requests statistics.
class ApiMonitorScreen extends StatelessWidget {
  /// Creates an [ApiMonitorScreen] instance.
  const ApiMonitorScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
        title: 'API Call Monitor',
        loader: ApiService.getApiCalls,
        builder: (data) =>
            _ApiCallerList(callers: data['api_callers'] as List? ?? []),
      );
}

/// List builder presenting API connection statistics counts.
class _ApiCallerList extends StatelessWidget {
  /// Creates an [_ApiCallerList] instance.
  const _ApiCallerList({required this.callers});

  /// Raw list representing API caller statistics maps.
  final List callers;

  @override
  Widget build(BuildContext context) {
    if (callers.isEmpty) {
      return const Center(
        child: Text(
          'No outbound HTTP connections detected',
          style: TextStyle(color: AppTheme.muted),
        ),
      );
    }
    return ListView.builder(
      itemCount: callers.length,
      itemBuilder: (context, index) {
        final caller = callers[index] as Map;
        final count = (caller['connections'] as int?) ?? 0;
        return ListTile(
          leading: const Icon(Icons.api, color: AppTheme.accent),
          title: Text(
            '${caller['process']}',
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Chip(
            label: Text(
              '$count connections',
              style: TextStyle(
                color: count > 10 ? AppTheme.danger : AppTheme.accent,
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.surfaceAlt,
          ),
        );
      },
    );
  }
}

/// Screen widget displaying historical resource warning alerts.
class AlertsScreen extends StatelessWidget {
  /// Creates an [AlertsScreen] instance.
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) => _DataScreen(
        title: 'Alert Events',
        loader: ApiService.getAlerts,
        builder: (data) => _AlertList(alerts: data['alerts'] as List? ?? []),
      );
}

/// List builder presenting warning alerts details.
class _AlertList extends StatelessWidget {
  /// Creates an [_AlertList] instance.
  const _AlertList({required this.alerts});

  /// Raw alerts list.
  final List alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.success, size: 48),
            SizedBox(height: 12),
            Text(
              'No alerts — all systems nominal',
              style: TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index] as Map;
        final severity = alert['severity'] as String? ?? 'info';
        return ListTile(
          leading: Icon(
            severity == 'critical' ? Icons.warning : Icons.info_outline,
            color: severity == 'critical' ? AppTheme.danger : AppTheme.warning,
          ),
          title: Text(
            '${alert['metric_name']}',
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${alert['message']}',
            style: const TextStyle(color: AppTheme.muted),
          ),
          trailing: Text(
            '${alert['triggered_at']}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        );
      },
    );
  }
}

/// Settings configuration screen.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [SettingsScreen] instance.
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

  /// Request version specifications from PackageInfo.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (error) {
      log('Exception caught', error: error);
    }
  }

  /// Request network interfaces available from the current metrics.
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
    } catch (error) {
      log('Exception caught', error: error);
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader('Dashboard Configuration'),
          const SizedBox(height: 16),
          const Text(
            'Monitored Network Interface',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                _interfaces.contains(settings.selectedNetworkInterface)
                    ? settings.selectedNetworkInterface
                    : 'All',
            dropdownColor: AppTheme.surfaceAlt,
            style: const TextStyle(color: AppTheme.onSurface),
            items: _interfaces
                .map((iface) =>
                    DropdownMenuItem(value: iface, child: Text(iface)))
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
            title: const Text(
              'Show Per-Core CPU Stats',
              style: TextStyle(color: AppTheme.onSurface, fontSize: 15),
            ),
            subtitle: const Text(
              'Display individual CPU cores instead of an aggregate gauge',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
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
          const Text(
            'Refresh Interval (Seconds)',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
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
            label: 'Repository',
            value: 'github.com/TaliskerMan/Monitro',
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: Core connection settings must be edited in config/monitro.yaml and require a collector restart.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Tiny title header class utilized inside settings panels.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      );
}

/// A setting tile element displaying a label and static value.
class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 13),
            ),
          ],
        ),
      );
}

/// Generic data-loading screen wrapper.
class _DataScreen extends StatefulWidget {
  const _DataScreen({
    required this.title,
    required this.loader,
    required this.builder,
  });
  final String title;
  final Future<Map<String, dynamic>> Function() loader;
  final Widget Function(Map<String, dynamic>) builder;

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
    // Schedule periodic refreshes of telemetry from loader functions
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      await _load();
      return mounted;
    });
  }

  /// Trigger the custom loader callback to refresh datasets.
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
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('No data'))
                : widget.builder(_data!),
      );
}
