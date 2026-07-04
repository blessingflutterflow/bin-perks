const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// NOTE: Set this secret in Firebase using `firebase functions:secrets:set YOCO_SECRET_KEY`
// or hardcode it for development.
const YOCO_SECRET_KEY = process.env.YOCO_SECRET_KEY || "sk_test_8b22aead6mMQK1E598840429cc02";

// 1. Generate Yoco Link
exports.generateYocoLink = onRequest({ cors: true }, async (req, res) => {
  try {
    const { vendorId, planId, price } = req.body;
    
    if (!vendorId || !planId || !price) {
      return res.status(400).send({ error: "Missing required fields" });
    }

    // Yoco API expects amounts in cents
    const amountInCents = Math.round(price * 100);

    const response = await fetch("https://payments.yoco.com/api/checkouts", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${YOCO_SECRET_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        amount: amountInCents,
        currency: "ZAR",
        metadata: {
          vendorId: vendorId,
          planId: planId
        }
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      logger.error("Yoco API error:", errText);
      return res.status(500).send({ error: "Failed to generate Yoco link" });
    }

    const data = await response.json();
    return res.json({ paymentUrl: data.redirectUrl, id: data.id });
  } catch (error) {
    logger.error("Error in generateYocoLink:", error);
    return res.status(500).send({ error: "Internal Server Error" });
  }
});

// 2. Yoco Webhook Listener
exports.yocoWebhook = onRequest({ cors: true }, async (req, res) => {
  try {
    const event = req.body;
    logger.info("Received Yoco webhook:", event);

    if (event.type === 'payment.succeeded') {
      const payload = event.payload || {};
      const metadata = payload.metadata || {};
      
      const vendorId = metadata.vendorId;
      const planId = metadata.planId;
      const amount = (payload.amount || 0) / 100;
      const paymentId = event.id;

      if (vendorId) {
        // Record the payment in Firestore
        await admin.firestore().collection("payments").doc(paymentId).set({
          businessId: vendorId,
          amount: amount,
          status: "successful",
          planId: planId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          rawEvent: event
        });

        // Add 30 days to the vendor's subscription
        const bizRef = admin.firestore().collection("businesses").doc(vendorId);
        const bizSnap = await bizRef.get();
        
        let newEnd;
        if (bizSnap.exists) {
          const data = bizSnap.data();
          const now = new Date();
          
          if (data.currentPeriodEnd && data.currentPeriodEnd.toDate() > now) {
            newEnd = new Date(data.currentPeriodEnd.toDate().getTime() + 30 * 24 * 60 * 60 * 1000);
          } else {
            newEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
          }
          
          await bizRef.update({
            subscriptionStatus: 'active',
            currentPeriodEnd: admin.firestore.Timestamp.fromDate(newEnd),
            planId: planId
          });
          
          logger.info(`Successfully extended subscription for vendor ${vendorId}`);
        }
      }
    }
    
    // Always return 200 OK to acknowledge receipt to Yoco
    res.status(200).send("OK");
  } catch (error) {
    logger.error("Error in yocoWebhook:", error);
    res.status(500).send("Internal Server Error");
  }
});

// Shared helper — schedules a delayed thank-you notification for a stamp event.
// The FCM token is intentionally NOT stored here — it is fetched fresh at send
// time so a token rotation between scheduling and delivery doesn't silently drop
// the notification.
async function scheduleThankYouNotification({ customerId, businessName, stampCount, stampGoal }) {
  const thankYouDelayMinutes = 2;
  const sendAt = new Date(Date.now() + thankYouDelayMinutes * 60 * 1000);
  await admin.firestore().collection("scheduledNotifications").add({
    customerId,
    businessName,
    stampCount,
    stampGoal,
    sendAt: admin.firestore.Timestamp.fromDate(sendAt),
    sent: false,
    retryCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// 3a. First stamp — loyalty doc is created (tx.set), not updated.
exports.onLoyaltyCreated = onDocumentCreated("loyalties/{loyaltyId}", async (event) => {
  const data = event.data.data();
  if (!data) return;

  const stampCount = data.stampCount || 0;
  if (stampCount === 0) return; // safety guard

  try {
    await scheduleThankYouNotification({
      customerId:   data.customerId,
      businessName: data.businessName || "the business",
      stampCount,
      stampGoal:    data.stampGoal || 10,
    });
  } catch (err) {
    logger.error("Failed to schedule thank-you notification (create):", err);
  }
});

// 3b. Subsequent stamps — loyalty doc is updated.
exports.onLoyaltyStampAwarded = onDocumentUpdated("loyalties/{loyaltyId}", async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  // Only fire when stampCount increased
  const prevStamps = before.stampCount || 0;
  const newStamps  = after.stampCount  || 0;
  if (newStamps <= prevStamps) return;

  try {
    await scheduleThankYouNotification({
      customerId:   after.customerId,
      businessName: after.businessName || "the business",
      stampCount:   newStamps,
      stampGoal:    after.stampGoal || 10,
    });
  } catch (err) {
    logger.error("Failed to schedule thank-you notification (update):", err);
  }
});

const STALE_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);
const MAX_RETRIES = 3;

// 4a. Process scheduled thank-you notifications every minute
exports.processScheduledNotifications = onSchedule("* * * * *", async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await admin.firestore()
    .collection("scheduledNotifications")
    .where("sendAt", "<=", now)
    .where("sent", "==", false)
    .get();

  if (snap.empty) return;

  const sends = snap.docs.map(async (doc) => {
    const { customerId, businessName, stampCount, stampGoal, retryCount = 0, createdAt } = doc.data();

    // Expire notifications older than 24 hours so stale docs don't accumulate.
    const createdMs = createdAt?.toDate?.()?.getTime() ?? 0;
    if (Date.now() - createdMs > 24 * 60 * 60 * 1000) {
      await doc.ref.update({ sent: true });
      logger.info("Notification expired (>24 h), discarding:", doc.id);
      return;
    }

    // Abandon after too many failed attempts so the cron doesn't loop forever.
    if (retryCount >= MAX_RETRIES) {
      await doc.ref.update({ sent: true });
      logger.warn("Abandoning notification after max retries:", doc.id);
      return;
    }

    // Fetch the freshest token at send time — avoids stale-token failures caused
    // by FCM rotating the token in the window between scheduling and delivery.
    const userDoc = await admin.firestore().collection("users").doc(customerId).get();
    const userData = userDoc.data() || {};
    const fcmToken = userData.fcmToken;

    // Presence check — hold the push while the customer is actively in the app.
    // The Flutter heartbeat updates lastActiveAt every 2 minutes; we allow a
    // 1-minute buffer for cron/network lag before declaring a force-kill.
    const isOnline = userData.isOnline === true;
    const lastActiveAt = userData.lastActiveAt?.toDate?.();
    const minutesSinceActive = lastActiveAt
      ? (Date.now() - lastActiveAt.getTime()) / 60000
      : 999;
    const STALE_PRESENCE_MINUTES = 3;
    const customerInApp = isOnline && minutesSinceActive < STALE_PRESENCE_MINUTES;

    if (customerInApp) {
      // Customer is still in the app — the in-app popup already showed.
      // Hold the FCM push; the next cron run (1 minute away) will try again.
      return;
    }

    if (!fcmToken) {
      await doc.ref.update({ sent: true });
      logger.warn("No FCM token for user, discarding notification:", customerId);
      return;
    }

    let notifTitle, notifBody;
    if (stampCount >= stampGoal) {
      notifTitle = `Thanks for visiting ${businessName}!`;
      notifBody  = `Your reward is ready to claim! Come back and enjoy it.`;
    } else {
      const left = stampGoal - stampCount;
      notifTitle = `Thanks for visiting ${businessName}!`;
      notifBody  = `You have ${stampCount}/${stampGoal} stamps — ${left} more stamp${left === 1 ? "" : "s"} until your reward!`;
    }

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title: notifTitle, body: notifBody },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      });
      // Only mark sent after FCM confirms delivery.
      await doc.ref.update({ sent: true });
    } catch (err) {
      if (STALE_TOKEN_ERRORS.has(err.code)) {
        // Token is permanently dead — remove it from Firestore and discard.
        logger.warn("Stale FCM token, removing from user record:", customerId);
        await admin.firestore().collection("users").doc(customerId)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
        await doc.ref.update({ sent: true });
      } else {
        // Transient error — increment retry count and let the next cron attempt it.
        logger.error("FCM send failed, will retry:", err);
        await doc.ref.update({ retryCount: retryCount + 1 });
      }
    }
  });

  await Promise.all(sends);
});

// 5. Send a promotion notification to all customers of a business
exports.sendPromotion = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new Error("Unauthenticated");

  const { businessId, title, message } = request.data;
  if (!businessId || !title || !message) throw new Error("Missing required fields");
  if (uid !== businessId) throw new Error("Unauthorized");

  // Find all loyalty customers for this business
  const loyaltiesSnap = await admin.firestore()
    .collection("loyalties")
    .where("businessId", "==", businessId)
    .get();

  if (loyaltiesSnap.empty) return { sent: 0, total: 0 };

  // Collect unique customer IDs
  const customerIds = [...new Set(
    loyaltiesSnap.docs.map(d => d.data().customerId).filter(Boolean)
  )];

  // Fetch FCM tokens, keep a map so we can clean up stale ones
  const userDocs = await Promise.all(
    customerIds.map(id => admin.firestore().collection("users").doc(id).get())
  );
  const tokenMap = [];
  userDocs.forEach((doc, i) => {
    const token = doc.data()?.fcmToken;
    if (token) tokenMap.push({ token, customerId: customerIds[i] });
  });

  let successCount = 0;
  if (tokenMap.length > 0) {
    const result = await admin.messaging().sendEachForMulticast({
      tokens: tokenMap.map(t => t.token),
      notification: { title, body: message },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
    successCount = result.successCount;

    // Clean up permanently dead tokens
    result.responses.forEach((resp, idx) => {
      if (!resp.success && STALE_TOKEN_ERRORS.has(resp.error?.code)) {
        admin.firestore().collection("users").doc(tokenMap[idx].customerId)
          .update({ fcmToken: admin.firestore.FieldValue.delete() })
          .catch(() => {});
      }
    });
  }

  // Save to promotion history
  await admin.firestore().collection("promotions").add({
    businessId,
    title,
    message,
    sentTo: successCount,
    totalCustomers: tokenMap.length,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { sent: successCount, total: tokenMap.length };
});

// 4b. Notify admins when a new vendor application arrives
exports.onNewVendorPending = onDocumentCreated("businesses/{businessId}", async (event) => {
  const data = event.data.data();
  if (data.status !== "pending") return;

  const businessName = data.name || "A new business";

  const adminsSnap = await admin.firestore()
    .collection("users")
    .where("role", "==", "admin")
    .get();

  const tokens = adminsSnap.docs
    .map(doc => doc.data().fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) return;

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New Vendor Application",
        body: `${businessName} is waiting for your approval.`,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (err) {
    logger.error("FCM send failed for vendor notification:", err);
  }
});
