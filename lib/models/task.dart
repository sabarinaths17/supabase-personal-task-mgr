class Task {
  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final String status;
  final String? waitingForNote;
  final String? projectId;
  final String? parentTaskId;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.status,
    this.waitingForNote,
    this.projectId,
    this.parentTaskId,
    required this.createdAt,
    this.completedAt,
  });

  bool get isTerminal => status == 'completed' || status == 'cancelled';

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      notes: map['notes'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      status: map['status'] ?? 'todo',
      waitingForNote: map['waiting_for_note'],
      projectId: map['project_id'],
      parentTaskId: map['parent_task_id'],
      createdAt: DateTime.parse(map['created_at']),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }
}

const List<String> kStatuses = [
  'todo',
  'wip',
  'pending',
  'lazy',
  'never_gonna_happen',
  'idk',
  'cancelled',
  'completed',
  'waiting_for',
];

String statusLabel(String status) {
  switch (status) {
    case 'todo': return 'To-do';
    case 'wip': return 'WIP';
    case 'pending': return 'Pending';
    case 'lazy': return 'Lazy';
    case 'never_gonna_happen': return 'Never Gonna Happen';
    case 'idk': return 'IDK';
    case 'cancelled': return 'Cancelled';
    case 'completed': return 'Completed';
    case 'waiting_for': return 'Waiting For';
    default: return status;
  }
}