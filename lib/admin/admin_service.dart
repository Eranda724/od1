import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> checkIsAdmin(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    return doc.exists && doc.data()?['role'] == 'admin';
  } catch (e) {
    print('Error checking admin status: $e');
    return false;
  }
}
