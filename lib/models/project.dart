class Project {
  final String id;
  final String name;
  final String? description;
  final DateTime? dueDate;
  final String priority;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.dueDate,
    this.priority = 'medium',
    required this.createdAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}