import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import 'merchant_scan_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int _selectedCategory = 0;

  final List<String> _categories = [
    'All Nearby',
    'Artisan Coffee',
    'Craft Dining',
    'Wellness',
    'Boutiques',
    'Grooming',
  ];

  final List<_Business> _businesses = const [
    _Business(
      name: 'The Daily Grind',
      category: 'Artisan Coffee',
      distance: '0.4 mi',
      aspectRatio: 4 / 5,
      seed: 'coffee1',
    ),
    _Business(
      name: "Joe's Barbershop",
      category: 'Grooming',
      distance: '1.2 mi',
      aspectRatio: 3 / 4,
      seed: 'barber2',
    ),
    _Business(
      name: 'Green Leaf Bistro',
      category: 'Health Food',
      distance: '0.8 mi',
      aspectRatio: 1.0,
      seed: 'salad3',
    ),
    _Business(
      name: 'Velvet & Vine',
      category: 'Boutique Fashion',
      distance: '2.5 mi',
      aspectRatio: 9 / 16,
      seed: 'fashion4',
    ),
    _Business(
      name: 'Rustic Crust',
      category: 'Italian Kitchen',
      distance: '0.2 mi',
      aspectRatio: 4 / 3,
      seed: 'pizza5',
    ),
    _Business(
      name: 'Iron Strong',
      category: 'Fitness',
      distance: '1.5 mi',
      aspectRatio: 1.0,
      seed: 'gym6',
    ),
    _Business(
      name: 'Bloom & Blossom',
      category: 'Floral Design',
      distance: '3.1 mi',
      aspectRatio: 3 / 4,
      seed: 'flowers7',
    ),
    _Business(
      name: 'Zen Spa',
      category: 'Wellness',
      distance: '0.5 mi',
      aspectRatio: 4 / 5,
      seed: 'spa8',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    // Split into two columns for masonry layout
    final leftCol = <_Business>[];
    final rightCol = <_Business>[];
    for (var i = 0; i < _businesses.length; i++) {
      (i.isEven ? leftCol : rightCol).add(_businesses[i]);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPad + 72),
              ),

              // Editorial header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURATED FOR YOU',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Explore local gems\nand unlock exclusive perks.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.15,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),

              // Category chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final active = _selectedCategory == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            _categories[index],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.onPrimary
                                  : AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Masonry grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: leftCol
                              .map((b) => _BusinessCard(business: b))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: rightCol
                              .map((b) => _BusinessCard(business: b))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom breathing room (nav + FAB clearance)
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ── Glass top app bar ────────────────────────────────────────
          _GlassAppBar(
            topPad: topPad,
            trailing: _AvatarBadge(),
            actions: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MerchantScanScreen()),
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Icon(
                    PhosphorIcons.qrCode(),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          // ── Map FAB ──────────────────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 20,
            child: _PrimaryFAB(
              icon: PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Business card
// ─────────────────────────────────────────────────────────────────

class _Business {
  final String name;
  final String category;
  final String distance;
  final double aspectRatio;
  final String seed;

  const _Business({
    required this.name,
    required this.category,
    required this.distance,
    required this.aspectRatio,
    required this.seed,
  });

  String get imageUrl => 'https://picsum.photos/seed/$seed/400/600';
}

class _BusinessCard extends StatelessWidget {
  final _Business business;
  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: AppColors.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: business.aspectRatio,
                    child: Image.network(
                      business.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => AspectRatio(
                        aspectRatio: business.aspectRatio,
                        child: Container(
                          color: AppColors.surfaceContainerHigh,
                          child: Center(
                            child: Icon(
                              PhosphorIcons.image(),
                              color: AppColors.onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Distance badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          color:
                              AppColors.surfaceContainerLowest.withOpacity(0.82),
                          child: Text(
                            business.distance,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      business.category.toUpperCase(),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared widgets (used across screens via import)
// ─────────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final Widget? trailing;
  final List<Widget> actions;
  final String title;

  const _GlassAppBar({
    required this.topPad,
    this.trailing,
    this.actions = const [],
    this.title = 'Bin Perks',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
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
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                ...actions,
                if (actions.isNotEmpty) const SizedBox(width: 10),
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

class _PrimaryFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryFAB({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.38),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.onPrimary, size: 28),
      ),
    );
  }
}
