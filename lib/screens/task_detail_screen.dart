import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../theme/status_colors.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final SupabaseClient supabase;
  final VoidCallback onChanged;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.supabase,
    required this.onChanged,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  bool _previewMode = false;
  DateTime? _dueDate;
  late String _status;
  List<Task> _subtasks = [];
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _dueDate = widget.task.dueDate;
    _status = widget.task.status;
    _loadSubtasks();

    _channel = widget.supabase.channel('subtasks_of_${widget.task.id}').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (payload) => _loadSubtasks(),
    ).subscribe();
  }

  @override
  void dispose() {
    widget.supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadSubtasks() async {
    final data = await widget.supabase
        .from('tasks')
        .select()
        .eq('parent_task_id', widget.task.id)
        .order('created_at', ascending: true);
    if (!mounted) return;
    setState(() {
      _subtasks = data.map<Task>((row) => Task.fromMap(row)).toList();
    });
  }

  /// Surfaces a write failure (e.g. a silently-rejecting RLS policy) as a
  /// SnackBar instead of letting it fail invisibly.
  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<bool> _save() async {
    final ok = await _mutate(() => widget.supabase.from('tasks').update({
      'title': _titleController.text.trim(),
      'notes': _notesController.text,
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'status': _status,
      'completed_at': _status == 'completed' ? DateTime.now().toIso8601String() : null,
    }).eq('id', widget.task.id));
    if (ok) widget.onChanged();
    return ok;
  }

  Future<void> _saveAndClose() async {
    final ok = await _save();
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _addSubtask(String title, DateTime? dueDate) {
    return _mutate(() => widget.supabase.from('tasks').insert({
      'title': title,
      'user_id': widget.supabase.auth.currentUser!.id,
      'parent_task_id': widget.task.id,
      'project_id': widget.task.projectId,
      'due_date': dueDate?.toIso8601String().split('T').first,
    })).then((_) => _loadSubtasks());
  }

  Future<void> _toggleSubtask(Task sub, bool done) {
    return _mutate(() => widget.supabase.from('tasks').update({
      'status': done ? 'completed' : 'todo',
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', sub.id)).then((_) => _loadSubtasks());
  }

  void _showAddSubtaskDialog() {
    final controller = TextEditingController();
    DateTime? dueDate;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Subtask'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Subtask title')),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dueDate == null ? 'Set due date' : '${dueDate!.year}-${dueDate!.month}-${dueDate!.day}'),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => dueDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) _addSubtask(controller.text.trim(), dueDate);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _subtasks.where((s) => s.isTerminal).length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Save & close',
          onPressed: _saveAndClose,
        ),
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saveAndClose,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: 'Status',
              filled: true,
              fillColor: statusColor(_status).withValues(alpha: 0.15),
            ),
            items: kStatuses.map((s) => DropdownMenuItem(
              value: s,
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(s), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(statusLabel(s)),
              ]),
            )).toList(),
            onChanged: (val) => setState(() => _status = val!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(_dueDate == null ? 'No due date' : '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: const Text('Change'),
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: Icon(_previewMode ? Icons.edit : Icons.visibility),
                label: Text(_previewMode ? 'Edit' : 'Preview'),
                onPressed: () => setState(() => _previewMode = !_previewMode),
              ),
            ],
          ),
          const Text('Supports **bold**, *italic*, # headings, - lists', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          _previewMode
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: MarkdownBody(data: _notesController.text.isEmpty ? '_No notes_' : _notesController.text),
                )
              : TextField(
                  controller: _notesController,
                  maxLines: 8,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Write notes here...'),
                ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtasks ($completedCount/${_subtasks.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: _showAddSubtaskDialog),
            ],
          ),
          ..._subtasks.map((sub) => Card(
                margin: const EdgeInsets.only(top: 6),
                child: ListTile(
                  leading: _HoverCheckbox(
                    value: sub.isTerminal,
                    onChanged: (val) => _toggleSubtask(sub, val),
                  ),
                  title: Text(sub.title, style: sub.isTerminal ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                  subtitle: Text([
                    statusLabel(sub.status),
                    if (sub.dueDate != null) '${sub.dueDate!.year}-${sub.dueDate!.month}-${sub.dueDate!.day}',
                  ].join(' · ')),
                ),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _HoverCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _HoverCheckbox({required this.value, required this.onChanged});

  @override
  State<_HoverCheckbox> createState() => _HoverCheckboxState();
}

class _HoverCheckboxState extends State<_HoverCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovering ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Checkbox(
          value: widget.value,
          activeColor: Colors.green,
          onChanged: (val) => widget.onChanged(val ?? false),
        ),
      ),
    );
  }
}