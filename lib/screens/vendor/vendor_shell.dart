import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_colors.dart';
import 'vendor_dashboard_screen.dart';
import 'vendor_scanner_screen.dart';
import 'vendor_billing_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_promotions_screen.dart';

class VendorShell extends StatefulWidget {
  const VendorShell({super.key});

  @override
  State<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<VendorShell> {
  int _currentIndex = 0;

  void setTab(int index) => setState(() => _currentIndex = index);

  // Maps the 4-tab index to the 3-slot IndexedStack index,
  // skipping slot 1 (scanner) which lives outside the stack.
  int get _stackIndex => switch (_currentIndex) {
        2 => 1,
        3 => 2,
        4 => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // Dashboard, Billing, Profile stay alive in memory.
            IndexedStack(
              index: _stackIndex,
              children: [
                VendorDashboardScreen(onScanTap: () => setTab(1)),
                const VendorBillingScreen(),
                const VendorProfileScreen(),
                const VendorPromotionsScreen(),
              ],
            ),
            // Scanner mounts/unmounts so the camera starts and stops correctly.
            if (_currentIndex == 1) const VendorScannerScreen(),
          ],
        ),
        bottomNavigationBar: _VendorBottomNav(
          currentIndex: _currentIndex,
          onTap: setTab,
        ),
      ),
    );
  }
}

// ── Vendor bottom nav ─────────────────────────────────────────────

class _VendorBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _VendorBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.88),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    label: 'Dashboard',
                    icon: PhosphorIcons.storefront(),
                    activeIcon:
                        PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    label: 'Scanner',
                    icon: PhosphorIcons.qrCode(),
                    activeIcon:
                        PhosphorIcons.qrCode(PhosphorIconsStyle.fill),
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    label: 'Billing',
                    icon: PhosphorIcons.creditCard(),
                    activeIcon:
                        PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    label: 'Profile',
                    icon: PhosphorIcons.user(),
                    activeIcon:
                        PhosphorIcons.user(PhosphorIconsStyle.fill),
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _NavItem(
                    label: 'Promote',
                    icon: PhosphorIcons.megaphone(),
                    activeIcon:
                        PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(9999),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? AppColors.onPrimaryFixed
                  : AppColors.onSurface.withOpacity(0.45),
              size: 26,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.onPrimaryFixed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
