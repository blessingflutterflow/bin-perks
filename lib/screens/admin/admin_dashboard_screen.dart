import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Admin Dashboard',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(PhosphorIcons.signOut(), color: AppColors.onPrimary),
                          onPressed: () => FirebaseAuth.instance.signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'All Vendors',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
          _buildVendorList(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('businesses').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Unable to load stats. Please try again.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 52,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }
        final docs = snap.data!.docs;
        final total = docs.length;
        final now = DateTime.now();
        int active = 0;
        int expired = 0;
        int pending = 0;
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          if (status == 'pending') {
            pending++;
            continue;
          }
          final subStatus = data['subscriptionStatus'] as String? ?? 'none';
          final endTs = data['currentPeriodEnd'] as Timestamp?;
          final daysLeft = endTs != null ? endTs.toDate().difference(now).inDays : -1;
          if (subStatus == 'active' || subStatus == 'trialing') {
            if (daysLeft >= 0) active++;
          }
          if (daysLeft < 0 || subStatus == 'canceled' || subStatus == 'none') {
            expired++;
          }
        }

        return Row(
          children: [
            _StatChip(label: 'Total', value: total, color: AppColors.primary),
            const SizedBox(width: 8),
            _StatChip(label: 'Active', value: active, color: Colors.green),
            const SizedBox(width: 8),
            _StatChip(label: 'Expired', value: expired, color: Colors.red),
            const SizedBox(width: 8),
            _StatChip(label: 'Pending', value: pending, color: Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildVendorList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .orderBy('name', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snap.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'Error: ${snap.error}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: AppColors.error),
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'No vendors yet.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: AppColors.onSecondaryContainer),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final sortedDocs = docs.toList()..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aStatus = aData['status'] as String? ?? 'pending';
          final bStatus = bData['status'] as String? ?? 'pending';
          if (aStatus == 'pending' && bStatus != 'pending') return -1;
          if (bStatus == 'pending' && aStatus != 'pending') return 1;
          final aEnd = (aData['currentPeriodEnd'] as Timestamp?)?.toDate() ?? now;
          final bEnd = (bData['currentPeriodEnd'] as Timestamp?)?.toDate() ?? now;
          return aEnd.compareTo(bEnd);
        });

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _VendorCard(
                docId: doc.id,
                data: data,
                now: now,
                onExtend: (days) => _extendSubscription(context, doc.id, data, days),
              );
            },
            childCount: sortedDocs.length,
          ),
        );
      },
    );
  }

  Future<void> _extendSubscription(BuildContext context, String docId,
      Map<String, dynamic> data, int days) async {
    try {
      final currentEnd = (data['currentPeriodEnd'] as Timestamp?)?.toDate() ?? DateTime.now();
      final newEnd = currentEnd.isBefore(DateTime.now())
          ? DateTime.now().add(Duration(days: days))
          : currentEnd.add(Duration(days: days));

      await FirebaseFirestore.instance.collection('businesses').doc(docId).update({
        'currentPeriodEnd': Timestamp.fromDate(newEnd),
        'subscriptionStatus': 'active',
        'extendedAt': FieldValue.serverTimestamp(),
        'extendedBy': FirebaseAuth.instance.currentUser?.uid,
        'extensionDays': days,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extended by $days days until ${DateFormat('MMM d, y').format(newEnd)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final DateTime now;
  final void Function(int days) onExtend;

  const _VendorCard({
    required this.docId,
    required this.data,
    required this.now,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unnamed Business';
    final planId = data['planId'] as String? ?? 'None';
    final status = data['status'] as String? ?? 'pending';
    final subStatus = data['subscriptionStatus'] as String? ?? 'none';
    final endTs = data['currentPeriodEnd'] as Timestamp?;
    final endDate = endTs?.toDate();
    final daysLeft = endDate != null ? endDate.difference(now).inDays : -1;
    final isExpired = daysLeft < 0 || subStatus == 'canceled' || subStatus == 'none';

    Color statusColor;
    String statusLabel;
    if (status == 'pending') {
      statusColor = Colors.orange;
      statusLabel = 'Pending Approval';
    } else if (isExpired) {
      statusColor = Colors.red;
      statusLabel = 'Expired';
    } else if (daysLeft <= 3) {
      statusColor = Colors.orange;
      statusLabel = 'Expiring Soon ($daysLeft days)';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Active ($daysLeft days left)';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Plan: ${planId.isEmpty ? 'None' : planId}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (endDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(PhosphorIcons.calendarBlank(), size: 14, color: AppColors.onSecondaryContainer),
                const SizedBox(width: 6),
                Text(
                  'Ends: ${DateFormat('MMM d, y').format(endDate)}',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: status == 'pending' ? null : () => _showExtendSheet(context, endDate),
              icon: Icon(PhosphorIcons.plusCircle(), size: 16),
              label: const Text('Extend Days'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExtendSheet(BuildContext context, DateTime? currentEnd) {
    final daysCtrl = TextEditingController();
    String? errorText;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Extend Subscription',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (currentEnd != null)
                  Text(
                    'Current expiry: ${DateFormat('MMM d, y').format(currentEnd)}',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Days to add',
                    hintText: 'e.g. 30',
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(PhosphorIcons.calendarBlank()),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
                      if (days > 0) {
                        Navigator.pop(ctx);
                        onExtend(days);
                      } else {
                        setSheetState(
                          () => errorText = 'Please enter a number greater than 0',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm Extension', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ).then((_) => daysCtrl.dispose());
  }
}
