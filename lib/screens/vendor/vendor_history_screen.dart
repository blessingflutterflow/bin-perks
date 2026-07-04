import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

enum PeriodType { day, week, month, year }

class VendorHistoryScreen extends StatefulWidget {
  const VendorHistoryScreen({super.key});

  @override
  State<VendorHistoryScreen> createState() => _VendorHistoryScreenState();
}

class _VendorHistoryScreenState extends State<VendorHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PeriodType _selectedPeriod = PeriodType.month;
  DateTime _focusedDate = DateTime.now();

  final List<int> _years = List.generate(5, (i) => DateTime.now().year - i);
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedYear = _focusedDate.year;
    _selectedMonth = _focusedDate.month;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getRange() {
    switch (_selectedPeriod) {
      case PeriodType.day:
        final start = DateTime(_selectedYear, _selectedMonth, _focusedDate.day);
        return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
      case PeriodType.week:
        final start = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
        final cleanStart = DateTime(start.year, start.month, start.day);
        return DateTimeRange(start: cleanStart, end: cleanStart.add(const Duration(days: 7)));
      case PeriodType.month:
        final start = DateTime(_selectedYear, _selectedMonth, 1);
        return DateTimeRange(start: start, end: DateTime(_selectedYear, _selectedMonth + 1, 1));
      case PeriodType.year:
        final start = DateTime(_selectedYear, 1, 1);
        return DateTimeRange(start: start, end: DateTime(_selectedYear + 1, 1, 1));
    }
  }

  // ── Delete all for whichever tab is active ──────────────────────────
  void _onDeleteAll() {
    final isActivityTab = _tabController.index == 0;
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return;

    if (isActivityTab) {
      _showConfirmDialog(
        title: 'Delete All Activity?',
        message: 'This will permanently delete all stamps and rewards shown for the selected period.',
        onConfirm: () => _deleteAllActivity(vendorId),
      );
    } else {
      _showConfirmDialog(
        title: 'Delete All Customers?',
        message: 'This will permanently remove all customer loyalty records for your business.',
        onConfirm: () => _deleteAllCustomers(vendorId),
      );
    }
  }

  Future<void> _deleteAllActivity(String vendorId) async {
    // Capture the messenger before any await so we never touch a stale context.
    final messenger = ScaffoldMessenger.of(context);
    final range = _getRange();
    final db = FirebaseFirestore.instance;

    try {
      // Fetch by vendorId only (single-field query, no composite index needed),
      // then filter the date range on-device. Avoids the fragile range query.
      final stampsSnap = await db
          .collection('stamps')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      final redemptionsSnap = await db
          .collection('redemptions')
          .where('vendorId', isEqualTo: vendorId)
          .get();

      bool inRange(Timestamp? ts) {
        if (ts == null) return false;
        final d = ts.toDate();
        return !d.isBefore(range.start) && d.isBefore(range.end);
      }

      final refs = <DocumentReference>[];
      for (final doc in stampsSnap.docs) {
        if (inRange(doc.data()['createdAt'] as Timestamp?)) {
          refs.add(doc.reference);
        }
      }
      for (final doc in redemptionsSnap.docs) {
        if (inRange(doc.data()['redeemedAt'] as Timestamp?)) {
          refs.add(doc.reference);
        }
      }

      if (refs.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('No activity to delete for this period'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      // Delete individually — the same mechanism swipe-to-delete uses — so one
      // problem document can't block the rest (unlike an all-or-nothing batch).
      await Future.wait(refs.map((r) => r.delete()));

      messenger.showSnackBar(SnackBar(
        content: Text(
            'Deleted ${refs.length} item${refs.length == 1 ? '' : 's'}'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not delete: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteAllCustomers(String vendorId) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = FirebaseFirestore.instance;

    try {
      final loyalties = await db
          .collection('loyalties')
          .where('businessId', isEqualTo: vendorId)
          .get();

      if (loyalties.docs.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('No customer records to delete'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      await Future.wait(loyalties.docs.map((d) => d.reference.delete()));

      messenger.showSnackBar(SnackBar(
        content: Text(
            'Deleted ${loyalties.docs.length} customer record${loyalties.docs.length == 1 ? '' : 's'}'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not delete: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(message, style: GoogleFonts.beVietnamPro(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'History Archive',
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
            icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                color: AppColors.error),
            tooltip: 'Delete all',
            onPressed: _onDeleteAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSecondaryContainer,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'All Activity'),
            Tab(text: 'By Customer'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActivityTab(range: _getRange()),
                _CustomerTab(range: _getRange()),
              ],
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
              if (_selectedPeriod == PeriodType.day) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _focusedDate,
                      firstDate: DateTime(2020),
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
                  icon: Icon(PhosphorIcons.calendar(), color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── All Activity Tab ──────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final DateTimeRange range;
  const _ActivityTab({required this.range});

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stamps')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThanOrEqualTo: range.start)
          .where('createdAt', isLessThan: range.end)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, stampsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('redemptions')
              .where('vendorId', isEqualTo: vendorId)
              .where('redeemedAt', isGreaterThanOrEqualTo: range.start)
              .where('redeemedAt', isLessThan: range.end)
              .orderBy('redeemedAt', descending: true)
              .snapshots(),
          builder: (context, redeemSnap) {
            if (stampsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final items = <_HistoryItem>[];
            for (final doc in stampsSnap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              items.add(_HistoryItem(
                type: 'Stamp',
                label: 'Stamp #${d['stampNumber'] ?? ''}',
                customerName: d['customerName'],
                customerId: d['customerId'],
                ts: d['createdAt'] as Timestamp,
                color: AppColors.primary,
                icon: PhosphorIcons.stamp(PhosphorIconsStyle.fill),
                docId: doc.id,
                collection: 'stamps',
              ));
            }
            for (final doc in redeemSnap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              items.add(_HistoryItem(
                type: 'Reward',
                label: d['rewardDescription'] ?? 'Reward Redeemed',
                customerName: d['customerName'],
                customerId: d['customerId'],
                ts: d['redeemedAt'] as Timestamp,
                color: const Color(0xFF7C3AED),
                icon: PhosphorIcons.gift(PhosphorIconsStyle.fill),
                docId: doc.id,
                collection: 'redemptions',
              ));
            }

            items.sort((a, b) => b.ts.compareTo(a.ts));

            if (items.isEmpty) {
              return _emptyState('No activity found for this period');
            }

            final grouped = <String, List<_HistoryItem>>{};
            for (final item in items) {
              final dateStr = DateFormat('EEEE, d MMMM').format(item.ts.toDate());
              grouped.putIfAbsent(dateStr, () => []).add(item);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final date = grouped.keys.elementAt(index);
                final dayItems = grouped[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 0, 12),
                      child: Text(
                        date.toUpperCase(),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.onSecondaryContainer.withOpacity(0.6),
                        ),
                      ),
                    ),
                    ...dayItems.map((item) => _buildItemTile(context, item)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemTile(BuildContext context, _HistoryItem item) {
    return Dismissible(
      key: Key(item.docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await FirebaseFirestore.instance
            .collection(item.collection)
            .doc(item.docId)
            .delete();
        messenger.showSnackBar(SnackBar(
          content: Text('${item.label} deleted'),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  FutureBuilder<String?>(
                    future: item.customerName != null
                        ? Future.value(item.customerName)
                        : _getCustomerName(item.customerId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          item.customerName == null) {
                        return Text(
                          'Loading name...',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.onSecondaryContainer.withOpacity(0.5),
                          ),
                        );
                      }
                      return Text(
                        snap.data ?? item.customerName ?? 'Anonymous Customer',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSecondaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(item.ts.toDate()),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSecondaryContainer.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '← Swipe to delete',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSecondaryContainer.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── By Customer Tab ───────────────────────────────────────────────────

class _CustomerTab extends StatelessWidget {
  final DateTimeRange range;
  const _CustomerTab({required this.range});

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loyalties')
          .where('businessId', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _emptyState('Failed to load customers');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data!.docs)
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['lastStampAt'] as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['lastStampAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        if (docs.isEmpty) return _emptyState('No loyalty customers yet');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;
            final customerId = d['customerId'] as String;
            final totalVisits = (d['totalVisits'] as num?)?.toInt() ?? 0;
            final lastStamp = (d['lastStampAt'] as Timestamp?)?.toDate();
            final lastVisitStr = lastStamp != null
                ? DateFormat('d MMM yyyy').format(lastStamp)
                : '—';

            return FutureBuilder<String?>(
              future: _getCustomerName(customerId),
              builder: (context, nameSnap) {
                final name = nameSnap.data ?? 'Anonymous Customer';

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
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
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Remove $name?',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        content: Text(
                            'This will permanently remove their loyalty record.',
                            style: GoogleFonts.beVietnamPro(fontSize: 14)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel',
                                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Delete',
                                style: GoogleFonts.beVietnamPro(
                                    fontWeight: FontWeight.w700, color: AppColors.error)),
                          ),
                        ],
                      ),
                    ) ?? false;
                  },
                  onDismissed: (_) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await FirebaseFirestore.instance
                        .collection('loyalties')
                        .doc(doc.id)
                        .delete();
                    messenger.showSnackBar(SnackBar(
                      content: Text('$name removed'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                                    size: 12,
                                    color: AppColors.onSecondaryContainer.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Last visit: $lastVisitStr',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSecondaryContainer.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$totalVisits visits',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────

Widget _emptyState(String msg) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(PhosphorIcons.archive(PhosphorIconsStyle.light),
          size: 64, color: AppColors.outline),
      const SizedBox(height: 16),
      Text(msg, style: GoogleFonts.beVietnamPro(color: AppColors.onSecondaryContainer)),
    ],
  ),
);

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

// ── Models ────────────────────────────────────────────────────────────

class _HistoryItem {
  final String type;
  final String label;
  final String? customerName;
  final String customerId;
  final Timestamp ts;
  final Color color;
  final IconData icon;
  final String docId;
  final String collection;

  _HistoryItem({
    required this.type,
    required this.label,
    required this.customerName,
    required this.customerId,
    required this.ts,
    required this.color,
    required this.icon,
    required this.docId,
    required this.collection,
  });
}
