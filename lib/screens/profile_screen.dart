import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: topPad + 24, left: 20, right: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Text(
              'Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppColors.onSurface,
              ),
            ),

            const SizedBox(height: 28),

            // ── Avatar + info ──────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.fill),
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Blessing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'hello@binperks.com',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Role badge from Firestore
            Padding(
              padding: const EdgeInsets.only(left: 92),
              child: StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                    : null,
                builder: (context, snapshot) {
                  String roleLabel = 'Member';
                  IconData roleIcon = PhosphorIcons.crown(PhosphorIconsStyle.fill);
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final role = data['role'] ?? 'customer';
                    roleLabel = role == 'vendor' ? 'Vendor' : 'Customer';
                    roleIcon = role == 'vendor'
                        ? PhosphorIcons.storefront(PhosphorIconsStyle.fill)
                        : PhosphorIcons.user(PhosphorIconsStyle.fill);
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, color: AppColors.primary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          roleLabel,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Reward stats ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(value: '2,450', label: 'Points'),
                  Container(width: 1, height: 32, color: AppColors.outlineVariant.withOpacity(0.3)),
                  _StatChip(value: '12', label: 'Streak'),
                  Container(width: 1, height: 32, color: AppColors.outlineVariant.withOpacity(0.3)),
                  _StatChip(value: '47', label: 'Visits'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Light-mode toggle row ─────────────────────────────
            _ToggleRow(
              label: 'Switch to Light Mode',
              icon: PhosphorIcons.sun(PhosphorIconsStyle.fill),
              value: true,
              onChanged: (_) {},
            ),

            const SizedBox(height: 28),

            // ── Flyer Box card ───────────────────────────────────
            _ActionCard(
              label: 'Flyer Box',
              backgroundColor: AppColors.tertiaryContainer,
              textColor: AppColors.onTertiary,
              icon: PhosphorIcons.caretRight(),
              onTap: () {},
            ),

            const SizedBox(height: 28),

            // ── Account Settings label ───────────────────────────
            Text(
              'Account Settings',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryContainer,
              ),
            ),

            const SizedBox(height: 12),

            // ── Reset Password ────────────────────────────────────
            _ActionCard(
              label: 'Reset Password',
              backgroundColor: AppColors.surfaceContainerLow,
              textColor: AppColors.onSurface,
              icon: PhosphorIcons.caretRight(),
              onTap: () {},
            ),

            const SizedBox(height: 12),

            // ── Delete Account ───────────────────────────────────
            _ActionCard(
              label: 'Delete Account',
              backgroundColor: AppColors.errorContainer,
              textColor: AppColors.onErrorContainer,
              icon: PhosphorIcons.userMinus(),
              onTap: () {},
            ),

            const SizedBox(height: 32),

            // ── Log Out ───────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Version ───────────────────────────────────────────
            Center(
              child: Text(
                'V1.3.5-33',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.onSecondaryContainer,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Toggle row widget ────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 30,
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? AppColors.onPrimary : AppColors.outline,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: value ? AppColors.primary : AppColors.onPrimary,
                  size: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action card widget ───────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            Icon(icon, color: textColor.withOpacity(0.7), size: 20),
          ],
        ),
      ),
    );
  }
}
