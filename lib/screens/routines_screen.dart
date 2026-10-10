import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/routine.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _timeStr(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

class RoutinesScreen extends StatelessWidget {
  final SupabaseClient supabase;
  final List<Routine> routines;
  final VoidCallback onChanged;

  const RoutinesScreen({
    super.key,
    required this.supabase,
    required this.routines,
    required this.onChanged,
  });

  Future<bool> _mutate(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
      onChanged();
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _deleteRoutine(BuildContext context, Routine r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text('Delete "${r.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      _mutate(context, () => supabase.from('routines').delete().eq('id', r.id));
    }
  }

  static void showDialog_(
    BuildContext context, {
    required SupabaseClient supabase,
    required VoidCallback onChanged,
    Routine? existing,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var selectedDays = Set<int>.from(existing?.daysOfWeek ?? []);
    TimeOfDay? selectedTime = existing?.timeOfDay;
    DateTime? startDate = existing?.startDate;
    DateTime? endDate = existing?.endDate;
    var isActive = existing?.isActive ?? true;

    const dayLetters = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];

    showAdaptiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text(existing == null ? 'New Routine' : 'Edit Routine'),
          scrollable: true,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDs(() => isActive = v),
                ),
                const Text('Days of week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Text('Leave all unselected = every day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    return FilterChip(
                      label: Text(dayLetters[i]),
                      selected: selectedDays.contains(day),
                      onSelected: (v) => setDs(() {
                        if (v) selectedDays.add(day); else selectedDays.remove(day);
                      }),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(selectedTime == null ? 'Set time' : selectedTime!.format(ctx)),
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: selectedTime ?? TimeOfDay.now());
                        if (t != null) setDs(() => selectedTime = t);
                      },
                    ),
                    if (selectedTime != null)
                      TextButton(
                        onPressed: () => setDs(() => selectedTime = null),
                        child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Where (optional)',
                    prefixIcon: Icon(Icons.place, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.event_available, size: 16),
                        label: Text(
                          startDate == null ? 'Start date' : _dateStr(startDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setDs(() => startDate = d);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.event_busy, size: 16),
                        label: Text(
                          endDate == null ? 'End date' : _dateStr(endDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setDs(() => endDate = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final data = {
                  'title': title,
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'time_of_day': selectedTime != null ? _timeStr(selectedTime!) : null,
                  'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                  'days_of_week': (selectedDays.toList()..sort()),
                  'start_date': startDate?.toIso8601String().split('T').first,
                  'end_date': endDate?.toIso8601String().split('T').first,
                  'is_active': isActive,
                };
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await supabase.from('routines').insert({
                      ...data,
                      'user_id': supabase.auth.currentUser!.id,
                    });
                  } else {
                    await supabase.from('routines').update(data).eq('id', existing.id);
                  }
                  onChanged();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routineCard(BuildContext context, Routine r) {
    final todayActive = r.isActiveToday;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: todayActive ? const Color(0xFF5B8DEF).withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: r.isActive
              ? const Color(0xFF5B8DEF).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(
            Icons.repeat,
            size: 20,
            color: r.isActive ? const Color(0xFF5B8DEF) : Colors.grey,
          ),
        ),
        title: Text(
          r.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: r.isActive ? null : Colors.grey,
            decoration: r.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(r.daysLabel, style: const TextStyle(fontSize: 12)),
            if (r.timeLabel.isNotEmpty)
              Text('· ${r.timeLabel}', style: const TextStyle(fontSize: 12)),
            if (r.location != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Text(r.location!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            if (r.startDate != null || r.endDate != null)
              Text(
                [
                  if (r.startDate != null) 'from ${_dateStr(r.startDate!)}',
                  if (r.endDate != null) 'until ${_dateStr(r.endDate!)}',
                ].join(' '),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (!r.isActive) _chip('Inactive', Colors.grey),
            if (todayActive && r.isActive) _chip('Today', const Color(0xFF5B8DEF)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              showDialog_(context, supabase: supabase, onChanged: onChanged, existing: r);
            } else if (v == 'delete') {
              _deleteRoutine(context, r);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
        onTap: () => showDialog_(context, supabase: supabase, onChanged: onChanged, existing: r),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 52, color: Colors.grey),
            SizedBox(height: 12),
            Text('No routines yet.', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            SizedBox(height: 4),
            Text('Tap + to add a daily habit or recurring task.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final todayList = routines.where((r) => r.isActiveToday).toList();
    final otherList = routines.where((r) => !r.isActiveToday).toList();

    return ListView(
      children: [
        if (todayList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'TODAY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...todayList.map((r) => _routineCard(context, r)),
        ],
        if (otherList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'OTHER DAYS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...otherList.map((r) => _routineCard(context, r)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}
