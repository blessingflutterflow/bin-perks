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

  String _trend(int current, int previous) {
    if (previous == 0) return current > 0 ? '↑ new' : '—';
    final pct = ((current - previous) / previous * 100).round();
    return pct >= 0 ? '↑ $pct%' : '↓ ${pct.abs()}%';
  }

  Color _trendColor(int current, int previous) {
    if (previous == 0) return AppColors.onSecondaryContainer;
    return current >= previous ? const Color(0xFF00875A) : AppColors.error;
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
          SliverToBoxAdapter(child: _buildReviewEditor(vendorId)),
          SliverToBoxAdapter(child: _buildCooldown(vendorId)),
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
            final stamps = stampsSnap.data?.docs ?? [];
            final redeems = redeemSnap.data?.docs ?? [];

            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final monthStart = DateTime(now.year, now.month, 1);
            final lastMonthStart = DateTime(now.year, now.month - 1, 1);
            final lastMonthEnd = monthStart.subtract(const Duration(seconds: 1));

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

            // Last month (for trend)
            final stampsLast = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, lastMonthStart, lastMonthEnd))
                .length;
            final customersLast = stamps
                .where((s) => inRange(s['createdAt'] as Timestamp?, lastMonthStart, lastMonthEnd))
                .map((s) => s['customerId'])
                .toSet()
                .length;
            final redeemsLast = redeems
                .where((r) => inRange(r['redeemedAt'] as Timestamp?, lastMonthStart, lastMonthEnd))
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
                          trend: _trend(stampsMonth, stampsLast),
                          trendColor: _trendColor(stampsMonth, stampsLast),
                        ),
                        _Divider(),
                        _MonthStat(
                          label: 'Customers',
                          value: customersMonth,
                          trend: _trend(customersMonth, customersLast),
                          trendColor: _trendColor(customersMonth, customersLast),
                        ),
                        _Divider(),
                        _MonthStat(
                          label: 'Redeemed',
                          value: redeemsMonth,
                          trend: _trend(redeemsMonth, redeemsLast),
                          trendColor: _trendColor(redeemsMonth, redeemsLast),
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

  // ── Unified Activity Feed ─────────────────────────────────────────

  Widget _buildActivityFeed(String? vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('stamps')
                .where('vendorId', isEqualTo: vendorId)
                .orderBy('createdAt', descending: true)
                .limit(15)
                .snapshots()
          : null,
      builder: (context, stampsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: vendorId != null
              ? FirebaseFirestore.instance
                    .collection('redemptions')
                    .where('vendorId', isEqualTo: vendorId)
                    .orderBy('redeemedAt', descending: true)
                    .limit(15)
                    .snapshots()
              : null,
          builder: (context, redeemSnap) {
            // Build a unified list of activity events
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
              ));
            }

            events.sort((a, b) => b.ts.compareTo(a.ts));
            final recent = events.take(10).toList();
            return _Section(
              title: 'Recent Activity',
              trailing: recent.isNotEmpty
                  ? GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VendorHistoryScreen()),
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
              child: recent.isEmpty
                  ? _emptyState('No activity yet — start scanning customers')
                  : Column(
                      children: recent.map((e) {
                        final isRedeem = e.type == _EventType.redemption;
                        final short = e.customerId.length > 8
                            ? e.customerId.substring(0, 8)
                            : e.customerId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isRedeem
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                                      : AppColors.primaryContainer.withValues(alpha: 0.50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isRedeem
                                      ? PhosphorIcons.gift(PhosphorIconsStyle.fill)
                                      : PhosphorIcons.stamp(PhosphorIconsStyle.fill),
                                  size: 16,
                                  color: isRedeem
                                      ? const Color(0xFF7C3AED)
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.label,
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    if (e.customerName != null)
                                      Text(
                                        e.customerName!,
                                        style: GoogleFonts.beVietnamPro(
                                          fontSize: 11,
                                          color: AppColors.onSecondaryContainer,
                                        ),
                                      )
                                    else
                                      FutureBuilder<String?>(
                                        future: _getCustomerName(e.customerId),
                                        builder: (context, snap) {
                                          final name = snap.data ?? 'Customer ${short}';
                                          return Text(
                                            name,
                                            style: GoogleFonts.beVietnamPro(
                                              fontSize: 11,
                                              color: AppColors.onSecondaryContainer,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _timeAgo(e.ts),
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  color: AppColors.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            );
          },
        );
      },
    );
  }

  // ── Customer Reviews ──────────────────────────────────────────────

  Widget _buildReviews(String? vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('reviews')
                .where('businessId', isEqualTo: vendorId)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots()
          : null,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        const emojis = ['😡', '😕', '😐', '🙂', '😍'];
        const labels = ['Awful', 'Bad', 'OK', 'Good', 'Loved it!'];

        return _Section(
          title: 'Recent Reviews',
          trailing: docs.isNotEmpty
              ? GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const VendorReviewsScreen()),
                  ),
                  child: Text(
                    'View All',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : null,
          child: docs.isEmpty
              ? _emptyState('No reviews yet')
              : Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final rating = (d['rating'] as num?)?.toInt() ?? 2;
                    final safeRating = rating.clamp(0, 4);
                    final ts = d['createdAt'] as Timestamp?;
                    final alreadyFlagged = d['flagged'] as bool? ?? false;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(emojis[safeRating],
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(labels[safeRating],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    )),
                                if (ts != null)
                                  Text(
                                    DateFormat('MMM d').format(ts.toDate()),
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 11,
                                      color: AppColors.onSecondaryContainer,
                                    ),
                                  ),
                                if (d['comment'] != null && d['comment'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '"${d['comment']}"',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
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
                                        content:
                                            Text('Review reported for moderation'),
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
                              size: 18,
                              color: alreadyFlagged
                                  ? AppColors.error
                                  : AppColors.onSecondaryContainer
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );
      },
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

  Widget _buildReviewEditor(String? vendorId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: vendorId != null
          ? FirebaseFirestore.instance
                .collection('businesses')
                .doc(vendorId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final biz = snap.data?.data() as Map<String, dynamic>? ?? {};
        final currentQuestion = biz['reviewQuestion'] as String? ?? 'How was your visit?';

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
                onSubmitted: (val) {
                  if (vendorId == null || val.trim().isEmpty) return;
                  FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(vendorId)
                      .update({'reviewQuestion': val.trim()});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review question updated!')),
                  );
                },
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                controller: TextEditingController(text: currentQuestion)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: currentQuestion.length),
                  ),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(msg,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: AppColors.onSecondaryContainer),
            textAlign: TextAlign.center),
      );
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
  final String trend;
  final Color trendColor;
  const _MonthStat(
      {required this.label,
      required this.value,
      required this.trend,
      required this.trendColor});

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
          const SizedBox(height: 2),
          Text(trend,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: trendColor,
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
  const _ActivityEvent(
      {required this.type,
      required this.customerId,
      this.customerName,
      required this.label,
      required this.ts});
}
