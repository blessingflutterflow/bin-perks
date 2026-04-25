import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Placeholder content ─────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.outlineVariant.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.fill),
                    color: AppColors.primary,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Your Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coming soon',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),

          // ── Glass top app bar ─────────────────────────────────────
          Positioned(
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
                      Icon(PhosphorIcons.list(),
                          color: AppColors.primary, size: 28),
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
