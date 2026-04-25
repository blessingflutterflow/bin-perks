import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import 'merchant_scan_screen.dart';

class _ReviewBusiness {
  final String name;
  final String category;
  final IconData icon;
  final int filledStamps;
  final int totalStamps;
  final int streakDays;
  final int streakMax;

  _ReviewBusiness({
    required this.name,
    required this.category,
    required this.icon,
    required this.filledStamps,
    this.totalStamps = 10,
    required this.streakDays,
    this.streakMax = 10,
  });
}

class StreakReviewScreen extends StatefulWidget {
  const StreakReviewScreen({super.key});

  @override
  State<StreakReviewScreen> createState() => _StreakReviewScreenState();
}

class _StreakReviewScreenState extends State<StreakReviewScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_ReviewBusiness> _businesses = [
    _ReviewBusiness(
      name: 'The Daily Grind',
      category: 'Artisan Coffee',
      icon: PhosphorIcons.coffee(),
      filledStamps: 7,
      streakDays: 7,
    ),
    _ReviewBusiness(
      name: "Joe's Barbershop",
      category: 'Grooming',
      icon: PhosphorIcons.scissors(),
      filledStamps: 3,
      streakDays: 2,
    ),
    _ReviewBusiness(
      name: 'Green Leaf Bistro',
      category: 'Health Food',
      icon: PhosphorIcons.carrot(),
      filledStamps: 5,
      streakDays: 4,
    ),
    _ReviewBusiness(
      name: 'Velvet & Vine',
      category: 'Boutique Fashion',
      icon: PhosphorIcons.tShirt(),
      filledStamps: 1,
      streakDays: 0,
    ),
    _ReviewBusiness(
      name: 'Rustic Crust',
      category: 'Italian Kitchen',
      icon: PhosphorIcons.pizza(),
      filledStamps: 8,
      streakDays: 6,
    ),
    _ReviewBusiness(
      name: 'Iron Strong',
      category: 'Fitness',
      icon: PhosphorIcons.barbell(),
      filledStamps: 4,
      streakDays: 3,
    ),
    _ReviewBusiness(
      name: 'Bloom & Blossom',
      category: 'Floral Design',
      icon: PhosphorIcons.flower(),
      filledStamps: 2,
      streakDays: 1,
    ),
    _ReviewBusiness(
      name: 'Zen Spa',
      category: 'Wellness',
      icon: PhosphorIcons.drop(),
      filledStamps: 6,
      streakDays: 5,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Horizontal swipe pages ────────────────────────────────
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            itemCount: _businesses.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _BusinessReviewPage(
                business: _businesses[index],
                topPad: topPad,
              );
            },
          ),

          // ── Page indicator dots ───────────────────────────────────
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_businesses.length, (index) {
                final active = index == _currentPage;
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

          // ── Scan FAB ─────────────────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MerchantScanScreen()),
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
                      color: AppColors.primary.withOpacity(0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  PhosphorIcons.qrCode(),
                  color: AppColors.onPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Individual business review page (one swipe card)
// ─────────────────────────────────────────────────────────────────

class _BusinessReviewPage extends StatefulWidget {
  final _ReviewBusiness business;
  final double topPad;

  const _BusinessReviewPage({
    required this.business,
    required this.topPad,
  });

  @override
  State<_BusinessReviewPage> createState() => _BusinessReviewPageState();
}

class _BusinessReviewPageState extends State<_BusinessReviewPage> {
  int? _selectedEmoji;

  final List<Map<String, String>> _emojis = const [
    {'glyph': '😡', 'label': 'Awful'},
    {'glyph': '😕', 'label': 'Bad'},
    {'glyph': '😐', 'label': 'OK'},
    {'glyph': '🙂', 'label': 'Good'},
    {'glyph': '😍', 'label': 'Loved it!'},
  ];

  @override
  Widget build(BuildContext context) {
    final b = widget.business;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: widget.topPad + 24),
      child: Column(
        children: [
          // ── Business logo header ──────────────────────────────
          _buildBusinessHeader(b),

          const SizedBox(height: 32),

          // ── Main card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.04),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  _buildStampGrid(b),
                  const SizedBox(height: 32),
                  _buildStreakBar(b),
                  const SizedBox(height: 32),
                  Container(
                    height: 1,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  const SizedBox(height: 32),
                  _buildEmojiReview(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Rewards ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRewards(),
          ),

          const SizedBox(height: 160),
        ],
      ),
    );
  }

  Widget _buildBusinessHeader(_ReviewBusiness b) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  b.icon,
                  color: AppColors.onPrimary,
                  size: 40,
                ),
                const SizedBox(height: 4),
                Text(
                  b.name.split(' ').first.toUpperCase(),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          b.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildStampGrid(_ReviewBusiness b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Goal Progress',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              '${b.filledStamps}/${b.totalStamps}',
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
          itemCount: b.totalStamps,
          itemBuilder: (context, index) {
            final filled = index < b.filledStamps;
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
                    fontSize: 16,
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

  Widget _buildStreakBar(_ReviewBusiness b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Streak',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Center(
            child: Text(
              '${b.streakDays}/${b.streakMax}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          b.streakDays > 0
              ? 'Keep visiting to maintain your streak!'
              : 'No active streak — visit today to start one!',
          style: GoogleFonts.beVietnamPro(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiReview() {
    return Column(
      children: [
        Text(
          'How was your visit?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_emojis.length, (index) {
            final selected = _selectedEmoji == index;
            final isLoved = index == _emojis.length - 1;
            return GestureDetector(
              onTap: () => setState(() => _selectedEmoji = index),
              child: Column(
                children: [
                  AnimatedScale(
                    scale: selected ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Text(
                      _emojis[index]['glyph']!,
                      style: TextStyle(
                        fontSize: isLoved && !selected ? 34 : 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    opacity: selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
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
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRewards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Rewards',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outline,
                  width: 2,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

