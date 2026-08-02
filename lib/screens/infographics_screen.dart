import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../theme/status_colors.dart';

class InfographicsScreen extends StatefulWidget {
  final List<Task> allTasks;
  final List<Project> projects;
  final bool compact;

  const InfographicsScreen({super.key, required this.allTasks, required this.projects, this.compact = false});

  @override
  State<InfographicsScreen> createState() => _InfographicsScreenState();
}

class _InfographicsScreenState extends State<InfographicsScreen> {
  String _xAxis = 'status';
  String _scope = 'tasks';
  final List<String> _xOptions = ['status', 'project', 'due_date_week'];

  String _xLabel(String v) {
    switch (v) {
      case 'status': return 'Status';
      case 'project': return 'Project';
      case 'due_date_week': return 'Due Date (by week)';
      default: return v;
    }
  }

  List<Task> get _scopedItems => _scope == 'tasks'
      ? widget.allTasks.where((t) => t.parentTaskId == null).toList()
      : widget.allTasks.where((t) => t.parentTaskId != null).toList();

  List<MapEntry<String, int>> _computeCounts() {
    final counts = <String, int>{};
    final colorKeys = <String, String>{}; // key -> status string (for coloring when xAxis == status)
    for (final t in _scopedItems) {
      String key;
      switch (_xAxis) {
        case 'status':
          key = statusLabel(t.status);
          colorKeys[key] = t.status;
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
    _lastColorKeys = colorKeys;
    return counts.entries.toList();
  }

  Map<String, String> _lastColorKeys = {};

  Color _barColor(BuildContext context, String label, int index) {
    if (_xAxis == 'status' && _lastColorKeys.containsKey(label)) {
      return statusColor(_lastColorKeys[label]!);
    }
    final palette = [
      const Color(0xFF5B8DEF), const Color(0xFFF5A623), const Color(0xFF4CAF50),
      const Color(0xFF8B6DD1), const Color(0xFFE55555), const Color(0xFF06B6D4),
      const Color(0xFFF0C808), const Color(0xFFB8A9C9),
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _computeCounts();
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 1;

    return Padding(
      padding: EdgeInsets.all(widget.compact ? 4 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compact) ...[
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Tasks'), selected: _scope == 'tasks', onSelected: (_) => setState(() => _scope = 'tasks')),
                ChoiceChip(label: const Text('Subtasks'), selected: _scope == 'subtasks', onSelected: (_) => setState(() => _scope = 'subtasks')),
              ],
            ),
            const SizedBox(height: 12),
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
              ],
            ),
            const SizedBox(height: 24),
          ],
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No data to show yet.'))
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: entries.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(
                            toY: e.value.value.toDouble(),
                            width: widget.compact ? 14 : 20,
                            borderRadius: BorderRadius.circular(4),
                            color: _barColor(context, e.value.key, e.key),
                          )],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: !widget.compact,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= entries.length) return const SizedBox();
                              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(entries[idx].key, style: const TextStyle(fontSize: 9)));
                            },
                            reservedSize: 36,
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: !widget.compact, reservedSize: 28)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: !widget.compact),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}