import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_info.dart';
import 'streak_service.dart';
import 'in_app_notification_service.dart';
import 'dart:math' as math;

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String getPairId(String uid1, String uid2) {
    final uids = [uid1, uid2]..sort();
    return '${uids[0]}_${uids[1]}';
  }

  // Send Friend Request
  Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUsername,
  }) async {
    // 1. Find user by username
    final usersRef = FirebaseFirestore.instance.collection('users');
    var query = await usersRef.where('displayName', isEqualTo: toUsername).limit(1).get();

    if (query.docs.isEmpty) {
      // Fallback: check legacy 'username' field
      query = await usersRef.where('username', isEqualTo: toUsername).limit(1).get();
    }

    if (query.docs.isEmpty) {
      throw Exception('User not found.');
    }
    
    final toUid = query.docs.first.id;
    if (toUid == fromUid) {
      throw Exception("You can't add yourself as a friend.");
    }

    final pairId = getPairId(fromUid, toUid);

    // 2. Check if already friends
    final pairDoc = await FirebaseFirestore.instance.collection('friendPairs').doc(pairId).get();
    if (pairDoc.exists) {
      throw Exception('You are already friends.');
    }

    // 3. Check for existing request
    final reqsQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reqsQuery.docs.isNotEmpty) {
      throw Exception('Friend request already sent.');
    }

    // 4. Create request
    await FirebaseFirestore.instance.collection('friendRequests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromName': fromName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 5. Send Notification
    await InAppNotificationService.instance.sendNotification(
      targetUserId: toUid,
      title: 'New Friend Request',
      message: '$fromName sent you a friend request!',
      type: 'friend_request',
      relatedId: fromUid,
    );
  }

  // Accept Friend Request
  Future<void> acceptRequest(String docId, String fromUid, String toUid) async {
    final pairId = getPairId(fromUid, toUid);

    final batch = FirebaseFirestore.instance.batch();

    // 1. Mark request as accepted
    final reqRef = FirebaseFirestore.instance.collection('friendRequests').doc(docId);
    batch.update(reqRef, {'status': 'accepted'});

    // Also get the fromName for the notification (need to fetch it first or use currentUser displayName)
    // Wait, the request has fromName but not toName. Let's fetch the toName from currentUser.
    final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(toUid).get();
    final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Someone';

    // 2. Create pair document
    final pairRef = FirebaseFirestore.instance.collection('friendPairs').doc(pairId);
    batch.set(pairRef, {
      'uids': [fromUid, toUid],
    });

    await batch.commit();

    // 3. Send Notification to the person who requested
    await InAppNotificationService.instance.sendNotification(
      targetUserId: fromUid,
      title: 'Friend Request Accepted',
      message: '$currentUserName accepted your friend request!',
      type: 'friend_accepted',
      relatedId: toUid,
    );
  }

  // Reject Friend Request
  Future<void> rejectRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('friendRequests')
        .doc(docId)
        .update({'status': 'rejected'});
  }

  // Remove Friend Request
  Future<void> removeFriendRequest(String fromUid, String toUid) async {
    final reqsQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in reqsQuery.docs) {
      await doc.reference.delete();
    }
  }

  // Remove Friend
  Future<void> removeFriend(String uid1, String uid2) async {
    final pairId = getPairId(uid1, uid2);
    await FirebaseFirestore.instance.collection('friendPairs').doc(pairId).delete();
  }

  // Get Friends List
  Stream<List<FriendInfo>> getFriendsList(String currentUid) {
    late StreamController<List<FriendInfo>> controller;
    StreamSubscription? pairsSub;
    StreamSubscription? meSub;
    final Map<String, StreamSubscription> friendSubs = {};
    
    List<String> currentFriendUids = [];
    Map<String, String> pairIds = {};
    Map<String, int> pairSharedStreaks = {};
    DocumentSnapshot? myDoc;
    final Map<String, DocumentSnapshot> friendDocs = {};

    void emit() {
      if (myDoc == null) return;
      if (friendDocs.length != currentFriendUids.length) return;
      
      final cData = myDoc!.data() as Map<String, dynamic>? ?? {};
      final cEffective = StreakService.getEffectiveStreakData(
        streak: cData['overallStreak'] ?? 0,
        freezesAvailable: cData['freezesAvailable'] ?? 2,
        frozenDates: List<String>.from(cData['frozenDates'] ?? []),
        lastEvaluatedDate: cData['overallLastEvaluatedDate'] as String?,
      );
      final myStreak = cEffective.streak;
      final today = _todayKey();

      final friends = <FriendInfo>[];
      for (final fUid in currentFriendUids) {
        final fDoc = friendDocs[fUid];
        if (fDoc == null) continue;
        final fData = fDoc.data() as Map<String, dynamic>? ?? {};
        
        final fEffective = StreakService.getEffectiveStreakData(
          streak: fData['overallStreak'] ?? 0,
          freezesAvailable: fData['freezesAvailable'] ?? 2,
          frozenDates: List<String>.from(fData['frozenDates'] ?? []),
          lastEvaluatedDate: fData['overallLastEvaluatedDate'] as String?,
        );
        final friendStreak = fEffective.streak;
        final friendDoneToday = (fData['overallLastDate'] as String?) == today;

        friends.add(FriendInfo(
          uid: fUid,
          displayName: fData['displayName'] ?? 'Unknown',
          overallStreak: friendStreak,
          yearlyActiveDays: (fData['yearlyActiveDays'] as num?)?.toInt() ?? 0,
          sharedStreak: pairSharedStreaks[fUid] ?? 0,
          sharedLastDate: null,
          friendDoneToday: friendDoneToday,
          pairId: pairIds[fUid]!,
          photoUrl: fData['photoUrl'],
        ));
      }
      
      // Sort identical to original behavior if needed, although caller sorts it anyway.
      controller.add(friends);
    }

    controller = StreamController<List<FriendInfo>>.broadcast(
      onListen: () {
        meSub = FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots().listen((snap) {
          myDoc = snap;
          emit();
        });

        pairsSub = FirebaseFirestore.instance
            .collection('friendPairs')
            .where('uids', arrayContains: currentUid)
            .snapshots()
            .listen((snapshot) {
          
          final newFriendUids = <String>[];
          for (final doc in snapshot.docs) {
            final uids = List<String>.from(doc['uids']);
            final fUid = uids.firstWhere((id) => id != currentUid);
            newFriendUids.add(fUid);
            pairIds[fUid] = doc.id;
            
            final data = doc.data() as Map<String, dynamic>? ?? {};
            pairSharedStreaks[fUid] = (data['sharedStreak'] ?? 0) as int;
          }
          currentFriendUids = newFriendUids;

          // Remove old subs
          final toRemove = friendSubs.keys.where((k) => !newFriendUids.contains(k)).toList();
          for (final k in toRemove) {
            friendSubs[k]?.cancel();
            friendSubs.remove(k);
            friendDocs.remove(k);
          }

          // Add new subs
          for (final fUid in newFriendUids) {
            if (!friendSubs.containsKey(fUid)) {
              friendSubs[fUid] = FirebaseFirestore.instance.collection('users').doc(fUid).snapshots().listen((snap) {
                friendDocs[fUid] = snap;
                emit();
              });
            }
          }
          emit();
        });
      },
      onCancel: () {
        meSub?.cancel();
        pairsSub?.cancel();
        for (final sub in friendSubs.values) {
          sub.cancel();
        }
      },
    );

    return controller.stream;
  }

}
