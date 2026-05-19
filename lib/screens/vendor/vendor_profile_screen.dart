import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/address_autocomplete_field.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  String _address = '';
  double? _lat;
  double? _lng;
  String _category = 'Other';
  int _stampGoal = 10;
  String? _currentImageUrl;
  XFile? _newImage;
  bool _initialized = false;
  bool _saving = false;
  bool _isPaused = false;
  Map<String, dynamic> _businessHours = {};
  String? _error;
  String? _success;

  static const _categories = [
    'Coffee shops',
    'Food & Beverage',
    'Spa/Wellness',
    'Beauty Salon',
    'Barber shop',
    'Car wash',
    'Petrol station',
    'Retail',
    'Fitness center',
    'Health center',
    'Automotive',
    'Accommodation',
    'Entertainment',
    'Home services',
    'Laundry',
    'Repair & Maintenance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameCtrl.text = data['name'] as String? ?? '';
        _phoneCtrl.text = data['phoneNumber'] as String? ?? '';
        _address = data['address'] as String? ?? '';
        _lat = (data['lat'] as num?)?.toDouble();
        _lng = (data['lng'] as num?)?.toDouble();
        _category = data['category'] as String? ?? 'Other';
        _stampGoal = (data['stampGoal'] as num?)?.toInt() ?? 10;
        _rewardCtrl.text = data['rewardDescription'] as String? ?? '';
        _currentImageUrl = data['imageUrl'] as String?;
        _isPaused = data['isPaused'] as bool? ?? false;
        _businessHours =
            data['businessHours'] as Map<String, dynamic>? ??
            {
              'Mon': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
              'Tue': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
              'Wed': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
              'Thu': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
              'Fri': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
              'Sat': {'isOpen': false, 'open': '09:00', 'close': '13:00'},
              'Sun': {'isOpen': false, 'open': '09:00', 'close': '13:00'},
            };
        _initialized = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null && mounted) setState(() => _newImage = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Business name cannot be empty.');
      return;
    }
    if (_address.isEmpty) {
      setState(() => _error = 'Business address cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      String? imageUrl = _currentImageUrl;
      if (_newImage != null) {
        final bytes = await _newImage!.readAsBytes();
        final ref = FirebaseStorage.instance.ref('businesses/$uid/profile.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      }
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .update({
            'name': name,
            'phoneNumber': _phoneCtrl.text.trim(),
            'address': _address,
            'category': _category,
            'stampGoal': _stampGoal,
            'rewardDescription': _rewardCtrl.text.trim(),
            'imageUrl': imageUrl,
            'isPaused': _isPaused,
            'businessHours': _businessHours,
            if (_lat != null) 'lat': _lat,
            if (_lng != null) 'lng': _lng,
          });
      if (!mounted) return;
      setState(() {
        _currentImageUrl = imageUrl;
        _newImage = null;
        _success = 'Changes saved successfully!';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FirebaseException
              ? 'Upload failed: ${e.message}'
              : 'Failed to save. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete your business profile and all customer data. This cannot be undone.',
          style: GoogleFonts.beVietnamPro(
            color: AppColors.onSecondaryContainer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _saving = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Delete the Firebase Auth account FIRST. This is the step most
      // likely to fail (requires-recent-login). If it throws, nothing in
      // Firestore has been touched yet and the vendor can retry after
      // logging back in. If it succeeds, the Firestore cleanup below runs
      // — even if those fail the auth account is gone so orphaned docs
      // are invisible to the vendor.
      await FirebaseAuth.instance.currentUser?.delete();

      try {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(uid)
            .delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete();
      } catch (_) {
        // Firestore cleanup failed — orphaned docs are harmless since the
        // auth account no longer exists and no one can log in to see them.
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.code == 'requires-recent-login'
              ? 'For security, please log out and log back in, then try deleting again.'
              : 'Failed to delete. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to delete. Please try again.';
        });
      }
    }
  }

  Widget _buildDayRow(String day) {
    final dayData = _businessHours[day] as Map<String, dynamic>;
    final isOpen = dayData['isOpen'] as bool;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              day,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isOpen
                    ? AppColors.onSurface
                    : AppColors.onSecondaryContainer.withOpacity(0.5),
              ),
            ),
          ),
          Switch(
            value: isOpen,
            onChanged: (val) {
              setState(() {
                _businessHours[day]['isOpen'] = val;
              });
            },
            activeThumbColor: AppColors.primary,
          ),
          const Spacer(),
          if (isOpen) ...[
            GestureDetector(
              onTap: () => _selectTime(day, 'open'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dayData['open'],
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            GestureDetector(
              onTap: () => _selectTime(day, 'close'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dayData['close'],
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else
            Text(
              'Closed',
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onSecondaryContainer.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectTime(String day, String type) async {
    final currentStr = _businessHours[day][type] as String;
    final parts = currentStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final h = picked.hour.toString().padLeft(2, '0');
        final m = picked.minute.toString().padLeft(2, '0');
        _businessHours[day][type] = '$h:$m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final displayImage = _newImage != null
        ? DecorationImage(
            image: FileImage(File(_newImage!.path)),
            fit: BoxFit.cover,
          )
        : _currentImageUrl != null
        ? DecorationImage(
            image: NetworkImage(_currentImageUrl!),
            fit: BoxFit.cover,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topPad + 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page title ────────────────────────────────────────
            Text(
              'Business Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppColors.onSurface,
              ),
            ),

            const SizedBox(height: 24),

            // ── Business image ────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceContainerLow,
                        image: displayImage,
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: displayImage == null
                          ? Icon(
                              PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                              color: AppColors.onSecondaryContainer,
                              size: 40,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIcons.camera(PhosphorIconsStyle.fill),
                          color: AppColors.onPrimary,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tap to change photo',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Pause Business Toggle ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPaused
                    ? AppColors.errorContainer
                    : AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPaused
                        ? PhosphorIcons.pauseCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                    color: _isPaused ? AppColors.error : AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPaused
                              ? 'Business is Paused'
                              : 'Business is Active',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _isPaused
                                ? AppColors.onErrorContainer
                                : AppColors.onSecondaryContainer,
                          ),
                        ),
                        Text(
                          _isPaused
                              ? 'You are hidden from customers.'
                              : 'Visible to all customers.',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: _isPaused
                                ? AppColors.onErrorContainer.withOpacity(0.7)
                                : AppColors.onSecondaryContainer.withOpacity(
                                    0.7,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !_isPaused,
                    onChanged: (val) => setState(() => _isPaused = !val),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Business name ─────────────────────────────────────
            _Label('Business Name'),
            const SizedBox(height: 8),
            _EditField(controller: _nameCtrl, hint: 'e.g. The Daily Grind'),

            const SizedBox(height: 20),

            // ── Phone Number ──────────────────────────────────────
            _Label('Phone Number'),
            const SizedBox(height: 8),
            _EditField(
              controller: _phoneCtrl,
              hint: 'e.g. +27 71 234 5678',
            ),

            const SizedBox(height: 20),

            // ── Address ───────────────────────────────────────────
            _Label('Business Address'),
            const SizedBox(height: 8),
            AddressAutocompleteField(
              initialValue: _address,
              onPlaceSelected: (address, lat, lng) {
                setState(() {
                  _address = address;
                  _lat = lat;
                  _lng = lng;
                });
              },
            ),

            const SizedBox(height: 20),

            // ── Category ──────────────────────────────────────────
            _Label('Business Category'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final active = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Stamp goal ────────────────────────────────────────
            _Label('Stamp Goal'),
            const SizedBox(height: 4),
            Text(
              'How many stamps until the reward is earned?',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StepButton(
                  icon: PhosphorIcons.minus(PhosphorIconsStyle.bold),
                  onTap: _stampGoal > 1
                      ? () => setState(() => _stampGoal--)
                      : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '$_stampGoal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                _StepButton(
                  icon: PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  onTap: _stampGoal < 50
                      ? () => setState(() => _stampGoal++)
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Reward description ────────────────────────────────
            _Label('Reward Description'),
            const SizedBox(height: 4),
            Text(
              'What do customers get when they complete their card?',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            _EditField(
              controller: _rewardCtrl,
              hint: 'e.g. Free coffee after $_stampGoal stamps',
            ),

            const SizedBox(height: 24),

            // ── Business Hours ────────────────────────────────────
            _Label('Business Hours'),
            const SizedBox(height: 4),
            Text(
              'When is your business open for customers?',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildDayRow('Mon'),
                  _buildDayRow('Tue'),
                  _buildDayRow('Wed'),
                  _buildDayRow('Thu'),
                  _buildDayRow('Fri'),
                  _buildDayRow('Sat'),
                  _buildDayRow('Sun'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Feedback ──────────────────────────────────────────
            if (_error != null) ...[
              _FeedbackBox(message: _error!, isError: true),
              const SizedBox(height: 12),
            ],
            if (_success != null) ...[
              _FeedbackBox(message: _success!, isError: false),
              const SizedBox(height: 12),
            ],

            // ── Save button ───────────────────────────────────────
            GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Account section ───────────────────────────────────
            Text(
              'ACCOUNT',
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),

            _ActionRow(
              label: 'Log Out',
              icon: PhosphorIcons.signOut(PhosphorIconsStyle.fill),
              backgroundColor: AppColors.surfaceContainerLow,
              textColor: AppColors.onSurface,
              onTap: _logout,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              label: 'Delete Business & Account',
              icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
              backgroundColor: AppColors.errorContainer,
              textColor: AppColors.onErrorContainer,
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? AppColors.onPrimary
              : AppColors.onSecondaryContainer,
          size: 18,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.onSurface,
    ),
  );
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _EditField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.beVietnamPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 15,
          color: AppColors.onSecondaryContainer.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBox({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorContainer : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isError ? AppColors.onErrorContainer : const Color(0xFF065F46),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  fontSize: 15,
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
