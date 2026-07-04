import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'vendor_history_screen.dart';
import 'vendor_reviews_screen.dart';
import '../../theme/app_colors.dart';

class VendorDashboardScreen extends StatelessWidget {
  final VoidCallback? onScanTap;
  const VendorDashboardScreen({super.key, this.onScanTap});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '—';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }


  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, vendorId)),
          SliverToBoxAdapter(child: _buildBillingWarning(vendorId)),
          SliverToBoxAdapter(child: _buildStats(vendorId)),
          SliverToBoxAdapter(child: _buildActivityFeed(vendorId)),
          SliverToBoxAdapter(child: _buildReviews(vendorId)),
          SliverToBoxAdapter(child: _ReviewEditorSection(vendorId: vendorId)),
          SliverToBoxAdapter(child: _buildCooldown(vendorId)),
          SliverToBoxAdapter(child: _buildThankYouDelay(vendorId)),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String? vendorId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('businesses')
                .doc(vendorId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final biz = snap.data?.data() as Map<String, dynamic>?;
        final name = biz?['name'] as String? ?? 'Your Business';

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.primary,
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          color: AppColors.onPrimary.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onScanTap != null)
                  GestureDetector(
                    onTap: onScanTap,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIcons.qrCode(PhosphorIconsStyle.bold),
                        color: AppColors.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Billing Warning ───────────────────────────────────────────────

  Widget _buildBillingWarning(String? vendorId) {
    if (vendorId == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(vendorId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final biz = snap.data?.data() as Map<String, dynamic>? ?? {};
        final subStatus = biz['subscriptionStatus'] as String? ?? 'none';
        final endTs = biz['currentPeriodEnd'] as Timestamp?;
        final daysLeft = endTs != null
            ? endTs.toDate().difference(DateTime.now()).inDays
            : -1;

        if (subStatus == 'active' && daysLeft > 3) return const SizedBox.shrink();

        final isExpired = daysLeft <= 0 || subStatus == 'canceled';
        final bg = isExpired ? Colors.red.shade50 : Colors.orange.shade50;
        final fg = isExpired ? Colors.red.shade800 : Colors.orange.shade800;
        final msg = isExpired
            ? 'Subscription ended — your listing is at risk of suspension.'
            : 'Subscription expires in $daysLeft day${daysLeft == 1 ? '' : 's'}.';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                  color: fg, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(msg,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Stats: today + this month ─────────────────────────────────────

  Widget _buildStats(String? vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('stamps')
                .where('vendorId', isEqualTo: vendorId)
                .snapshots()
          : null,
      builder: (context, stampsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: vendorId != null
              ? FirebaseFirestore.instance
                    .collection('redemptions')
                    .where('vendorId', isEqualTo: vendorId)
                    .snapshots()
              : null,
          builder: (context, redeemSnap) {
            if (stampsSnap.hasError || redeemSnap.hasError) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(
                  'Unable to load stats. Please try again.',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: AppColors.error),
                ),
              );
            }
            final stamps = stampsSnap.data?.docs ?? [];
            final redeems = redeemSnap.data?.docs ?? [];

            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final monthStart = DateTime(now.year, now.month, 1);

            bool inRange(Timestamp? ts, DateTime from, DateTime to) {
              if (ts == null) return false;
              final d = ts.toDate();
              return d.isAfter(from) && d.isBefore(to);
            }

            // Today
            final stampsToday = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, todayStart, now))
                .length;
            final customersToday = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, todayStart, now))
                .map((s) => s['customerId'])
                .toSet()
                .length;

            // This month
            final stampsMonth = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, monthStart, now))
                .length;
            final customersMonth = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, monthStart, now))
                .map((s) => s['customerId'])
                .toSet()
                .length;
            final redeemsMonth = redeems
                .where((r) => inRange(r['redeemedAt'] as Timestamp?, monthStart, now))
                .length;


            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Today snapshot ───────────────────────────────
                  Text('Today',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.onSecondaryContainer,
                      )),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TodayTile(
                          label: 'Stamps',
                          value: stampsToday,
                          icon: PhosphorIcons.stamp(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TodayTile(
                          label: 'Customers',
                          value: customersToday,
                          icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),

                  // ── This month ───────────────────────────────────
                  const SizedBox(height: 20),
                  Text('This Month',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.onSecondaryContainer,
                      )),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        _MonthStat(
                          label: 'Stamps',
                          value: stampsMonth,
                        ),
                        _Divider(),
                        _MonthStat(
                          label: 'Customers',
                          value: customersMonth,
                        ),
                        _Divider(),
                        _MonthStat(
                          label: 'Redeemed',
                          value: redeemsMonth,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Activity Archive Card ─────────────────────────────────────────

  Widget _buildActivityFeed(String? vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('stamps')
                .where('vendorId', isEqualTo: vendorId)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots()
          : null,
      builder: (context, stampsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: vendorId != null
              ? FirebaseFirestore.instance
                    .collection('redemptions')
                    .where('vendorId', isEqualTo: vendorId)
                    .orderBy('redeemedAt', descending: true)
                    .limit(50)
                    .snapshots()
              : null,
          builder: (context, redeemSnap) {
            if (stampsSnap.hasError || redeemSnap.hasError) {
              final err = stampsSnap.error?.toString() ?? redeemSnap.error?.toString() ?? 'Unknown';
              return _Section(
                title: 'Activity Archive',
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: $err\n\nRun: firebase deploy --only firestore:indexes',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.error),
                  ),
                ),
              );
            }
            final events = <_ActivityEvent>[];
            for (final s in stampsSnap.data?.docs ?? []) {
              final d = s.data() as Map<String, dynamic>;
              final ts = d['createdAt'] as Timestamp?;
              if (ts == null) continue;
              events.add(_ActivityEvent(
                type: _EventType.stamp,
                customerId: d['customerId'] as String? ?? '—',
                customerName: d['customerName'] as String?,
                label: 'Stamp #${d['stampNumber'] ?? ''}',
                ts: ts,
                docId: s.id,
              ));
            }
            for (final r in redeemSnap.data?.docs ?? []) {
              final d = r.data() as Map<String, dynamic>;
              final ts = d['redeemedAt'] as Timestamp?;
              if (ts == null) continue;
              events.add(_ActivityEvent(
                type: _EventType.redemption,
                customerId: d['customerId'] as String? ?? '—',
                customerName: d['customerName'] as String?,
                label: d['rewardDescription'] as String? ?? 'Reward redeemed',
                ts: ts,
                docId: r.id,
              ));
            }
            events.sort((a, b) => b.ts.compareTo(a.ts));
            final total = events.length;
            final peek = events.take(2).toList();

            return _ArchiveCard(
              title: 'Activity Archive',
              count: total,
              icon: PhosphorIcons.archive(PhosphorIconsStyle.fill),
              iconColor: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VendorHistoryScreen()),
              ),
              onLongPress: total == 0
                  ? null
                  : () => _showClearDialog(
                        context,
                        title: 'Clear Activity Archive?',
                        message:
                            'This will permanently delete all $total activity records (stamps & redemptions).',
                        onConfirm: () => _clearActivityArchive(vendorId!, events),
                      ),
              child: total == 0
                  ? _emptyState('No activity yet — start scanning customers')
                  : Column(
                      children: [
                        ...peek.map((e) {
                          final isRedeem = e.type == _EventType.redemption;
                          final short = e.customerId.length > 8
                              ? e.customerId.substring(0, 8)
                              : e.customerId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isRedeem
                                        ? const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.12)
                                        : AppColors.primaryContainer
                                            .withValues(alpha: 0.50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isRedeem
                                        ? PhosphorIcons.gift(
                                            PhosphorIconsStyle.fill)
                                        : PhosphorIcons.stamp(
                                            PhosphorIconsStyle.fill),
                                    size: 14,
                                    color: isRedeem
                                        ? const Color(0xFF7C3AED)
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.label,
                                        style: GoogleFonts.beVietnamPro(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        e.customerName ??
                                            'Customer ${short}',
                                        style: GoogleFonts.beVietnamPro(
                                          fontSize: 10,
                                          color: AppColors.onSecondaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _timeAgo(e.ts),
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 10,
                                    color: AppColors.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (total > 2)
                          Center(
                            child: Text(
                              '${total - 2} more in archive',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearActivityArchive(
      String vendorId, List<_ActivityEvent> events) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final e in events) {
        final col = e.type == _EventType.stamp ? 'stamps' : 'redemptions';
        batch.delete(
            FirebaseFirestore.instance.collection(col).doc(e.docId));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing activity archive: $e');
    }
  }

  // ── Reviews Archive Card ──────────────────────────────────────────

  Widget _buildReviews(String? vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('reviews')
                .where('businessId', isEqualTo: vendorId)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots()
          : null,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Section(
            title: 'Reviews Archive',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading reviews: ${snap.error}\n\nCreate a Firestore composite index:\ncollection=reviews, fields=businessId(asc)+createdAt(desc)',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        const emojis = ['😡', '😕', '😐', '🙂', '😍'];
        const labels = ['Awful', 'Bad', 'OK', 'Good', 'Loved it!'];
        final total = docs.length;
        final avg = total > 0
            ? docs
                    .map((d) => ((d.data() as Map<String, dynamic>)['rating'] as num?)?.toInt() ?? 2)
                    .reduce((a, b) => a + b) /
                total
            : 0;
        final peekDocs = docs.take(2).toList();

        return _ArchiveCard(
          title: 'Reviews Archive',
          count: total,
          icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
          iconColor: const Color(0xFF7C3AED),
          subtitle: total > 0
              ? '${avg.toStringAsFixed(1)} avg rating'
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VendorReviewsScreen()),
          ),
          onLongPress: total == 0
              ? null
              : () => _showClearDialog(
                    context,
                    title: 'Clear Reviews Archive?',
                    message:
                        'This will permanently delete all $total reviews.',
                    onConfirm: () => _clearReviewsArchive(vendorId!, docs),
                  ),
          child: total == 0
              ? _emptyState('No reviews yet')
              : Column(
                  children: [
                    ...peekDocs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final rating = (d['rating'] as num?)?.toInt() ?? 2;
                      final safeRating = rating.clamp(0, 4);
                      final ts = d['createdAt'] as Timestamp?;
                      final alreadyFlagged = d['flagged'] as bool? ?? false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(emojis[safeRating],
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final comment = (d['comment'] as String?) ?? '';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(labels[safeRating],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.onSurface,
                                          )),
                                      if (ts != null)
                                        Text(
                                          DateFormat('MMM d').format(ts.toDate()),
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 10,
                                            color: AppColors.onSecondaryContainer,
                                          ),
                                        ),
                                      if (comment.isNotEmpty)
                                        Text(
                                          comment.length > 50
                                              ? '${comment.substring(0, 50)}...'
                                              : comment,
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 10,
                                            color: AppColors.onSecondaryContainer,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: alreadyFlagged
                                  ? null
                                  : () {
                                      FirebaseFirestore.instance
                                          .collection('reviews')
                                          .doc(doc.id)
                                          .update({
                                        'flagged': true,
                                        'flaggedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Review reported for moderation'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                              child: Icon(
                                PhosphorIcons.flag(
                                  alreadyFlagged
                                      ? PhosphorIconsStyle.fill
                                      : PhosphorIconsStyle.regular,
                                ),
                                size: 16,
                                color: alreadyFlagged
                                    ? AppColors.error
                                    : AppColors.onSecondaryContainer
                                        .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (total > 2)
                      Center(
                        child: Text(
                          '${total - 2} more in archive',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _clearReviewsArchive(
      String vendorId, List<QueryDocumentSnapshot> docs) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs) {
        batch.delete(FirebaseFirestore.instance.collection('reviews').doc(doc.id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing reviews archive: $e');
    }
  }

  void _showClearDialog(BuildContext context,
      {required String title,
      required String message,
      required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(message,
            style: GoogleFonts.beVietnamPro(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Delete',
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
  // ── Cooldown Settings ─────────────────────────────────────────────

  Widget _buildCooldown(String? vendorId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('businesses')
                .doc(vendorId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final biz = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabled = biz['cooldownEnabled'] as bool? ?? true;
        final minutes = (biz['cooldownMinutes'] as num?)?.toInt() ?? 60;

        void update(Map<String, dynamic> data) {
          if (vendorId == null) return;
          FirebaseFirestore.instance
              .collection('businesses')
              .doc(vendorId)
              .update(data);
        }

        return _Section(
          title: 'Stamp Cooldown',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prevent back-to-back stamps',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'One stamp per customer per $minutes min',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => update({'cooldownEnabled': v}),
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3, 4, 5, 10, 15, 30, 60, 120].map((m) {
                    final selected = minutes == m;
                    return GestureDetector(
                      onTap: () => update({'cooldownMinutes': m}),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                        ),
                        child: Text(
                          m >= 60 ? '${m ~/ 60}h' : '${m}m',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.onPrimary
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Thank You Notification Delay ─────────────────────────────────

  Widget _buildThankYouDelay(String? vendorId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('businesses')
                .doc(vendorId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final biz = snap.data?.data() as Map<String, dynamic>? ?? {};
        final delaySeconds = (biz['thankYouDelaySeconds'] as num?)?.toInt() ?? 8;

        void update(int seconds) {
          if (vendorId == null) return;
          FirebaseFirestore.instance
              .collection('businesses')
              .doc(vendorId)
              .update({'thankYouDelaySeconds': seconds});
        }

        return _Section(
          title: 'Thank You Notification',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'After scanning a customer, send them a thank-you message after a short delay.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Currently set to $delaySeconds sec after each scan',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [8, 9, 10, 11, 12, 13, 14, 15].map((s) {
                  final selected = delaySeconds == s;
                  return GestureDetector(
                    onTap: () => update(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.outline,
                        ),
                      ),
                      child: Text(
                        '${s}s',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getCustomerName(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        final d = snap.data();
        return (d?['name'] ?? d?['displayName']) as String?;
      }
    } catch (_) {}
    return null;
  }


  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(msg,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: AppColors.onSecondaryContainer),
            textAlign: TextAlign.center),
      );
}

// ── Review Question editor ────────────────────────────────────────────

class _ReviewEditorSection extends StatefulWidget {
  final String? vendorId;
  const _ReviewEditorSection({required this.vendorId});

  @override
  State<_ReviewEditorSection> createState() => _ReviewEditorSectionState();
}

class _ReviewEditorSectionState extends State<_ReviewEditorSection> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  String? _lastLoaded;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = _ctrl.text.trim();
    if (widget.vendorId == null || val.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.vendorId)
          .update({'reviewQuestion': val});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review question updated!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.vendorId != null
          ? FirebaseFirestore.instance
                .collection('businesses')
                .doc(widget.vendorId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final biz = snap.data?.data() as Map<String, dynamic>? ?? {};
        final firestoreQuestion =
            biz['reviewQuestion'] as String? ?? 'How was your visit?';

        // Only sync from Firestore when the value changes and the field isn't focused,
        // so the user's in-progress edits are never overwritten by a stream event.
        if (_lastLoaded != firestoreQuestion && !_focus.hasFocus) {
          _lastLoaded = firestoreQuestion;
          _ctrl.text = firestoreQuestion;
          _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: firestoreQuestion.length),
          );
        }

        return _Section(
          title: 'Review Question',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize the question customers see when leaving a review.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: 'e.g. How was your coffee today?',
                  hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    color: AppColors.onSecondaryContainer.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared section wrapper ────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.onSecondaryContainer,
                  )),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Today tile ────────────────────────────────────────────────────────

class _TodayTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _TodayTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  )),
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    color: AppColors.onSecondaryContainer,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Month stat ────────────────────────────────────────────────────────

class _MonthStat extends StatelessWidget {
  final String label;
  final int value;
  const _MonthStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              )),
          Text(label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                color: AppColors.onSecondaryContainer,
              )),
        ],
      ),
    );
  }
}

// ── Vertical divider ──────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 44,
        color: AppColors.outlineVariant.withValues(alpha: 0.40),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ── Activity event model ──────────────────────────────────────────────

enum _EventType { stamp, redemption }

class _ActivityEvent {
  final _EventType type;
  final String customerId;
  final String? customerName;
  final String label;
  final Timestamp ts;
  final String docId;
  const _ActivityEvent(
      {required this.type,
      required this.customerId,
      this.customerName,
      required this.label,
      required this.ts,
      required this.docId});
}

// ── Archive Summary Card ────────────────────────────────────────────

class _ArchiveCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _ArchiveCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    required this.onTap,
    this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
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
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  color: AppColors.onSecondaryContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 12),
                    child,
                  ] else ...[
                    const SizedBox(height: 12),
                    child,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
