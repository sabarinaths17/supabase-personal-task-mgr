import 'package:flutter/material.dart';

class Routine {
  final String id;
  final String title;
  final String? notes;
  final TimeOfDay? timeOfDay;
  final String? location;
  final List<int> daysOfWeek; // 1=Mon..7=Sun, empty=every day
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;

  Routine({
    required this.id,
    required this.title,
    this.notes,
    this.timeOfDay,
    this.location,
    required this.daysOfWeek,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  bool get isActiveToday {
    if (!isActive) return false;
    final today = DateTime.now().weekday; // 1=Mon..7=Sun
    return daysOfWeek.isEmpty || daysOfWeek.contains(today);
  }

  String get daysLabel {
    if (daysOfWeek.isEmpty) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...daysOfWeek]..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  String get timeLabel {
    if (timeOfDay == null) return '';
    final h = timeOfDay!.hour;
    final m = timeOfDay!.minute;
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'],
      title: map['title'],
      notes: map['notes'],
      timeOfDay: _parseTime(map['time_of_day']),
      location: map['location'],
      daysOfWeek: (map['days_of_week'] as List<dynamic>? ?? []).cast<int>(),
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
