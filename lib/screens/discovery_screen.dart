import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int _selectedCategory = 0;
  String? _currentAddress;
  bool _isLoadingLocation = false;

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
              // Location picker
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
                  child: _buildLocationPicker(),
                ),
              ),

              // Editorial header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
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

  // ── Location picker ───────────────────────────────────────────
  Widget _buildLocationPicker() {
    return GestureDetector(
      onTap: _isLoadingLocation ? null : _getCurrentLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSecondaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_isLoadingLocation)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Getting location...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _currentAddress ?? 'Tap to detect your location',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretDown(),
              color: AppColors.onSecondaryContainer,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentAddress = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentAddress =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _currentAddress = 'Failed to get location';
        _isLoadingLocation = false;
      });
    }
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
// Shared widgets
// ─────────────────────────────────────────────────────────────────

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
