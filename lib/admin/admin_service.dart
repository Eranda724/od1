import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<bool> checkIsAdmin(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists && doc.data()?['isAdmin'] == true;
  } catch (e) {
    debugPrint('Error checking admin status: $e');
    return false;
  }
}

Future<String?> getAdminRole(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        return data['adminRole'] as String?;
      }
    }
    return null;
  } catch (e) {
    debugPrint('Error checking admin role: $e');
    return null;
  }
}
