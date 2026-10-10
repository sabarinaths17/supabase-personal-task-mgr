import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/task.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task Reminders';
  static const _channelDesc = 'Due date and overdue task reminders';

  static Future<void> init() async {
    if (_initialized || !Platform.isAndroid) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Cancel all pending notifications and reschedule based on current task list.
  static Future<void> scheduleTaskNotifications(List<Task> tasks) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancelAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final active = tasks
        .where((t) => t.parentTaskId == null && !t.isTerminal)
        .toList();

    final todayDue = active
        .where((t) =>
            t.dueDate != null &&
            DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) ==
                today)
        .toList();

    final overdue = active
        .where((t) =>
            t.dueDate != null &&
            DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
                .isBefore(today))
        .toList();

    // Morning digest: fires at 9am today (or tomorrow if 9am already passed)
    if (todayDue.isNotEmpty || overdue.isNotEmpty) {
      var digestAt = DateTime(now.year, now.month, now.day, 9, 0, 0);
      if (digestAt.isBefore(now)) digestAt = digestAt.add(const Duration(days: 1));
      await _schedule(
        id: 1,
        title: _digestTitle(todayDue.length, overdue.length),
        body: _digestBody(todayDue, overdue),
        at: digestAt,
      );
    }

    // Per-task "due tomorrow" reminder at 9am the day before
    for (final task in active) {
      if (task.dueDate == null) continue;
      final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final dayBefore9am = DateTime(due.year, due.month, due.day, 9, 0, 0)
          .subtract(const Duration(days: 1));
      if (dayBefore9am.isAfter(now)) {
        await _schedule(
          id: _taskNotifId(task.id),
          title: 'Due tomorrow: ${task.title}',
          body: task.priority == 'high'
              ? 'High priority — don\'t forget!'
              : 'Task due tomorrow',
          at: dayBefore9am,
        );
      }
    }
  }

  static String _digestTitle(int todayCount, int overdueCount) {
    if (overdueCount > 0 && todayCount > 0) {
      return '$overdueCount overdue · $todayCount due today';
    } else if (overdueCount > 0) {
      return '$overdueCount overdue task${overdueCount > 1 ? 's' : ''}';
    } else {
      return '$todayCount task${todayCount > 1 ? 's' : ''} due today';
    }
  }

  static String _digestBody(List<Task> todayDue, List<Task> overdue) {
    final first = overdue.isNotEmpty ? overdue.first : todayDue.first;
    final total = overdue.length + todayDue.length;
    return total > 1 ? '${first.title} and ${total - 1} more' : first.title;
  }

  // Map a UUID string to a stable int notification ID (avoids collisions with ID 1)
  static int _taskNotifId(String uuid) => uuid.hashCode.abs() % 100000 + 2000;

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
