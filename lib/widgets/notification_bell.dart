import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/in_app_notification.dart';
import '../services/in_app_notification_service.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  final Color? iconColor;
  final Function(int)? onNavigateTab;

  const NotificationBell({super.key, this.iconColor, this.onNavigateTab});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isDropdownOpen = false;
    });
  }

  void _showDropdown() {
    if (_overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible barrier to close dropdown when tapping outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
              child: Container(),
            ),
          ),
          Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-320 + size.width, size.height + 8), // Align to the right
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                shadowColor: Colors.black26,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'notifications'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _closeDropdown();
                                InAppNotificationService.instance.markAllAsRead();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'mark_all_read'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? Colors.blueAccent : Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Notifications List
                      Flexible(
                        child: StreamBuilder<List<InAppNotification>>(
                          stream: InAppNotificationService.instance.streamNotifications(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final notifications = snapshot.data ?? [];

                            if (notifications.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    'no_notifications_yet'.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Show up to 4 notifications
                            final displayCount = notifications.length > 4 ? 4 : notifications.length;

                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: displayCount,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final notif = notifications[index];
                                return _buildDropdownItem(notif, isDark);
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      // Footer (See All)
                      InkWell(
                        onTap: () async {
                          _closeDropdown();
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                          if (result == 'social') {
                            widget.onNavigateTab?.call(3);
                          }
                        },
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            'see_all'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color.fromARGB(255, 224, 138, 58), // Primary orange
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(InAppNotification notif, bool isDark) {
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
          return const Color.fromARGB(255, 224, 138, 58);
      }
    }

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          InAppNotificationService.instance.markAsRead(notif.id);
        }
        _closeDropdown();
        if (notif.type == 'friend_activity' || 
            notif.type == 'friend_request' || 
            notif.type == 'friend_accepted') {
          widget.onNavigateTab?.call(3);
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: getIconColor().withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getIconData(),
                color: getIconColor(),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatShortTime(notif.createdAt),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatShortTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: StreamBuilder<int>(
        stream: InAppNotificationService.instance.streamUnreadCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: Colors.red,
              smallSize: 10,
              child: Icon(
                Icons.notifications_none_rounded,
                color: widget.iconColor,
              ),
            ),
            onPressed: _toggleDropdown,
          );
        },
      ),
    );
  }
}
