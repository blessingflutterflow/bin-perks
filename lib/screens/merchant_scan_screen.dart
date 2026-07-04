import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

class MerchantScanScreen extends StatefulWidget {
  const MerchantScanScreen({super.key});

  @override
  State<MerchantScanScreen> createState() => _MerchantScanScreenState();
}

class _MerchantScanScreenState extends State<MerchantScanScreen> {
  String? _userName;

  String get _qrValue {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unknown';
    final name = _userName ?? user?.displayName ?? 'Customer';
    return 'BINPERKS_USER_${uid}|${name}';
  }
  static const int _timerSeconds = 300; // 5 minutes

  Timer? _countdownTimer;
  int _remaining = _timerSeconds;
  bool _expired = false;
  double _previousBrightness = 0.5;

  String get _formattedTime {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _setMaxBrightness();
    _startTimer();
    _loadName();
  }

  Future<void> _loadName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists && mounted) {
        final data = snap.data();
        setState(() {
          _userName = (data?['name'] ?? data?['displayName']) as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _setMaxBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(_previousBrightness);
    } catch (_) {}
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _countdownTimer?.cancel();
        setState(() => _expired = true);
      }
    });
  }

  void _refresh() {
    setState(() {
      _expired = false;
      _remaining = _timerSeconds;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topPad + 40,
                    left: 24,
                    right: 24,
                    bottom: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Your QR Code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Show this to the merchant to earn perks.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSecondaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── QR Code Banner ────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.inverseSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Tap to copy',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inverseOnSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _expired
                                ? AppColors.error
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _expired
                                    ? PhosphorIcons.warning(PhosphorIconsStyle.fill)
                                    : PhosphorIcons.clock(PhosphorIconsStyle.fill),
                                color: AppColors.onPrimary,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _expired ? 'Expired' : _formattedTime,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _expired
                          ? _refresh
                          : () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _qrValue));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'QR Value copied!',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: AppColors.inverseSurface,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: ColorFiltered(
                              colorFilter: _expired
                                  ? const ColorFilter.matrix([
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0,      0,      0,      1, 0,
                                    ])
                                  : const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    ),
                              child: QrImageView(
                                data: _qrValue,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                          if (_expired)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              width: 224,
                              height: 224,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.arrowCounterClockwise(
                                        PhosphorIconsStyle.bold),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Expired',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to refresh',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Raw code ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.inverseOnSurface.withOpacity(0.15),
                        ),
                      ),
                      child: SelectableText(
                        _qrValue,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.inverseOnSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Share button ──────────────────────────────────
              GestureDetector(
                onTap: () => Share.share(_qrValue),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                        color: AppColors.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Send Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
},
),
);
}
}
