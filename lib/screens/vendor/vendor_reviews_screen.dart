import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

enum PeriodType { day, week, month, year }

class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  PeriodType _selectedPeriod = PeriodType.month;
  DateTime _focusedDate = DateTime.now();
  final List<int> _years = List.generate(5, (i) => DateTime.now().year - i);
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = _focusedDate.year;
    _selectedMonth = _focusedDate.month;
  }

  DateTimeRange _getRange() {
    switch (_selectedPeriod) {
      case PeriodType.day:
        final start = DateTime(_selectedYear, _selectedMonth, _focusedDate.day);
        final end = start.add(const Duration(days: 1));
        return DateTimeRange(start: start, end: end);
      case PeriodType.week:
        final start = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
        final cleanStart = DateTime(start.year, start.month, start.day);
        final end = cleanStart.add(const Duration(days: 7));
        return DateTimeRange(start: cleanStart, end: end);
      case PeriodType.month:
        final start = DateTime(_selectedYear, _selectedMonth, 1);
        final end = DateTime(_selectedYear, _selectedMonth + 1, 1);
        return DateTimeRange(start: start, end: end);
      case PeriodType.year:
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear + 1, 1, 1);
        return DateTimeRange(start: start, end: end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return const SizedBox.shrink();

    final range = _getRange();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Reviews Archive',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('businessId', isEqualTo: vendorId)
                  .where('createdAt', isGreaterThanOrEqualTo: range.start)
                  .where('createdAt', isLessThan: range.end)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading reviews:\n${snap.error}\n\nCreate a Firestore composite index:\ncollection=reviews, fields=businessId(asc)+createdAt(desc)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _emptyState('No reviews found for this period');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data() as Map<String, dynamic>;
                    final rating = (d['rating'] as num?)?.toInt() ?? 2;
                    final ts = d['createdAt'] as Timestamp?;
                    final comment = d['comment'] as String?;
                    final customerName = d['customerName'];
                    final customerId = (d['customerId'] ?? d['uid'] ?? d['userId'] ?? '') as String;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                            color: Colors.white, size: 22),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Text('Delete review?',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            content: Text(
                                'This will permanently remove this review from your archive.',
                                style: GoogleFonts.beVietnamPro(fontSize: 14)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancel',
                                    style: GoogleFonts.beVietnamPro(
                                        fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Delete',
                                    style: GoogleFonts.beVietnamPro(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error)),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await doc.reference.delete();
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Review deleted'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getEmoji(rating),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['ratingLabel'] ?? 'OK',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    FutureBuilder<String?>(
                                      future: customerName != null
                                          ? Future.value(customerName)
                                          : _getCustomerName(customerId),
                                      builder: (context, nameSnap) {
                                        final name =
                                            nameSnap.data ?? customerName;
                                        if (nameSnap.connectionState ==
                                                ConnectionState.waiting &&
                                            customerName == null) {
                                          return Text(
                                            'Loading name...',
                                            style: GoogleFonts.beVietnamPro(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors
                                                  .onSecondaryContainer
                                                  .withOpacity(0.5),
                                            ),
                                          );
                                        }
                                        return Text(
                                          name ?? 'Anonymous Customer',
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                AppColors.onSecondaryContainer,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (ts != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('d MMM, HH:mm')
                                          .format(ts.toDate()),
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 11,
                                        color: AppColors.onSecondaryContainer
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '← Swipe to delete',
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSecondaryContainer
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (comment != null && comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                comment,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PeriodType.values.map((p) {
                final active = _selectedPeriod == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                    selected: active,
                    onSelected: (val) {
                      if (val) setState(() => _selectedPeriod = p);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.onSecondaryContainer,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (y) => setState(() => _selectedYear = y!),
                      style: GoogleFonts.beVietnamPro(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedPeriod != PeriodType.year) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isExpanded: true,
                        items: List.generate(12, (i) => i + 1).map((m) {
                          final name = DateFormat('MMMM').format(DateTime(2022, m));
                          return DropdownMenuItem(value: m, child: Text(name));
                        }).toList(),
                        onChanged: (m) => setState(() => _selectedMonth = m!),
                        style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getEmoji(int index) {
    const emojis = ['😡', '😕', '😐', '🙂', '😍'];
    if (index >= 0 && index < emojis.length) return emojis[index];
    return '😐';
  }

  Widget _emptyState(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.star(PhosphorIconsStyle.light), size: 64, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(
              msg,
              style: GoogleFonts.beVietnamPro(color: AppColors.onSecondaryContainer),
            ),
          ],
        ),
      );

  Future<String?> _getCustomerName(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        final d = snap.data();
        final name = d?['name'] ?? d?['displayName'] ?? d?['fullName'] ?? d?['full_name'];
        return name as String?;
      }
    } catch (_) {}
    return null;
  }
}
