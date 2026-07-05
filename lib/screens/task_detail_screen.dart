import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final List<Task> subtasks;
  final SupabaseClient supabase;
  final VoidCallback onChanged;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.subtasks,
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _dueDate = widget.task.dueDate;
    _status = widget.task.status;
  }

  Future<void> _save() async {
    await widget.supabase.from('tasks').update({
      'title': _titleController.text.trim(),
      'notes': _notesController.text,
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'status': _status,
      'completed_at': _status == 'completed' ? DateTime.now().toIso8601String() : null,
    }).eq('id', widget.task.id);
    widget.onChanged();
  }

  Future<void> _addSubtask(String title) async {
    await widget.supabase.from('tasks').insert({
      'title': title,
      'user_id': widget.supabase.auth.currentUser!.id,
      'parent_task_id': widget.task.id,
      'project_id': widget.task.projectId,
    });
    widget.onChanged();
  }

  void _showAddSubtaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subtask'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) _addSubtask(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: () async {
            await _save();
            if (context.mounted) Navigator.pop(context);
          }),
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
            decoration: const InputDecoration(labelText: 'Status'),
            items: kStatuses.map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))).toList(),
            onChanged: (val) => setState(() => _status = val!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(_dueDate == null ? 'No due date' : '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
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
              const Text('Subtasks', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: _showAddSubtaskDialog),
            ],
          ),
          ...widget.subtasks.map((sub) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: sub.status == 'completed',
                  onChanged: (val) async {
                    await widget.supabase.from('tasks').update({
                      'status': val == true ? 'completed' : 'todo',
                      'completed_at': val == true ? DateTime.now().toIso8601String() : null,
                    }).eq('id', sub.id);
                    widget.onChanged();
                  },
                ),
                title: Text(sub.title, style: sub.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                subtitle: Text(statusLabel(sub.status)),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}