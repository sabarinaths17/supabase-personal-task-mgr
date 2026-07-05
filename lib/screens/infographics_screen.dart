import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/task.dart';
import '../models/project.dart';

class InfographicsScreen extends StatefulWidget {
  final List<Task> tasks;
  final List<Project> projects;

  const InfographicsScreen({super.key, required this.tasks, required this.projects});

  @override
  State<InfographicsScreen> createState() => _InfographicsScreenState();
}

class _InfographicsScreenState extends State<InfographicsScreen> {
  String _xAxis = 'status';
  final List<String> _xOptions = ['status', 'project', 'due_date_week'];

  String _xLabel(String v) {
    switch (v) {
      case 'status': return 'Status';
      case 'project': return 'Project';
      case 'due_date_week': return 'Due Date (by week)';
      default: return v;
    }
  }

  Map<String, int> _computeCounts() {
    final counts = <String, int>{};
    for (final t in widget.tasks) {
      String key;
      switch (_xAxis) {
        case 'status':
          key = statusLabel(t.status);
          break;
        case 'project':
          if (t.projectId == null) {
            key = 'No Project';
          } else {
            final match = widget.projects.where((p) => p.id == t.projectId);
            key = match.isNotEmpty ? match.first.name : 'Unknown';
          }
          break;
        case 'due_date_week':
          if (t.dueDate == null) {
            key = 'No date';
          } else {
            final weekStart = t.dueDate!.subtract(Duration(days: t.dueDate!.weekday - 1));
            key = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
          }
          break;
        default:
          key = 'Other';
      }
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _computeCounts();
    final entries = counts.entries.toList();
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
  children: [
    const Text('X-Axis: '),
    const SizedBox(width: 8),
    Wrap(
      spacing: 8,
      children: _xOptions.map((o) => ChoiceChip(
        label: Text(_xLabel(o)),
        selected: _xAxis == o,
        onSelected: (_) => setState(() => _xAxis = o),
      )).toList(),
    ),
    const Spacer(),
    const Text('Y-Axis: Task Count'),
  ],
),
          const SizedBox(height: 24),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No data to show yet.'))
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: entries.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(toY: e.value.value.toDouble(), width: 20)],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= entries.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(entries[idx].key, style: const TextStyle(fontSize: 10)),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}