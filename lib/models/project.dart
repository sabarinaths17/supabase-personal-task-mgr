class Project {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}