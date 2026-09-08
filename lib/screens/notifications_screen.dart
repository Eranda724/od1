import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/in_app_notification.dart';
import '../services/in_app_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Delete notifications older than 7 days
    InAppNotificationService.instance.deleteOldNotifications();
    // Mark all as read when opening the screen
    InAppNotificationService.instance.markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'notifications'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<InAppNotification>>(
        stream: InAppNotificationService.instance.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('error_loading_data'.tr()));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 64,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_notifications_yet'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationCard(context, notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, InAppNotification notif) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData getIconData() {
      switch (notif.type) {
        case 'friend_request':
          return Icons.person_add_rounded;
        case 'friend_accepted':
          return Icons.how_to_reg_rounded;
        case 'friend_activity':
          return Icons.fitness_center_rounded;
        case 'streak_broken':
          return Icons.heart_broken_rounded;
        default:
          return Icons.notifications_active_rounded;
      }
    }

    Color getIconColor() {
      switch (notif.type) {
        case 'friend_request':
        case 'friend_accepted':
          return Colors.blue;
        case 'friend_activity':
          return Colors.green;
        case 'streak_broken':
          return Colors.red;
        default:
          return const Color.fromARGB(255, 224, 138, 58); // Primary orange
      }
    }

    // A subtle 3D card style consistent with other screens
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: getIconColor().withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            getIconData(),
            color: getIconColor(),
            size: 24,
          ),
        ),
        title: Text(
          notif.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notif.message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(notif.createdAt),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        trailing: notif.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          if (!notif.isRead) {
            InAppNotificationService.instance.markAsRead(notif.id);
          }
          if (notif.type == 'friend_activity' || 
              notif.type == 'friend_request' || 
              notif.type == 'friend_accepted') {
            Navigator.pop(context, 'social');
          }
        },
      ),
    ));
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'yesterday'.tr();
      return '${difference.inDays} ${'days_ago'.tr()}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${'hours_ago'.tr()}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${'minutes_ago'.tr()}';
    } else {
      return 'just_now'.tr();
    }
  }
}
