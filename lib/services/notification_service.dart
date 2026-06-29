import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../app_settings.dart';

/// A singleton service that manages all local notifications for the app.
///
/// Features:
/// - Morning reminder: "Time for your workout!" at 6 AM daily.
/// - Evening streak-saver: "⚠️ Your streak is at risk!" at 5 PM daily.
/// - The evening reminder is cancelled as soon as the user logs an exercise.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const int _morningId = 1;
  static const int _eveningId = 2;
  static const int _friendId = 3;

  // ─── Morning message bank (Potato Couch voice) ────────────────────────────
  static const List<String> _morningMessages = [
    "Your couch misses you. Do 60 seconds first. 🥔",
    "Rise and… well, at least do some squats.",
    "Good morning! Your streak won't protect itself. 🔥",
    "60 seconds. Even a potato can do that. 💪",
    "Your future self will thank you. Your couch won't.",
    "Streak alert: still alive. Keep it that way. 🥔",
    "Today's workout: 60 seconds. Reward: guilt-free couch time.",
    "You've done harder things. Probably. Let's go. 💪",
    "Don't let yesterday's streak die today. 🔥",
    "The sofa will still be there after. Promise. 🥔",
    "One minute of effort. 23 hours 59 minutes of couch. Deal?",
    "Your streak is fragile. Your excuses are not. 💪",
    "Morning! 60 seconds now = zero regrets later. 🔥",
    "A potato in motion stays in motion. Barely. 🥔",
    "You woke up. Hardest part done. Now squat. 💪",
    "Your streak is watching you scroll. 👀",
    "Gym? No. 60 seconds in your living room? Yes. 🥔",
    "The couch will wait. Your streak won't. 🔥",
  ];

  // ─── Evening message bank (urgent but on-brand) ───────────────────────────
  static const List<String> _eveningMessages = [
    "Still on the couch? Your streak ends at midnight. 🥔",
    "60 seconds. That's all. The couch will survive. 🔥",
    "Evening check-in: streak still alive. Barely. 💪",
    "Your streak called. It's nervous. 👀",
    "Don't go to bed with a broken streak. 🥔",
    "Last chance for today. 60 seconds. Go. 🔥",
    "The couch is a trap. 60 seconds first. 💪",
    "Midnight is closer than you think. 🥔",
    "One set. Any exercise. Right now. 🔥",
    "Your streak survived today. Don't ruin it now. 💪",
    "Evening reminder: you're better than a couch potato. Barely. 🥔",
    "Do it now. Thank yourself at midnight. 🔥",
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // ignore: avoid_print
      print('Could not get local timezone: $e');
    }

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

  /// Show a friend activity notification right now
  Future<void> showFriendActivityNotification(String friendName, String detail) async {
    if (!AppSettings().notificationsEnabled) return;
    await _plugin.show(
      id: _friendId,
      title: '🤝 Friend Update',
      body: '$friendName $detail',
      notificationDetails: _notifDetails(
        channelId: 'friend_activity',
        channelName: 'Friend Activity',
        importance: Importance.defaultImportance,
      ),
    );
  }

  // ─── Private scheduling helpers ────────────────────────────────────────

  // Default times (also shown as defaults in admin_screen.dart)
  static const int _defaultMorningHour = 6;
  static const int _defaultEveningHour = 17;

  /// Fetches admin-configured notification times from Firestore.
  /// Falls back to hardcoded defaults if the document doesn't exist yet.
  Future<Map<String, int>> _fetchNotifTimes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('notifications')
          .get();
      final d = snap.data() ?? {};
      return {
        'morningHour':   (d['morningHour']   as int?) ?? _defaultMorningHour,
        'morningMinute': (d['morningMinute'] as int?) ?? 0,
        'eveningHour':   (d['eveningHour']   as int?) ?? _defaultEveningHour,
        'eveningMinute': (d['eveningMinute'] as int?) ?? 0,
      };
    } catch (_) {
      // Offline or first run — use defaults
      return {
        'morningHour': _defaultMorningHour, 'morningMinute': 0,
        'eveningHour': _defaultEveningHour, 'eveningMinute': 0,
      };
    }
  }

  /// Picks a random index from [bank], never repeating the last shown index.
  /// The last index is persisted in SharedPreferences under [prefKey].
  Future<int> _pickIndex(List<String> bank, String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(prefKey) ?? -1;

    int index;
    if (bank.length == 1) {
      index = 0;
    } else {
      final pool = List<int>.generate(bank.length, (i) => i)..remove(last);
      index = pool[Random().nextInt(pool.length)];
    }

    await prefs.setInt(prefKey, index);
    return index;
  }

  Future<void> _scheduleMorning() async {
    final times = await _fetchNotifTimes();
    final idx = await _pickIndex(_morningMessages, 'notif_morning_last');
    await _plugin.zonedSchedule(
      id: _morningId,
      title: '💪 Time for your workout!',
      body: _morningMessages[idx],
      scheduledDate: _nextInstanceOfHour(times['morningHour']!, times['morningMinute']!),
      notificationDetails: _notifDetails(
        channelId: 'daily_reminder',
        channelName: 'Daily Reminder',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEvening() async {
    final times = await _fetchNotifTimes();
    final idx = await _pickIndex(_eveningMessages, 'notif_evening_last');
    await _plugin.zonedSchedule(
      id: _eveningId,
      title: '⚠️ Your streak is at risk!',
      body: _eveningMessages[idx],
      scheduledDate: _nextInstanceOfHour(times['eveningHour']!, times['eveningMinute']!),
      notificationDetails: _notifDetails(
        channelId: 'streak_saver',
        channelName: 'Streak Saver',
        importance: Importance.high,
        priority: Priority.high,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
