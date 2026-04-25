import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

class MerchantScanScreen extends StatefulWidget {
  const MerchantScanScreen({super.key});

  @override
  State<MerchantScanScreen> createState() => _MerchantScanScreenState();
}

class _MerchantScanScreenState extends State<MerchantScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  final TextEditingController _codeController = TextEditingController();

  final List<Map<String, String>> _nearby = const [
    {
      'name': 'The Bean Gallery',
      'distance': '200m away',
      'seed': 'coffee10',
    },
    {
      'name': 'Velvet Thread',
      'distance': '450m away',
      'seed': 'clothes11',
    },
    {
      'name': 'The Daily Press',
      'distance': '600m away',
      'seed': 'cafe12',
    },
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: topPad + 80),

                // Guidance text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        'Scan business QR code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Align the QR code within the frame\nto earn your perks automatically.',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondary,
                          height: 1.55,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Scanner viewfinder ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxWidth;
                        return Stack(
                          children: [
                            // Corner bracket – top left
                            _Corner(top: true, left: true),
                            _Corner(top: true, left: false),
                            _Corner(top: false, left: true),
                            _Corner(top: false, left: false),

                            // Viewfinder content
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Blurred camera-like background
                                      ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.35),
                                          BlendMode.darken,
                                        ),
                                        child: Image.network(
                                          'https://picsum.photos/seed/cafeinterior/600/600',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                  color: AppColors.inverseSurface),
                                        ),
                                      ),

                                      // Scan line animation
                                      AnimatedBuilder(
                                        animation: _scanAnimation,
                                        builder: (context, _) {
                                          return Positioned(
                                            top: _scanAnimation.value * size,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 2.5,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    AppColors.primary,
                                                    Colors.transparent,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.7),
                                                    blurRadius: 10,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      // Top/bottom gradient vignette
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.38),
                                              Colors.transparent,
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.38),
                                            ],
                                            stops: const [0, 0.25, 0.75, 1],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 44),

                // ── Manual entry ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Code input
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: TextField(
                          controller: _codeController,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter code manually',
                            hintStyle: GoogleFonts.beVietnamPro(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.outline,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 20, right: 12),
                              child: Icon(
                                PhosphorIcons.key(),
                                color: AppColors.outline,
                                size: 22,
                              ),
                            ),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 0, minHeight: 0),
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: Text(
                            'Submit Code',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Trouble link
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'TROUBLE SCANNING?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Nearby merchants ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearby Merchants',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'See All',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _nearby.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final m = _nearby[index];
                      return _NearbyCard(
                        name: m['name']!,
                        distance: m['distance']!,
                        imageUrl:
                            'https://picsum.photos/seed/${m['seed']}/300/200',
                      );
                    },
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),

          // ── Glass top app bar (back button) ──────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: AppColors.surface.withOpacity(0.88),
                  padding: EdgeInsets.only(top: topPad, left: 16, right: 20),
                  height: topPad + 64,
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Icon(
                            PhosphorIcons.arrowLeft(),
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Check In',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        backgroundImage: const NetworkImage(
                            'https://picsum.photos/seed/avatar99/100/100'),
                      ),
                    ],
                  ),
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
// Scanner corner bracket
// ─────────────────────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft:
                (top && left) ? const Radius.circular(12) : Radius.zero,
            topRight:
                (top && !left) ? const Radius.circular(12) : Radius.zero,
            bottomLeft:
                (!top && left) ? const Radius.circular(12) : Radius.zero,
            bottomRight:
                (!top && !left) ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Nearby merchant card
// ─────────────────────────────────────────────────────────────────

class _NearbyCard extends StatelessWidget {
  final String name;
  final String distance;
  final String imageUrl;

  const _NearbyCard({
    required this.name,
    required this.distance,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(
              imageUrl,
              height: 106,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 106,
                color: AppColors.surfaceContainerHigh,
                child: Center(
                  child: Icon(
                    PhosphorIcons.image(),
                    color: AppColors.onSurfaceVariant,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      color: AppColors.primary,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distance,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
