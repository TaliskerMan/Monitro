import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:monitro/services/api_service.dart';
import 'package:monitro/theme/app_theme.dart';

class CpuCoresScreen extends StatefulWidget {
  const CpuCoresScreen({super.key});

  @override
  State<CpuCoresScreen> createState() => _CpuCoresScreenState();
}

class _CpuCoresScreenState extends State<CpuCoresScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      await _load();
      return mounted;
    });
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getCurrentMetrics();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final cpuData = _data?['cpu'] as Map? ?? {};
    final cores = cpuData['cores'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('CPU Logical Cores')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Real-time Core Utilization', 
              style: TextStyle(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${cores.length} Available Logical Processors', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 32),
            Expanded(
              child: cores.isEmpty 
                  ? const Center(child: Text('No CPU data available', style: TextStyle(color: AppTheme.muted)))
                  : _buildBarChart(cores),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List cores) {
    final barGroups = <BarChartGroupData>[];
    
    for (int i = 0; i < cores.length; i++) {
      final core = cores[i] as Map? ?? {};
      final rawPct = core['busy_pct'];
      final pct = (rawPct is num) ? rawPct.toDouble() : 0.0;
      
      Color color = AppTheme.success;
      if (pct > 50) color = AppTheme.warning;
      if (pct > 80) color = AppTheme.danger;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pct,
              color: color,
              width: cores.length > 16 ? 12 : 24,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: AppTheme.surfaceAlt,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: 100,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'Core ${group.x.toInt()}\n${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 100) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}
