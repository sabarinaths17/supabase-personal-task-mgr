import 'package:flutter/material.dart';

Color statusColor(String status) {
  switch (status) {
    case 'todo': return const Color(0xFF5B8DEF);
    case 'wip': return const Color(0xFFF5A623);
    case 'pending': return const Color(0xFFF0C808);
    case 'lazy': return const Color(0xFFB8A9C9);
    case 'never_gonna_happen': return const Color(0xFF6B7280);
    case 'idk': return const Color(0xFF9CA3AF);
    case 'cancelled': return const Color(0xFFE55555);
    case 'completed': return const Color(0xFF4CAF50);
    case 'waiting_for': return const Color(0xFF8B6DD1);
    default: return Colors.grey;
  }
}

Color priorityColor(String priority) {
  switch (priority) {
    case 'high': return const Color(0xFFE55555);
    case 'medium': return const Color(0xFFF5A623);
    case 'low': return const Color(0xFF5B8DEF);
    default: return Colors.grey;
  }
}