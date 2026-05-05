const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
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

// 3. Notify customer when a stamp is awarded
exports.onLoyaltyStampAwarded = onDocumentUpdated("loyalties/{loyaltyId}", async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  // Only fire when stampCount increased
  const prevStamps = before.stampCount || 0;
  const newStamps  = after.stampCount  || 0;
  if (newStamps <= prevStamps) return;

  const customerId  = after.customerId;
  const businessName = after.businessName || "the business";
  const stampGoal   = after.stampGoal || 10;

  // Fetch the customer's FCM token
  const userDoc  = await admin.firestore().collection("users").doc(customerId).get();
  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) return;

  let title, body;
  if (newStamps >= stampGoal) {
    title = "🎁 Reward Ready!";
    body  = `Your reward at ${businessName} is ready to claim!`;
  } else {
    const left = stampGoal - newStamps;
    title = `Stamped at ${businessName}!`;
    body  = `${left} more stamp${left === 1 ? "" : "s"} until your reward.`;
  }

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (err) {
    logger.error("FCM send failed for stamp notification:", err);
  }
});

// 4. Notify admins when a new vendor application arrives
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
