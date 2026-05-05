import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // ── Stats loaded once from Firestore ─────────────────────────────
  int _totalCards = 0;
  int _totalStamps = 0;
  int _totalRedeemed = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = _user;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('loyalties')
        .where('customerId', isEqualTo: user.uid)
        .get();

    int stamps = 0;
    int redeemed = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      stamps += (d['stampCount'] as num?)?.toInt() ?? 0;
      redeemed += (d['redeemedCount'] as num?)?.toInt() ?? 0;
    }

    if (mounted) {
      setState(() {
        _totalCards = snap.size;
        _totalStamps = stamps;
        _totalRedeemed = redeemed;
        _statsLoaded = true;
      });
    }
  }

  // ── Profile Image ─────────────────────────────────────────────────
  bool _uploadingImage = false;

  Future<void> _pickImage() async {
    final user = _user;
    if (user == null) return;
    
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (picked == null || !mounted) return;

      setState(() => _uploadingImage = true);

      final file = File(picked.path);
      final ref = FirebaseStorage.instance.ref('users/${user.uid}/profile.jpg');
      
      // Use putFile for better reliability on mobile
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final photoUrl = await ref.getDownloadURL();

      await user.updatePhotoURL(photoUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoUrl': photoUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  // ── Edit name ─────────────────────────────────────────────────────
  Future<void> _editName() async {
    final controller = TextEditingController(
      text: _user?.displayName ?? '',
    );
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Display Name',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: GoogleFonts.beVietnamPro(
                    color: AppColors.onSecondaryContainer,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pop(ctx, controller.text.trim()),
                  child: Text(
                    'Save',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final user = _user;
    if (newName != null && newName.isNotEmpty && user != null && newName != user.displayName) {
      await user.updateDisplayName(newName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'displayName': newName}, SetOptions(merge: true));
      setState(() {});
    }
  }

  // ── Reset password ────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final email = _user?.email;
    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'We will send a password reset link to:\n\n$email',
          style: GoogleFonts.beVietnamPro(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password reset email sent!',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF00875A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Delete account ────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete Account',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all loyalty card progress. This cannot be undone.',
          style: GoogleFonts.beVietnamPro(
            color: AppColors.onSecondaryContainer,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _user?.delete();
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'requires-recent-login'
                  ? 'Please log out and log back in, then try again.'
                  : 'Could not delete account: ${e.message}',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final user = _user;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: topPad + 24,
          left: 20,
          right: 20,
          bottom: 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Text(
              'Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),

            const SizedBox(height: 28),

            // ── Avatar + info + edit ─────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: _uploadingImage ? null : _pickImage,
                  child: Stack(
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
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.surface,
                            shape: BoxShape.circle,
                            image: user?.photoURL != null
                                ? DecorationImage(
                                    image: NetworkImage(user!.photoURL!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _uploadingImage
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : (user?.photoURL == null
                                  ? Center(
                                      child: Icon(
                                        PhosphorIcons.user(PhosphorIconsStyle.fill),
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    )
                                  : null),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkSurface : AppColors.surface,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIcons.camera(PhosphorIconsStyle.fill),
                              color: AppColors.primary,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user?.displayName?.isNotEmpty == true
                                  ? user!.displayName!
                                  : 'Add your name',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: user?.displayName?.isNotEmpty == true
                                    ? (isDark
                                          ? AppColors.darkOnSurface
                                          : AppColors.onSurface)
                                    : AppColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _editName,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                PhosphorIcons.pencilSimple(),
                                size: 16,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
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

            // Role badge
            Padding(
              padding: const EdgeInsets.only(left: 92),
              child: StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots()
                    : null,
                builder: (context, snapshot) {
                  String roleLabel = 'Customer';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final role = data['role'] ?? 'customer';
                    roleLabel = role == 'vendor' ? 'Vendor' : 'Customer';
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                          size: 12,
                        ),
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

            // ── Real stats row ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerLow
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkOutlineVariant.withValues(alpha: 0.2)
                      : AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: _statsLoaded
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                            value: '$_totalCards', label: 'Loyalty Cards'),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                        _StatChip(
                            value: '$_totalStamps', label: 'Stamps'),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                        _StatChip(
                            value: '$_totalRedeemed', label: 'Redeemed'),
                      ],
                    )
                  : const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 28),

            // ── Reward History ────────────────────────────────────────
            Text(
              'Reward History',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _RewardHistory(uid: user?.uid ?? ''),

            const SizedBox(height: 28),

            // ── Light/Dark mode toggle ────────────────────────────────
            _ToggleRow(
              label: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: isDark
                  ? PhosphorIcons.sun(PhosphorIconsStyle.fill)
                  : PhosphorIcons.moon(PhosphorIconsStyle.fill),
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),

            const SizedBox(height: 28),

            // ── Account Settings ──────────────────────────────────────
            Text(
              'Account Settings',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSecondaryContainer,
              ),
            ),

            const SizedBox(height: 12),

            _ActionCard(
              label: 'Reset Password',
              backgroundColor: isDark
                  ? AppColors.darkSurfaceContainerLow
                  : AppColors.surfaceContainerLow,
              textColor:
                  isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              icon: PhosphorIcons.caretRight(),
              onTap: _resetPassword,
            ),

            const SizedBox(height: 12),

            _ActionCard(
              label: 'Delete Account',
              backgroundColor: AppColors.errorContainer,
              textColor: AppColors.onErrorContainer,
              icon: PhosphorIcons.userMinus(),
              onTap: _deleteAccount,
            ),

            const SizedBox(height: 32),

            // ── Log Out ───────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerHigh
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                'V1.3.5-33',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reward history widget ─────────────────────────────────────────

class _RewardHistory extends StatelessWidget {
  final String uid;
  const _RewardHistory({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('redemptions')
          .where('customerId', isEqualTo: uid)
          .orderBy('redeemedAt', descending: true)
          .limit(20)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.gift(PhosphorIconsStyle.regular),
                  size: 32,
                  color: AppColors.onSecondaryContainer
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'No rewards redeemed yet',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final idx = entry.key;
              final doc = entry.value;
              final d = doc.data() as Map<String, dynamic>;
              final businessName =
                  d['businessName'] as String? ?? 'Unknown Business';
              final rewardDescription =
                  d['rewardDescription'] as String? ?? 'Reward';
              final ts = d['redeemedAt'] as Timestamp?;
              final date = ts != null
                  ? _formatDate(ts.toDate())
                  : '—';

              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                      height: 1,
                      color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      indent: 56,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7C3AED),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIcons.gift(PhosphorIconsStyle.fill),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rewardDescription,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSecondaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          date,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Stat chip ─────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSecondaryContainer,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────

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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 30,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.darkSurfaceContainerHigh
                        : AppColors.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Align(
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value
                        ? AppColors.onPrimary
                        : (isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.outline),
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
      ),
    );
  }
}

// ── Action card ───────────────────────────────────────────────────

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
            Icon(icon, color: textColor.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }
}
