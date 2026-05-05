import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../services/sound_service.dart';
import 'merchant_scan_screen.dart';
import 'redeem_screen.dart';

// ── Data model ────────────────────────────────────────────────────

class _LoyaltyCard {
  final String docId;
  final String businessId;
  final String businessName;
  final String businessCategory;
  final String? businessImageUrl;
  final int stampCount;
  final int stampGoal;
  final String rewardDescription;
  final int rewardCount;
  final int redeemedCount;

  int get pendingRewards => rewardCount - redeemedCount;

  _LoyaltyCard({
    required this.docId,
    required this.businessId,
    required this.businessName,
    required this.businessCategory,
    this.businessImageUrl,
    required this.stampCount,
    required this.stampGoal,
    required this.rewardDescription,
    required this.rewardCount,
    required this.redeemedCount,
  });

  factory _LoyaltyCard.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _LoyaltyCard(
      docId: doc.id,
      businessId: d['businessId'] as String? ?? doc.id,
      businessName: d['businessName'] as String? ?? 'Business',
      businessCategory: d['businessCategory'] as String? ?? '',
      businessImageUrl: d['businessImageUrl'] as String?,
      stampCount: (d['stampCount'] as num?)?.toInt() ?? 0,
      stampGoal: (d['stampGoal'] as num?)?.toInt() ?? 10,
      rewardDescription:
          d['rewardDescription'] as String? ??
          'Complete your card to earn a reward!',
      rewardCount: (d['rewardCount'] as num?)?.toInt() ?? 0,
      redeemedCount: (d['redeemedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────

class StreakReviewScreen extends StatefulWidget {
  const StreakReviewScreen({super.key});

  @override
  State<StreakReviewScreen> createState() => _StreakReviewScreenState();
}

class _StreakReviewScreenState extends State<StreakReviewScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _pageController = PageController();
  late final Stream<QuerySnapshot> _loyaltiesStream;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loyaltiesStream = FirebaseFirestore.instance
        .collection('loyalties')
        .where('customerId', isEqualTo: _uid)
        .snapshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return StreamBuilder<QuerySnapshot>(
      stream: _loyaltiesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final cards = (snap.data?.docs ?? [])
            .map(_LoyaltyCard.fromDoc)
            .toList();

        if (cards.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: _EmptyState(topPad: topPad),
          );
        }

        final pageCount = cards.length;
        final clampedPage = _currentPage.clamp(0, pageCount - 1);

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: pageCount,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _BusinessReviewPage(card: cards[index], topPad: topPad),
              ),

              // Page indicator dots
              Positioned(
                bottom: 110,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pageCount, (index) {
                    final active = index == clampedPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: active ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    );
                  }),
                ),
              ),

              // QR FAB — shows customer's own QR code to vendor
              Positioned(
                bottom: 100,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MerchantScanScreen(),
                    ),
                  ),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.40),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      PhosphorIcons.qrCode(PhosphorIconsStyle.fill),
                      color: AppColors.onPrimary,
                      size: 28,
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

// ── Empty state ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final double topPad;
  const _EmptyState({required this.topPad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topPad, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No loyalty cards yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Explore businesses on the Discover tab and join their loyalty programs to start collecting stamps.',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSecondaryContainer,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Business review page ──────────────────────────────────────────

class _BusinessReviewPage extends StatefulWidget {
  final _LoyaltyCard card;
  final double topPad;
  const _BusinessReviewPage({required this.card, required this.topPad});

  @override
  State<_BusinessReviewPage> createState() => _BusinessReviewPageState();
}

class _BusinessReviewPageState extends State<_BusinessReviewPage> {
  int? _selectedEmoji;
  String? _reviewDocId;
  bool _reviewSubmitted = false; // true once feedback is fully submitted
  final _commentController = TextEditingController();
  String? _customerName;

  @override
  void initState() {
    super.initState();
    _fetchCustomerName();
  }

  Future<void> _fetchCustomerName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (snap.exists) {
        setState(() {
          _customerName = (snap.data()?['name'] ?? snap.data()?['displayName']) as String?;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  static const _emojis = [
    {'glyph': '😡', 'label': 'Awful'},
    {'glyph': '😕', 'label': 'Bad'},
    {'glyph': '😐', 'label': 'OK'},
    {'glyph': '🙂', 'label': 'Good'},
    {'glyph': '😍', 'label': 'Loved it!'},
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: widget.topPad + 24,
        bottom: bottomInset > 0 ? bottomInset + 20 : 120,
      ),
      child: Column(
        children: [
          _buildHeader(c),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.04),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Column(
                children: [
                  _buildStampGrid(c),
                  const SizedBox(height: 32),
                  _buildRewardSection(c),
                  const SizedBox(height: 32),
                  Container(height: 1, color: AppColors.surfaceContainerHigh),
                  const SizedBox(height: 32),
                  _buildEmojiReview(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 160),
        ],
      ),
    );
  }

  Widget _buildHeader(_LoyaltyCard c) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            image: c.businessImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(c.businessImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: c.businessImageUrl == null
              ? Center(
                  child: Text(
                    c.businessName.isEmpty
                        ? '?'
                        : c.businessName[0].toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          c.businessName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        if (c.businessCategory.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            c.businessCategory.toUpperCase(),
            style: GoogleFonts.beVietnamPro(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStampGrid(_LoyaltyCard c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Stamp Progress',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              '${c.stampCount}/${c.stampGoal}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: c.stampGoal,
          itemBuilder: (context, index) {
            final filled = index < c.stampCount;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: filled ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: filled
                        ? AppColors.onPrimary
                        : AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRewardSection(_LoyaltyCard c) {
    final pending = c.pendingRewards;           // claimable right now
    final lifetime = c.rewardCount;             // total ever earned
    final redeemed = c.redeemedCount;           // already claimed
    final hasReward = pending > 0;
    final stampsLeft = (c.stampGoal - c.stampCount).clamp(0, c.stampGoal);

    // Circles = full history + at least 2 future slots, capped at 6
    // Index 0..redeemed-1        → REDEEMED (grey checkmark)
    // Index redeemed..lifetime-1 → PENDING  (purple gift, claimable)
    // Index lifetime..end        → FUTURE   (outlined empty)
    final displayCount = (lifetime + 2).clamp(3, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Reward Ready banner ───────────────────────────────────
        if (hasReward) ...[
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RedeemScreen(
                  businessName: c.businessName,
                  rewardDescription: c.rewardDescription,
                  rewardCount: pending,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.gift(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pending == 1
                          ? 'Tap to claim your reward!'
                          : 'Tap to claim $pending rewards!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                    color: Colors.white.withValues(alpha: 0.80),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Section header ────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Rewards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            // Show pending count when available, lifetime total otherwise
            if (hasReward)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '$pending to claim',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              )
            else if (lifetime > 0)
              Text(
                '$lifetime earned all time',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Reward circles ────────────────────────────────────────
        // Each circle is one of three states:
        //   REDEEMED  (i < redeemed)  — grey + checkmark
        //   PENDING   (i < lifetime)  — purple + gift, claimable
        //   FUTURE    (i >= lifetime) — outlined empty
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(displayCount, (i) {
            final isRedeemed = i < redeemed;
            final isPending  = !isRedeemed && i < lifetime;

            Color bgColor;
            Color borderColor;
            Widget icon;

            if (isRedeemed) {
              bgColor     = AppColors.outline.withValues(alpha: 0.18);
              borderColor = AppColors.outline.withValues(alpha: 0.40);
              icon = Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                size: 20,
                color: AppColors.onSecondaryContainer.withValues(alpha: 0.55),
              );
            } else if (isPending) {
              bgColor     = const Color(0xFF7C3AED);
              borderColor = const Color(0xFF7C3AED);
              icon = Icon(
                PhosphorIcons.gift(PhosphorIconsStyle.fill),
                size: 20,
                color: Colors.white,
              );
            } else {
              bgColor     = Colors.transparent;
              borderColor = AppColors.outline;
              icon = Icon(
                PhosphorIcons.gift(PhosphorIconsStyle.regular),
                size: 20,
                color: AppColors.onSecondaryContainer.withValues(alpha: 0.40),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: isPending
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: icon),
              ),
            );
          }),
        ),

        // ── "X stamps until next reward" strip ───────────────────
        if (!hasReward) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.path(PhosphorIconsStyle.fill),
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stampsLeft == 0
                            ? 'Card complete — visit to claim!'
                            : '$stampsLeft more ${stampsLeft == 1 ? 'stamp' : 'stamps'} until your next reward',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: LinearProgressIndicator(
                    value: c.stampGoal > 0 ? c.stampCount / c.stampGoal : 0,
                    minHeight: 6,
                    backgroundColor: AppColors.outline.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${c.stampCount} / ${c.stampGoal} stamps',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Reward description ────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.tag(PhosphorIconsStyle.fill),
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.rewardDescription.isEmpty
                      ? 'Complete your card to earn a reward!'
                      : c.rewardDescription,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiReview() {
    return Column(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('businesses').doc(widget.card.businessId).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final question = data?['reviewQuestion'] as String? ?? 'How was your visit?';
            return Text(
              question,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            );
          }
        ),
        const SizedBox(height: 26),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: List.generate(_emojis.length, (index) {
            final selected = _selectedEmoji == index;
            final isLoved = index == _emojis.length - 1;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmoji = index);
                // Play bell sound when rating is selected
                SoundService().playRatingSound(index);
                _saveRating(index);
              },
              child: Column(
                children: [
                  // Emoji with selected background circle
                  Container(
                    width: selected ? 56 : 48,
                    height: selected ? 56 : 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? (isLoved
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surfaceVariant)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: isLoved
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: selected ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Text(
                          _emojis[index]['glyph']!,
                          style: TextStyle(
                            fontSize: isLoved && !selected ? 34 : 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label - always visible if selected, hidden if not
                  AnimatedOpacity(
                    opacity: selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            size: 14,
                            color: isLoved
                                ? AppColors.primary
                                : AppColors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _emojis[index]['label']!,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isLoved
                                ? AppColors.primary
                                : AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        if (_selectedEmoji != null) ...[
          const SizedBox(height: 24),
          TextField(
            controller: _commentController,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Tell us more about your experience (Optional)',
              hintStyle: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: AppColors.onSecondaryContainer.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                ),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _saveComment();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your feedback!')),
                  );
                  // Reset state so the next review is a brand new document
                  setState(() {
                    _reviewDocId = null;
                    _selectedEmoji = null;
                    _reviewSubmitted = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Submit Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveRating(int ratingIndex) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final businessId = widget.card.businessId;
      if (user == null || businessId.isEmpty) return;

      // Always create a new review doc — never reuse one from a previous
      // submission. _reviewDocId is only reused when the user is still
      // choosing their emoji in the SAME review session (before Submit).
      if (_reviewDocId == null) {
        final docRef = await FirebaseFirestore.instance.collection('reviews').add({
          'customerId': user.uid,
          'customerName': _customerName,
          'businessId': businessId,
          'businessName': widget.card.businessName,
          'rating': ratingIndex,
          'ratingLabel': _emojis[ratingIndex]['label'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => _reviewDocId = docRef.id);
      } else {
        // User changed their emoji within the same session — update in-place
        await FirebaseFirestore.instance.collection('reviews').doc(_reviewDocId!).update({
          'rating': ratingIndex,
          'ratingLabel': _emojis[ratingIndex]['label'],
        });
      }
    } catch (e) {
      debugPrint('Error saving rating: $e');
    }
  }

  Future<void> _saveComment() async {
    if (_reviewDocId == null || _commentController.text.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('reviews').doc(_reviewDocId!).update({
        'comment': _commentController.text.trim(),
      });
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint('Error saving comment: $e');
    }
  }
}
