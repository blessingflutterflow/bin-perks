import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import 'merchant_scan_screen.dart';

class StreakReviewScreen extends StatefulWidget {
  const StreakReviewScreen({super.key});

  @override
  State<StreakReviewScreen> createState() => _StreakReviewScreenState();
}

class _StreakReviewScreenState extends State<StreakReviewScreen> {
  int? _selectedEmoji;

  // Stamp progress – 7 of 10 completed
  static const int _totalStamps = 10;
  static const int _filledStamps = 7;

  final List<Map<String, String>> _emojis = const [
    {'glyph': '😡', 'label': 'Awful'},
    {'glyph': '😕', 'label': 'Bad'},
    {'glyph': '😐', 'label': 'OK'},
    {'glyph': '🙂', 'label': 'Good'},
    {'glyph': '😍', 'label': 'Loved it!'},
  ];

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topPad + 72)),

              // Hero header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STATUS',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "You're on fire!",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.1,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main card ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
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
                        _buildGoalProgress(),
                        const SizedBox(height: 32),
                        _buildStreakBar(),
                        const SizedBox(height: 32),
                        // Tonal divider – no hard lines
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
              ),

              // ── Secondary CTA cards ───────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _SecondaryCard(
                          icon: PhosphorIcons.gift(PhosphorIconsStyle.fill),
                          title: 'Next Perk',
                          subtitle: '3 more bins to unlock free coffee',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SecondaryCard(
                          icon: PhosphorIcons.mapTrifold(
                              PhosphorIconsStyle.fill),
                          title: 'Find Bins',
                          subtitle: 'Explore locations near you',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ── Glass top app bar ────────────────────────────────────────
          _GlassAppBar(topPad: topPad, trailing: _AvatarBadge()),

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

  // ── Goal progress (10-stamp grid) ──────────────────────────────
  Widget _buildGoalProgress() {
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
              '$_filledStamps/$_totalStamps',
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
          itemCount: _totalStamps,
          itemBuilder: (context, index) {
            final filled = index < _filledStamps;
            final isReward = index == _totalStamps - 1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.primaryContainer
                    : AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: filled
                    ? Icon(
                        PhosphorIcons.check(PhosphorIconsStyle.bold),
                        color: AppColors.onPrimaryContainer,
                        size: 20,
                      )
                    : isReward
                        ? Icon(
                            PhosphorIcons.medal(PhosphorIconsStyle.fill),
                            color: AppColors.onSecondaryContainer,
                            size: 20,
                          )
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Streak bar ──────────────────────────────────────────────────
  Widget _buildStreakBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIcons.flame(PhosphorIconsStyle.fill),
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '7 Day Streak',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.45),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.timer(), color: AppColors.error, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'Expiring in 4h 20m',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: 0.7,
            minHeight: 14,
            backgroundColor: AppColors.secondaryContainer,
            valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryContainer),
          ),
        ),
      ],
    );
  }

  // ── Emoji review ────────────────────────────────────────────────
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
}

// ─────────────────────────────────────────────────────────────────
// Secondary CTA card
// ─────────────────────────────────────────────────────────────────

class _SecondaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SecondaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.onSecondaryContainer,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared glass app bar (local copy; extracted to widgets if needed)
// ─────────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final Widget? trailing;

  const _GlassAppBar({required this.topPad, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: AppColors.surface.withOpacity(0.88),
            padding: EdgeInsets.only(top: topPad, left: 20, right: 20),
            height: topPad + 64,
            child: Row(
              children: [
                Icon(PhosphorIcons.list(), color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Bin Perks',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceContainerHigh,
      backgroundImage:
          const NetworkImage('https://picsum.photos/seed/avatar99/100/100'),
    );
  }
}
