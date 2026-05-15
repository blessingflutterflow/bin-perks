import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

enum PeriodType { day, week, month, year }

class CustomerRewardHistoryScreen extends StatefulWidget {
  const CustomerRewardHistoryScreen({super.key});

  @override
  State<CustomerRewardHistoryScreen> createState() =>
      _CustomerRewardHistoryScreenState();
}

class _CustomerRewardHistoryScreenState
    extends State<CustomerRewardHistoryScreen> {
  PeriodType _selectedPeriod = PeriodType.month;
  DateTime _focusedDate = DateTime.now();

  final List<int> _years =
      List.generate(5, (i) => DateTime.now().year - i);
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
        final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        final day = _focusedDate.day.clamp(1, daysInMonth);
        final start = DateTime(_selectedYear, _selectedMonth, day);
        final end = start.add(const Duration(days: 1));
        return DateTimeRange(start: start, end: end);
      case PeriodType.week:
        final start = _focusedDate.subtract(
            Duration(days: _focusedDate.weekday - 1));
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

  Future<void> _clearAllRedemptions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Reward Archive?',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
            'This will permanently delete all your reward history records. This cannot be undone.',
            style: GoogleFonts.beVietnamPro(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
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
    );

    if (confirmed != true || !mounted) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('redemptions')
          .where('customerId', isEqualTo: uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward archive cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear archive: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final range = _getRange();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Reward Archive',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.trash(), color: AppColors.error),
            onPressed: _clearAllRedemptions,
            tooltip: 'Clear Archive',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not signed in'))
                : _buildRedemptionsList(uid, range),
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
        border: Border(
            bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PeriodType.values.map((period) {
                      final isSelected = period == _selectedPeriod;
                      final label = period.name[0].toUpperCase() +
                          period.name.substring(1);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedPeriod = period),
                          selectedColor: AppColors.primary,
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.onSurface,
                          ),
                          backgroundColor:
                              AppColors.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.outlineVariant
                                      .withOpacity(0.3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDateSelector(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    if (_selectedPeriod == PeriodType.year) {
      return _YearSelector(
        years: _years,
        selectedYear: _selectedYear,
        onChanged: (y) => setState(() => _selectedYear = y),
      );
    }
    if (_selectedPeriod == PeriodType.month) {
      return Row(
        children: [
          Expanded(
            child: _MonthSelector(
              selectedMonth: _selectedMonth,
              onChanged: (m) => setState(() => _selectedMonth = m),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _YearSelector(
              years: _years,
              selectedYear: _selectedYear,
              onChanged: (y) => setState(() => _selectedYear = y),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _focusedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _focusedDate = picked;
            _selectedYear = picked.year;
            _selectedMonth = picked.month;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.calendar(),
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              _formatRangeLabel(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            Icon(PhosphorIcons.caretDown(),
                size: 14, color: AppColors.onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  String _formatRangeLabel() {
    final range = _getRange();
    switch (_selectedPeriod) {
      case PeriodType.day:
        return DateFormat('EEEE, d MMMM yyyy').format(range.start);
      case PeriodType.week:
        final end = range.end.subtract(const Duration(days: 1));
        return '${DateFormat('d MMM').format(range.start)} - ${DateFormat('d MMM yyyy').format(end)}';
      case PeriodType.month:
        return DateFormat('MMMM yyyy').format(range.start);
      case PeriodType.year:
        return range.start.year.toString();
    }
  }

  Widget _buildRedemptionsList(String uid, DateTimeRange range) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('redemptions')
          .where('customerId', isEqualTo: uid)
          .where('redeemedAt', isGreaterThanOrEqualTo: range.start)
          .where('redeemedAt', isLessThan: range.end)
          .orderBy('redeemedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snap.hasError) {
          return _emptyState('Unable to load rewards. Please try again.');
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState('No rewards redeemed for this period');
        }

        final grouped = <String, List<_RedemptionItem>>{};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['redeemedAt'] as Timestamp?;
          if (ts == null) continue;
          final dateStr = DateFormat('EEEE, d MMMM').format(ts.toDate());
          grouped.putIfAbsent(
              dateStr,
              () => []).add(_RedemptionItem(
            businessName:
                d['businessName'] as String? ?? 'Unknown Business',
            rewardDescription:
                d['rewardDescription'] as String? ?? 'Reward',
            ts: ts,
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final date = grouped.keys.elementAt(index);
            final items = grouped[date]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(4, 16, 0, 12),
                  child: Text(
                    date.toUpperCase(),
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.onSecondaryContainer
                          .withOpacity(0.6),
                    ),
                  ),
                ),
                ...items.map((item) => _buildItemTile(item)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItemTile(_RedemptionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                PhosphorIcons.gift(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.businessName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.rewardDescription,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(item.ts.toDate()),
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.gift(PhosphorIconsStyle.regular),
            size: 48,
            color: AppColors.onSecondaryContainer.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _RedemptionItem {
  final String businessName;
  final String rewardDescription;
  final Timestamp ts;
  _RedemptionItem({
    required this.businessName,
    required this.rewardDescription,
    required this.ts,
  });
}

// ── Year selector ─────────────────────────────────────────────────

class _YearSelector extends StatelessWidget {
  final List<int> years;
  final int selectedYear;
  final ValueChanged<int> onChanged;

  const _YearSelector({
    required this.years,
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedYear,
          isExpanded: true,
          icon: Icon(PhosphorIcons.caretDown(),
              size: 14, color: AppColors.onSecondaryContainer),
          items: years.map((y) {
            return DropdownMenuItem(
              value: y,
              child: Text(
                y.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Month selector ────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final int selectedMonth;
  final ValueChanged<int> onChanged;

  const _MonthSelector({
    required this.selectedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth,
          isExpanded: true,
          icon: Icon(PhosphorIcons.caretDown(),
              size: 14, color: AppColors.onSecondaryContainer),
          items: List.generate(12, (i) {
            return DropdownMenuItem(
              value: i + 1,
              child: Text(
                months[i],
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
              ),
            );
          }),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
