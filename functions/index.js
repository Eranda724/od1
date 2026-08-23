const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// 1. Friend Request Notification (Created)
exports.sendFriendRequestNotification = onDocumentCreated("friendRequests/{requestId}", async (event) => {
  const requestData = event.data.data();
  if (!requestData || requestData.status !== "pending") return;

  const toUid = requestData.toUid;
  const fromName = requestData.fromName || "Someone";

  const targetUserDoc = await db.collection("users").doc(toUid).get();
  if (!targetUserDoc.exists) {
    console.log(`Target user ${toUid} not found. Skipping.`);
    return;
  }

  const fcmToken = targetUserDoc.data().fcmToken;
  if (!fcmToken) {
    console.log(`Target user ${toUid} has no fcmToken. Skipping push notification.`);
    return;
  }

  const message = {
    notification: {
      title: "🤝 New Friend Request",
      body: `${fromName} wants to be your friend!`,
    },
    token: fcmToken,
  };

  try {
    await admin.messaging().send(message);
    console.log(`Successfully sent friend request push to ${toUid}`);
  } catch (error) {
    console.error(`Error sending push to ${toUid}:`, error);
  }
});

// 2. Friend Activity Notification (Workout Completed)
exports.sendFriendActivityNotification = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeDate = before ? before.overallLastDate : null;
  const afterDate = after ? after.overallLastDate : null;

  // Strict check: Only fire exactly when the overall last active date changes
  if (beforeDate === afterDate) return;

  const uid = event.params.uid;
  
  const displayName = after.displayName || "A friend";

  // Fetch all friend pairs for this user
  const pairsSnap = await db.collection("friendPairs")
    .where("uids", "array-contains", uid)
    .get();

  if (pairsSnap.empty) return;

  // Extract all friend UIDs
  const friendUids = [];
  pairsSnap.docs.forEach(doc => {
    const uids = doc.data().uids || [];
    const friendUid = uids.find(id => id !== uid);
    if (friendUid) friendUids.push(friendUid);
  });

  if (friendUids.length === 0) return;

  // Fetch all friend user documents, plus the sender's document to get their current token
  const friendRefs = friendUids.map(fUid => db.collection("users").doc(fUid));
  const friendDocs = await db.getAll(...friendRefs);

  // We must not send the push to the sender's own device!
  // This happens if the user tests two accounts on one physical phone (both share the same FCM token).
  const senderToken = after.fcmToken || null;

  const tokens = [];
  friendDocs.forEach(doc => {
    if (doc.exists && doc.data().fcmToken) {
      const friendToken = doc.data().fcmToken;
      // Exclude if it's the exact same physical device token as the person who worked out
      if (friendToken !== senderToken) {
        tokens.push(friendToken);
      }
    }
  });

  if (tokens.length === 0) {
    console.log(`No valid friend tokens found (or they were all the sender's own device).`);
    return;
  }

  const message = {
    notification: {
      title: "💪 Friend Activity",
      body: `${displayName} completed a workout today!`,
    },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Sent friend activity push to ${response.successCount} devices.`);
  } catch (err) {
    console.error("Error sending friend activity push:", err);
  }

  // Write to inAppNotifications for each friend
  const batch = db.batch();
  friendUids.forEach(fUid => {
    // Only write if it's not the sender themselves
    if (fUid !== uid) {
      const notifRef = db.collection("users").doc(fUid).collection("inAppNotifications").doc();
      batch.set(notifRef, {
        title: "💪 Friend Activity",
        message: `${displayName} completed a workout today!`,
        type: "friend_activity",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        relatedId: uid
      });
    }
  });

  try {
    await batch.commit();
    console.log(`Successfully wrote inAppNotifications for friend activity.`);
  } catch (err) {
    console.error("Error writing inAppNotifications:", err);
  }
});

// 3. Friend Request Accepted Notification
exports.sendFriendAcceptedNotification = onDocumentUpdated("friendRequests/{requestId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (!before || !after) return;

  // Strict check: Only fire when status transitions EXACTLY from pending to accepted
  if (before.status === after.status || after.status !== "accepted") {
    return;
  }

  const senderUid = after.fromUid; 

  const [senderDoc, receiverDoc] = await db.getAll(
    db.collection("users").doc(senderUid),
    db.collection("users").doc(after.toUid)
  );

  if (!senderDoc.exists || !senderDoc.data().fcmToken) return;
  
  const receiverName = receiverDoc.exists ? (receiverDoc.data().displayName || "Someone") : "Someone";

  const message = {
    notification: {
      title: "✅ Request Accepted",
      body: `${receiverName} accepted your friend request!`,
    },
    token: senderDoc.data().fcmToken,
  };

  try {
    await admin.messaging().send(message);
    console.log(`Successfully sent friend accepted push to ${senderUid}`);
  } catch (error) {
    console.error("Error sending accepted push:", error);
  }
});
