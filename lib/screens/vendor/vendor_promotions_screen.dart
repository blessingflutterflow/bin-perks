import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class VendorPromotionsScreen extends StatefulWidget {
  const VendorPromotionsScreen({super.key});

  @override
  State<VendorPromotionsScreen> createState() => _VendorPromotionsScreenState();
}

class _VendorPromotionsScreenState extends State<VendorPromotionsScreen> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in both title and message'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return;

    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendPromotion');
      final result = await callable.call({
        'businessId': vendorId,
        'title': title,
        'message': message,
      });

      final sent = result.data['sent'] ?? 0;
      final total = result.data['total'] ?? 0;

      if (mounted) {
        _titleCtrl.clear();
        _msgCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            total == 0
                ? 'No customers with the app installed yet'
                : 'Sent to $sent of $total customers',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: total == 0 ? AppColors.error : const Color(0xFF00875A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to send. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.primary,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Text(
              'Send Promotion',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: vendorId == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(vendorId)
                      .snapshots(),
              builder: (context, bizSnap) {
                final bizData = bizSnap.data?.data() as Map<String, dynamic>?;
                final promoEnabled = bizData?['promotionsEnabled'] != false;
                final promoReason =
                    bizData?['promotionsDisabledReason'] as String? ?? '';
                return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Disabled-by-admin banner ─────────────────────
                  if (!promoEnabled) ...[
                    _DisabledBanner(reason: promoReason),
                    const SizedBox(height: 16),
                  ],
                  // ── Compose card ─────────────────────────────────
                  Opacity(
                    opacity: promoEnabled ? 1 : 0.5,
                    child: IgnorePointer(
                      ignoring: !promoEnabled,
                      child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Create Notification',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Title field
                        Text(
                          'Title *',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder(
                          valueListenable: _titleCtrl,
                          builder: (_, __, ___) => TextField(
                            controller: _titleCtrl,
                            maxLength: 50,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'e.g. Lunch Special Today!',
                              hintStyle: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                color: AppColors.onSecondaryContainer
                                    .withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              counterText: '${_titleCtrl.text.length}/50',
                              counterStyle: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                color: AppColors.onSecondaryContainer,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withValues(alpha: 0.4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withValues(alpha: 0.4)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Message field
                        Text(
                          'Message *',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder(
                          valueListenable: _msgCtrl,
                          builder: (_, __, ___) => TextField(
                            controller: _msgCtrl,
                            maxLength: 200,
                            maxLines: 4,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. R15.99 Lunch Special — Today Only!',
                              hintStyle: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                color: AppColors.onSecondaryContainer
                                    .withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              counterText: '${_msgCtrl.text.length}/200',
                              counterStyle: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                color: AppColors.onSecondaryContainer,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withValues(alpha: 0.4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withValues(alpha: 0.4)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Send button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(
                                    PhosphorIcons.paperPlaneTilt(
                                        PhosphorIconsStyle.fill),
                                    size: 18,
                                  ),
                            label: Text(
                              _sending ? 'Sending...' : 'Send to All Customers',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── History section ───────────────────────────────
                  Text(
                    'SENT PROMOTIONS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PromotionHistory(),
                  const SizedBox(height: 120),
                ],
              ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Promotion history list ────────────────────────────────────────────

class _PromotionHistory extends StatelessWidget {
  const _PromotionHistory();

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promotions')
          .where('businessId', isEqualTo: vendorId)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final docs = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.light),
                      size: 40, color: AppColors.outline),
                  const SizedBox(height: 10),
                  Text(
                    'No promotions sent yet',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final ts = (d['createdAt'] as Timestamp?)?.toDate();
            final timeStr = ts != null
                ? DateFormat('d MMM yyyy • HH:mm').format(ts)
                : '—';
            final sentTo = d['sentTo'] ?? 0;
            final total = d['totalCustomers'] ?? sentTo;

            return Dismissible(
              key: ValueKey(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                    color: Colors.white, size: 22),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Delete promotion?',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800)),
                    content: Text(
                      'This will permanently remove "${d['title']}" from your history.',
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: GoogleFonts.beVietnamPro(
                                color: AppColors.onSecondaryContainer)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Delete',
                            style: GoogleFonts.beVietnamPro(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (_) => doc.reference.delete(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            d['message'] ?? '',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              color: AppColors.onSecondaryContainer,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            timeStr,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              color: AppColors.onSecondaryContainer
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '← Swipe to delete',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSecondaryContainer
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            '$sentTo/$total',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Delete promotion?',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800)),
                                content: Text(
                                  'This will permanently remove "${d['title']}" from your history.',
                                  style: GoogleFonts.beVietnamPro(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel',
                                        style: GoogleFonts.beVietnamPro(
                                            color: AppColors.onSecondaryContainer)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Delete',
                                        style: GoogleFonts.beVietnamPro(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) doc.reference.delete();
                          },
                          child: Icon(PhosphorIcons.trash(),
                              size: 18,
                              color: AppColors.onSecondaryContainer
                                  .withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Admin-disabled banner ─────────────────────────────────────────────

class _DisabledBanner extends StatelessWidget {
  final String reason;
  const _DisabledBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
              color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promotions disabled by the administrator',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You cannot send new promotions right now. Your past promotions are still shown below.',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.onSurface,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REASON',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reason,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
