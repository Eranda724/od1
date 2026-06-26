import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../app_settings.dart';

/// A singleton service that manages all local notifications for the app.
///
/// Features:
/// - Morning reminder: "Time for your workout!" at 8 AM daily.
/// - Evening streak-saver: "⚠️ Your streak is at risk!" at 8 PM daily.
/// - The evening reminder is cancelled as soon as the user logs an exercise.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const int _morningId = 1;
  static const int _eveningId = 2;

  // ─────────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // v22 uses named parameter `settings:`
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────────

  /// Schedules both daily reminders — only if notifications are enabled in settings.
  Future<void> refreshSchedule() async {
    if (!AppSettings().notificationsEnabled) return;
    await _scheduleMorning();
    await _scheduleEvening();
  }

  /// Cancels the evening streak-saver for today. Call this right after
  /// a user successfully saves an exercise.
  Future<void> cancelTodayEveningReminder() async {
    if (!AppSettings().notificationsEnabled) return;
    // v22 uses named parameter `id:`
    await _plugin.cancel(id: _eveningId);
  }

  /// Cancels ALL notifications — used when user disables notifications in settings.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Private scheduling helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _scheduleMorning() async {
    // v22 uses all named parameters
    await _plugin.zonedSchedule(
      id: _morningId,
      title: '💪 Time for your workout!',
      body: 'Keep your streak alive — just 60 seconds today.',
      scheduledDate: _nextInstanceOfHour(8, 0),
      notificationDetails: _notifDetails(
        channelId: 'daily_reminder',
        channelName: 'Daily Reminder',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  Future<void> _scheduleEvening() async {
    await _plugin.zonedSchedule(
      id: _eveningId,
      title: '⚠️ Your streak is at risk!',
      body: "You haven't worked out yet today. Don't let your streak break!",
      scheduledDate: _nextInstanceOfHour(20, 0),
      notificationDetails: _notifDetails(
        channelId: 'streak_saver',
        channelName: 'Streak Saver',
        importance: Importance.high,
        priority: Priority.high,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  NotificationDetails _notifDetails({
    required String channelId,
    required String channelName,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _nextInstanceOfHour(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
