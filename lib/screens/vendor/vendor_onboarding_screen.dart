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

class VendorOnboardingScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const VendorOnboardingScreen({super.key, this.initialData});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  String _address = '';
  double? _lat;
  double? _lng;
  String _category = 'Other';
  int _stampGoal = 10;
  XFile? _image;
  bool _loading = false;
  String? _error;
  String? _existingImageUrl;
  Map<String, dynamic> _businessHours = {
    'Mon': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
    'Tue': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
    'Wed': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
    'Thu': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
    'Fri': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
    'Sat': {'isOpen': false, 'open': '09:00', 'close': '13:00'},
    'Sun': {'isOpen': false, 'open': '09:00', 'close': '13:00'},
  };

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
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameCtrl.text = data['name'] as String? ?? '';
      _rewardCtrl.text = data['rewardDescription'] as String? ?? '';
      _address = data['address'] as String? ?? '';
      _lat = data['lat'] as double?;
      _lng = data['lng'] as double?;
      _category = data['category'] as String? ?? 'Other';
      _stampGoal = data['stampGoal'] as int? ?? 10;
      _existingImageUrl = data['imageUrl'] as String?;
      if (data['businessHours'] != null) {
        _businessHours = Map<String, dynamic>.from(data['businessHours']);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _image = picked);
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your business name.');
      return;
    }
    if (_address.isEmpty) {
      setState(() => _error = 'Please select your business address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? imageUrl;

      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final ref = FirebaseStorage.instance.ref('businesses/$uid/profile.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      } else {
        imageUrl = _existingImageUrl;
      }

      await FirebaseFirestore.instance.collection('businesses').doc(uid).set({
        'name': name,
        'address': _address,
        'category': _category,
        'imageUrl': imageUrl,
        'ownerId': uid,
        'status': 'pending', // Revert to pending on resubmission
        'totalStamps': widget.initialData?['totalStamps'] ?? 0,
        'stampGoal': _stampGoal,
        'rewardDescription': _rewardCtrl.text.trim(),
        'lat': _lat ?? 0.0,
        'lng': _lng ?? 0.0,
        'businessHours': _businessHours,
        'createdAt': widget.initialData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
      }, SetOptions(merge: true));
      // No manual navigation — the business-doc stream in _RoleRouter
      // detects the new doc and automatically switches to VendorShell.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                      color: AppColors.onPrimary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Set up your business',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell customers what makes you special.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSecondaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Business photo ──────────────────────────────────────
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
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: _image != null
                          ? ClipOval(
                              child: Image.file(
                                File(_image!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : _existingImageUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    _existingImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                                  color: AppColors.onSecondaryContainer,
                                  size: 40,
                                ),
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
            const SizedBox(height: 8),
            Center(
              child: Text(
                _image == null && _existingImageUrl == null
                    ? 'Add business photo (optional)'
                    : 'Tap to change photo',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Business name ──────────────────────────────────────
            _Label('Business Name'),
            const SizedBox(height: 8),
            _Field(
              controller: _nameCtrl,
              hint: 'e.g. The Daily Grind',
              action: TextInputAction.next,
            ),

            const SizedBox(height: 20),

            // ── Address ────────────────────────────────────────────
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

            // ── Category ───────────────────────────────────────────
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

            const SizedBox(height: 28),

            // ── Stamp goal ─────────────────────────────────────────
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

            // ── Reward description ─────────────────────────────────
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
            _Field(
              controller: _rewardCtrl,
              hint: 'e.g. Free coffee after $_stampGoal stamps',
              action: TextInputAction.done,
            ),

            const SizedBox(height: 28),

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

            const SizedBox(height: 28),

            // ── Error ──────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Submit ─────────────────────────────────────────────
            GestureDetector(
              onTap: _loading ? null : _submit,
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
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Launch my business',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputAction action;

  const _Field({
    required this.controller,
    required this.hint,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: action,
      style: GoogleFonts.beVietnamPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 15,
          fontWeight: FontWeight.w500,
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
