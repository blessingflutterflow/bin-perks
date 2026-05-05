import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_colors.dart';

class VendorScannerScreen extends StatefulWidget {
  const VendorScannerScreen({super.key});

  @override
  State<VendorScannerScreen> createState() => _VendorScannerScreenState();
}

class _VendorScannerScreenState extends State<VendorScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _isRedemption = false;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _result != null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      if (raw.startsWith('BINPERKS_REDEEM_')) {
        final data = raw.replaceFirst('BINPERKS_REDEEM_', '');
        if (data.isEmpty) continue;
        _processRedeem(data);
        break;
      }

      if (raw.startsWith('BINPERKS_USER_')) {
        final data = raw.replaceFirst('BINPERKS_USER_', '');
        if (data.isEmpty) continue;
        _processStamp(data);
        break;
      }
    }
  }

  Future<void> _processStamp(String data) async {
    setState(() { _isProcessing = true; _isRedemption = false; });
    try {
      await _controller.stop();
    } catch (_) {}
    final result = await _awardStamp(data);
    if (mounted) setState(() => _result = result);
  }

  Future<void> _processRedeem(String data) async {
    setState(() { _isProcessing = true; _isRedemption = true; });
    try {
      await _controller.stop();
    } catch (_) {}
    final result = await _redeemReward(data);
    if (mounted) setState(() => _result = result);
  }

  Future<_ScanResult> _redeemReward(String data) async {
    try {
      final parts = data.split('|');
      final customerUid = parts[0];
      final String? customerNameFromQr = parts.length > 1 ? parts[1] : null;

      final vendorUid = FirebaseAuth.instance.currentUser!.uid;
      final loyaltyId = '${customerUid}_$vendorUid';
      final loyaltyRef = FirebaseFirestore.instance
          .collection('loyalties')
          .doc(loyaltyId);

      String rewardDescription = '';
      String businessName = '';

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(loyaltyRef);
        if (!snap.exists) throw _NoLoyaltyException();

        final data = snap.data()!;
        final rewardCount = (data['rewardCount'] as num?)?.toInt() ?? 0;
        final redeemedCount = (data['redeemedCount'] as num?)?.toInt() ?? 0;
        final pending = rewardCount - redeemedCount;

        rewardDescription = data['rewardDescription'] as String? ?? '';
        businessName = data['businessName'] as String? ?? '';

        if (pending <= 0) throw _NoRewardException();

        tx.update(loyaltyRef, {
          'redeemedCount': FieldValue.increment(1),
          'lastRedeemedAt': FieldValue.serverTimestamp(),
        });
      });

      // Fetch customer name if not in QR
      String? customerName = customerNameFromQr;
      if (customerName == null) {
        try {
          final customerSnap = await FirebaseFirestore.instance.collection('users').doc(customerUid).get();
          final d = customerSnap.data();
          customerName = (d?['displayName'] ?? d?['name']) as String?;
        } catch (_) {}
      }

      await FirebaseFirestore.instance.collection('redemptions').add({
        'customerId': customerUid,
        'customerName': customerName,
        'vendorId': vendorUid,
        'businessName': businessName,
        'rewardDescription': rewardDescription,
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      return _ScanResult(
        success: true,
        isRedemption: true,
        message: 'Reward successfully redeemed!',
        rewardDescription: rewardDescription,
      );
    } on _NoLoyaltyException {
      return const _ScanResult(
        success: false,
        message: 'This customer has no loyalty card\nwith your business.',
      );
    } on _NoRewardException {
      return const _ScanResult(
        success: false,
        message: 'No rewards available\nto redeem for this customer.',
      );
    } catch (_) {
      return const _ScanResult(
        success: false,
        message: 'Something went wrong.\nPlease try again.',
      );
    }
  }

  Future<_ScanResult> _awardStamp(String data) async {
    try {
      final parts = data.split('|');
      final customerUid = parts[0];
      final String? customerNameFromQr = parts.length > 1 ? parts[1] : null;

      final vendorUid = FirebaseAuth.instance.currentUser!.uid;

      // Read business doc for reward config and cooldown settings
      final bizSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(vendorUid)
          .get();
      if (!bizSnap.exists) throw Exception('Business not found');
      final biz = bizSnap.data()!;
      final stampGoal = (biz['stampGoal'] as num?)?.toInt() ?? 10;
      final rewardDescription = biz['rewardDescription'] as String? ?? '';
      final businessName = biz['name'] as String? ?? '';
      final businessCategory = biz['category'] as String? ?? '';
      final businessImageUrl = biz['imageUrl'] as String?;
      // Cooldown settings (defaults: enabled, 60 minutes)
      final cooldownEnabled = biz['cooldownEnabled'] as bool? ?? true;
      final cooldownMinutes = (biz['cooldownMinutes'] as num?)?.toInt() ?? 60;

      final loyaltyId = '${customerUid}_$vendorUid';
      final loyaltyRef = FirebaseFirestore.instance
          .collection('loyalties')
          .doc(loyaltyId);

      int newStampCount = 0;
      bool rewardEarned = false;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(loyaltyRef);
        final now = DateTime.now();

        if (snap.exists) {
          final data = snap.data()!;
          final lastStamp = (data['lastStampAt'] as Timestamp?)?.toDate();
          // Check cooldown if enabled
          if (cooldownEnabled &&
              lastStamp != null &&
              now.difference(lastStamp).inMinutes < cooldownMinutes) {
            throw _CooldownException();
          }
          final current = (data['stampCount'] as num?)?.toInt() ?? 0;
          final rewards = (data['rewardCount'] as num?)?.toInt() ?? 0;
          newStampCount = current + 1;

          if (newStampCount >= stampGoal) {
            rewardEarned = true;
            tx.update(loyaltyRef, {
              'stampCount': 0,
              'rewardCount': rewards + 1,
              'lastStampAt': FieldValue.serverTimestamp(),
              'stampGoal': stampGoal,
              'rewardDescription': rewardDescription,
            });
          } else {
            tx.update(loyaltyRef, {
              'stampCount': newStampCount,
              'lastStampAt': FieldValue.serverTimestamp(),
              'stampGoal': stampGoal,
              'rewardDescription': rewardDescription,
            });
          }
        } else {
          // Auto-join: create loyalty doc on first scan
          newStampCount = 1;
          tx.set(loyaltyRef, {
            'customerId': customerUid,
            'businessId': vendorUid,
            'businessName': businessName,
            'businessCategory': businessCategory,
            'businessImageUrl': businessImageUrl,
            'stampCount': 1,
            'stampGoal': stampGoal,
            'rewardDescription': rewardDescription,
            'rewardCount': 0,
            'lastStampAt': FieldValue.serverTimestamp(),
            'joinedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Fetch customer name if not in QR
      String? customerName = customerNameFromQr;
      if (customerName == null) {
        try {
          final customerSnap = await FirebaseFirestore.instance.collection('users').doc(customerUid).get();
          final d = customerSnap.data();
          customerName = (d?['displayName'] ?? d?['name']) as String?;
        } catch (_) {}
      }

      // Write stamp record to stamps collection for dashboard tracking
      final stampRef = FirebaseFirestore.instance.collection('stamps').doc();
      await stampRef.set({
        'customerId': customerUid,
        'customerName': customerName,
        'vendorId': vendorUid,
        'businessName': businessName,
        'stampNumber': newStampCount,
        'createdAt': FieldValue.serverTimestamp(),
        'scannedBy': vendorUid,
      });

      // Update business total stamps
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(vendorUid)
          .update({'totalStamps': FieldValue.increment(1)});

      // If reward earned, create reward record
      if (rewardEarned) {
        final rewardRef = FirebaseFirestore.instance
            .collection('rewards')
            .doc();
        await rewardRef.set({
          'customerId': customerUid,
          'customerName': customerName,
          'vendorId': vendorUid,
          'businessName': businessName,
          'rewardDescription': rewardDescription,
          'status': 'issued',
          'createdAt': FieldValue.serverTimestamp(),
          'redeemedAt': null,
        });

        return _ScanResult(
          success: true,
          isReward: true,
          stampCount: stampGoal,
          rewardDescription: rewardDescription,
          message: 'Customer completed their card!',
        );
      }
      return _ScanResult(
        success: true,
        stampCount: newStampCount,
        message: 'Stamp $newStampCount of $stampGoal recorded.',
      );
    } on _CooldownException {
      return const _ScanResult(
        success: false,
        isCooldown: true,
        message:
            'This customer was stamped less than\nan hour ago. Come back later!',
      );
    } catch (_) {
      return const _ScanResult(
        success: false,
        message: 'Something went wrong.\nPlease try again.',
      );
    }
  }

  Future<void> _reset() async {
    setState(() {
      _result = null;
      _isProcessing = false;
    });
    try {
      await _controller.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          if (_result == null)
            LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    math.min(constraints.maxWidth, constraints.maxHeight) *
                    0.68;
                final scanWindow = Rect.fromCenter(
                  center: Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight * 0.44,
                  ),
                  width: size,
                  height: size,
                );
                return Stack(
                  children: [
                    CustomPaint(
                      painter: _OverlayPainter(scanWindow: scanWindow),
                      child: const SizedBox.expand(),
                    ),
                    if (!_isProcessing)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: scanWindow.bottom + 28,
                        child: Text(
                          'Point at the customer\'s QR code',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isProcessing)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: scanWindow.bottom + 24,
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isRedemption
                                  ? 'Redeeming reward…'
                                  : 'Awarding stamp…',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),

          if (_result != null)
            _ResultOverlay(result: _result!, onDismiss: _reset),

          if (_result == null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  'Scan Customer QR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Overlay painter ──────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Rect scanWindow;
  const _OverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final windowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, bgPath, windowPath),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    final l = scanWindow.left;
    final t = scanWindow.top;
    final r = scanWindow.right;
    final b = scanWindow.bottom;

    canvas
      ..drawLine(Offset(l, t + len), Offset(l, t), p)
      ..drawLine(Offset(l, t), Offset(l + len, t), p)
      ..drawLine(Offset(r - len, t), Offset(r, t), p)
      ..drawLine(Offset(r, t), Offset(r, t + len), p)
      ..drawLine(Offset(l, b - len), Offset(l, b), p)
      ..drawLine(Offset(l, b), Offset(l + len, b), p)
      ..drawLine(Offset(r - len, b), Offset(r, b), p)
      ..drawLine(Offset(r, b - len), Offset(r, b), p);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.scanWindow != scanWindow;
}

// ── Data types ────────────────────────────────────────────────────

class _ScanResult {
  final bool success;
  final bool isCooldown;
  final bool isReward;
  final bool isRedemption;
  final int stampCount;
  final String message;
  final String rewardDescription;

  const _ScanResult({
    required this.success,
    this.isCooldown = false,
    this.isReward = false,
    this.isRedemption = false,
    this.stampCount = 0,
    required this.message,
    this.rewardDescription = '',
  });
}

class _CooldownException implements Exception {}
class _NoLoyaltyException implements Exception {}
class _NoRewardException implements Exception {}

// ── Result overlay ───────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onDismiss;
  const _ResultOverlay({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.success;
    final isCooldown = result.isCooldown;
    final isReward = result.isReward;
    final isRedemption = result.isRedemption;

    final bgColor = isSuccess
        ? isRedemption
              ? const Color(0xFF2D0A6B)
              : isReward
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF00875A)
        : isCooldown
        ? const Color(0xFFB45309)
        : AppColors.error;

    final icon = isSuccess
        ? isReward
              ? PhosphorIcons.gift(PhosphorIconsStyle.fill)
              : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
        : isCooldown
        ? PhosphorIcons.clock(PhosphorIconsStyle.fill)
        : PhosphorIcons.xCircle(PhosphorIconsStyle.fill);

    final title = isSuccess
        ? isRedemption
              ? 'Reward Redeemed!'
              : isReward
                    ? 'Reward Earned!'
                    : 'Stamp Awarded!'
        : isCooldown
        ? 'Cooldown Active'
        : 'Scan Failed';

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 88),
              const SizedBox(height: 22),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.message,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (isSuccess &&
                  (isReward || isRedemption) &&
                  result.rewardDescription.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    result.rewardDescription,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (isSuccess && !isReward && !isRedemption) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'Stamp #${result.stampCount}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 44),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    isSuccess ? 'Scan Next' : 'Try Again',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: bgColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
