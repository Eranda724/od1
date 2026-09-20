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

/// Returns the current freeze recharge period in days from Firestore.
/// Defaults to 15 if not set.
Future<int> getFreezeRechargePeriod() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .get();
    return (doc.data()?['freezeRechargePeriodDays'] as int?) ?? 15;
  } catch (e) {
    debugPrint('Error getting freeze recharge period: $e');
    return 15;
  }
}

/// Saves the freeze recharge period (in days) to Firestore.
/// This immediately affects all users' freeze countdown display and
/// all future streak evaluations.
Future<void> updateFreezeRechargePeriod(int days) async {
  try {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .set({'freezeRechargePeriodDays': days}, SetOptions(merge: true));
    debugPrint('Freeze recharge period updated to $days days');
  } catch (e) {
    debugPrint('Error updating freeze recharge period: $e');
    rethrow;
  }
}
