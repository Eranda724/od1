import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // e.g. 'friend_request', 'system'
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });

  factory InAppNotification.fromMap(Map<String, dynamic> data, String documentId) {
    return InAppNotification(
      id: documentId,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedId: data['relatedId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (relatedId != null) 'relatedId': relatedId,
    };
  }
}
