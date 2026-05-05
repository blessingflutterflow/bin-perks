import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// Must be top-level — FCM calls this when the app is terminated/background.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage _) async {
  // FCM displays the notification automatically; no processing needed here.
}

class FCMService {
  FCMService._();

  // Set this from main.dart so foreground messages can show a SnackBar.
  static GlobalKey<ScaffoldMessengerState>? messengerKey;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Request permission (required on iOS, prompted on Android 13+).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Store token whenever the auth state changes (login / already signed in).
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveToken(user.uid);
    });

    // Keep the token fresh — FCM rotates it occasionally.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    });

    // Show foreground messages as a SnackBar banner.
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
  }

  // Call this on sign-out so the token is cleared from Firestore.
  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
    }
    await FirebaseMessaging.instance.deleteToken();
  }

  static Future<void> _saveToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  static void _showForegroundBanner(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    messengerKey?.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.title != null)
              Text(
                n.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            if (n.body != null)
              Text(
                n.body!,
                style: const TextStyle(fontSize: 13),
              ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
