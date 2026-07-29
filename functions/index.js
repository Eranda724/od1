const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Helper to update all users in batches
async function resetScoresForField(fieldPath) {
  const usersRef = db.collection("users");
  const snapshot = await usersRef.get();
  
  if (snapshot.empty) return;
  
  let batch = db.batch();
  let operationCount = 0;
  
  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { [fieldPath]: 0 });
    operationCount++;
    
    // Firestore batch limit is 500
    if (operationCount === 490) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }
  
  if (operationCount > 0) {
    await batch.commit();
  }
  
  console.log(`Successfully reset ${fieldPath} for all users.`);
}

// Define the timezone for resets (e.g., 'UTC', 'America/New_York', 'Asia/Kolkata')
const TIMEZONE = 'UTC';

// 1. Reset Daily Scores - Runs every day at 00:00 (Midnight)
exports.resetDailyLeaderboard = onSchedule({
  schedule: "0 0 * * *",
  timeZone: TIMEZONE
}, async (event) => {
  await resetScoresForField("scores.daily");
});

// 2. Reset Weekly Scores - Runs every Monday at 00:00
exports.resetWeeklyLeaderboard = onSchedule({
  schedule: "0 0 * * 1",
  timeZone: TIMEZONE
}, async (event) => {
  await resetScoresForField("scores.weekly");
});

// 3. Reset Monthly Scores - Runs on the 1st of every month at 00:00
exports.resetMonthlyLeaderboard = onSchedule({
  schedule: "0 0 1 * *",
  timeZone: TIMEZONE
}, async (event) => {
  await resetScoresForField("scores.monthly");
});

// 4. Friend Request Notifications
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
