import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/in_app_notification.dart';

class InAppNotificationService {
  InAppNotificationService._();
  static final InAppNotificationService instance = InAppNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of notifications for current user
  Stream<List<InAppNotification>> streamNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inAppNotifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return InAppNotification.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Stream of unread notification count
  Stream<int> streamUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inAppNotifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inAppNotifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inAppNotifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Send a notification (can be used when sending friend request, etc)
  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('inAppNotifications')
        .doc();

    final notif = InAppNotification(
      id: docRef.id,
      title: title,
      message: message,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
      relatedId: relatedId,
    );

    await docRef.set(notif.toMap());
  }

  // Helper method to clear old notifications (optional, for cleanup)
  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inAppNotifications')
        .doc(notificationId)
        .delete();
  }
}
