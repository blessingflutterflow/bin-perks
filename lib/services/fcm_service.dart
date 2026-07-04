import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'sound_service.dart';

// Tracks app foreground/background state for presence-aware push notifications.
// Refreshes the FCM token on resume and writes isOnline + lastActiveAt to
// Firestore so the Cloud Function knows whether to send or hold the push.
class _FCMLifecycleObserver with WidgetsBindingObserver {
  Timer? _heartbeat;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (state == AppLifecycleState.resumed) {
      if (uid != null) {
        FCMService._saveToken(uid);
        FCMService._setPresence(uid, online: true);
      }
      // Heartbeat keeps lastActiveAt fresh so force-kills are detected within
      // ~3 minutes (heartbeat every 2 min + 1 min cron buffer).
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(minutes: 2), (_) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) FCMService._refreshLastActive(currentUid);
      });
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached) {
      _heartbeat?.cancel();
      _heartbeat = null;
      if (uid != null) FCMService._setPresence(uid, online: false);
    }
    // AppLifecycleState.inactive is transient (incoming call, notification shade)
    // — ignore it so we don't flip presence for a split second.
  }
}

// Reward gift icon — purple circle with white gift, matches the app's reward icon.
class _GiftBoxIcon extends StatelessWidget {
  const _GiftBoxIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFF7C3AED),
        shape: BoxShape.circle,
      ),
      child: Icon(
        PhosphorIcons.gift(PhosphorIconsStyle.fill),
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

// Must be top-level — FCM calls this when the app is terminated/background.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage _) async {
  // FCM displays the notification automatically; no processing needed here.
}

class FCMService {
  FCMService._();

  static GlobalKey<ScaffoldMessengerState>? messengerKey;
  static GlobalKey<NavigatorState>? navigatorKey;

  static StreamSubscription? _stampWatcher;
  static final Map<String, int> _lastStampCounts = {};
  static String? _watchingUid;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Refresh the FCM token whenever the app resumes from background.
    WidgetsBinding.instance.addObserver(_FCMLifecycleObserver());

    // Request permission (required on iOS, prompted on Android 13+).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Store token and start stamp watcher when user logs in.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _saveToken(user.uid);
        _startStampWatcher(user.uid);
      } else {
        _stopStampWatcher();
      }
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

  }

  // Watches the customer's loyalty cards. When stamp count goes up,
  // fetches the vendor's configured delay and shows the thank-you popup.
  static void _startStampWatcher(String uid) {
    // Don't restart if already watching for the same user.
    if (_watchingUid == uid && _stampWatcher != null) return;
    _watchingUid = uid;
    _stampWatcher?.cancel();
    _lastStampCounts.clear();

    _stampWatcher = FirebaseFirestore.instance
        .collection('loyalties')
        .where('customerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final loyaltyId = change.doc.id;
        final currentStamps = (data['stampCount'] as num?)?.toInt() ?? 0;
        final prevStamps = _lastStampCounts[loyaltyId];

        _lastStampCounts[loyaltyId] = currentStamps;

        // Only fire when stamps actually increased, not on initial load.
        if (prevStamps != null && currentStamps > prevStamps) {
          final businessName = data['businessName'] as String? ?? 'the business';
          final stampGoal = (data['stampGoal'] as num?)?.toInt() ?? 10;
          final businessId = data['businessId'] as String?;

          int delaySeconds = 8;
          if (businessId != null) {
            try {
              final bizSnap = await FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .get();
              delaySeconds =
                  (bizSnap.data()?['thankYouDelaySeconds'] as num?)?.toInt() ?? 8;
            } catch (_) {}
          }

          _showThankYouCard(businessName, currentStamps, stampGoal, delaySeconds);
        }
      }
    });
  }

  static void _stopStampWatcher() {
    _stampWatcher?.cancel();
    _stampWatcher = null;
    _lastStampCounts.clear();
    _watchingUid = null;
  }

  // Call this on sign-out so the token and presence are cleared from Firestore.
  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete(), 'isOnline': false});
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

  static Future<void> _setPresence(String uid, {required bool online}) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isOnline': online,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _refreshLastActive(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _showThankYouCard(
      String businessName, int stampCount, int stampGoal, int delaySeconds) async {
    await Future.delayed(Duration(seconds: delaySeconds));

    final context = navigatorKey?.currentContext;
    if (context == null) return;

    SoundService().playBellSound();

    final title = 'Thanks for visiting $businessName!';
    final String body;
    if (stampCount >= stampGoal) {
      body = 'Your reward is ready to claim! Come back and enjoy it.';
    } else {
      final left = stampGoal - stampCount;
      body = 'You have $stampCount/$stampGoal stamps — $left more stamp${left == 1 ? '' : 's'} until your reward!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFCC0000),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.40),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top row: bell left, X right ──────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.bell(PhosphorIconsStyle.fill),
                    color: const Color(0xFFFFD700),
                    size: 38,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Title ────────────────────────────────────────
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              // ── Body + gift box ──────────────────────────────
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: body,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.92),
                        height: 1.55,
                      ),
                    ),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _GiftBoxIcon(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
