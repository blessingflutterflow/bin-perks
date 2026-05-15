import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../main.dart';

// ── Location state ────────────────────────────────────────────────
enum _LocState { loading, active, denied, deniedForever, serviceOff }

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {

  int _selectedCategory = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Position? _position;
  String? _locationName;
  String? _locationFull;
  _LocState _locState = _LocState.loading;
  StreamSubscription<Position>? _posSub;

  static const _categories = [
    'All Nearby',
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
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ── Location bootstrap ────────────────────────────────────────

  Future<void> _initLocation() async {
    setState(() => _locState = _LocState.loading);

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _locState = _LocState.serviceOff);
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locState = _LocState.deniedForever);
      return;
    }

    if (perm == LocationPermission.denied) {
      if (mounted) setState(() => _locState = _LocState.denied);
      return;
    }

    // Permission granted — subscribe to live stream
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // update every 20 m of movement
      ),
    ).listen(
      (pos) {
        if (!mounted) return;
        final isFirst = _position == null;
        setState(() {
          _position = pos;
          _locState = _LocState.active;
        });
        // Reverse-geocode only on the first fix
        if (isFirst) _reverseGeocode(pos);
      },
      onError: (_) {
        if (mounted) setState(() => _locState = _LocState.denied);
      },
    );
  }

  Future<void> _reverseGeocode(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted || placemarks.isEmpty) {
        debugPrint('[Geocode] no placemarks for ${pos.latitude},${pos.longitude}');
        return;
      }
      final place = placemarks.first;

      // Safely unwrap every field — the geocoder can return null for any of them
      final subLocality     = place.subLocality     ?? '';
      final locality        = place.locality        ?? '';
      final name            = place.name            ?? '';
      final street          = place.street          ?? '';
      final adminArea       = place.administrativeArea ?? '';
      final country         = place.country         ?? '';

      // Best short label: subLocality → locality → name
      final short = subLocality.isNotEmpty ? subLocality
          : locality.isNotEmpty            ? locality
          : name;

      // Full readable address — only include non-empty parts
      final full = [street, subLocality, locality, adminArea, country]
          .where((s) => s.isNotEmpty)
          .join(', ');

      debugPrint('[Geocode] short="$short" full="$full"');

      if (short.isNotEmpty && mounted) {
        setState(() {
          _locationName = short;
          _locationFull = full.isNotEmpty ? full : short;
        });
      } else {
        debugPrint('[Geocode] all fields empty — cannot resolve name');
      }
    } catch (e) {
      debugPrint('[Geocode] error: $e');
    }
  }

  // ── Distance helpers ──────────────────────────────────────────

  double _metersTo(Map<String, dynamic> data) {
    if (_position == null) return double.maxFinite;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      return double.maxFinite;
    }
    return Geolocator.distanceBetween(
        _position!.latitude, _position!.longitude, lat, lng);
  }

  String _distanceLabel(Map<String, dynamic> data) {
    final m = _metersTo(data);
    if (m == double.maxFinite) return '';
    if (m < 1000) return '${m.toInt()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  void _showBusinessSheet(Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final appShell = context.findAncestorStateOfType<AppShellState>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BusinessSheet(
        businessId: data['_id'] as String,
        data: data,
        customerId: uid,
        onJoined: () {
          Navigator.pop(context); // Close the bottom sheet
          appShell?.setTab(1); // Go to Rewards tab
        },
      ),
    );
  }

  bool _isOpenNow(Map<String, dynamic> data) {
    final hours = data['businessHours'] as Map<String, dynamic>?;
    if (hours == null) return true; // Default to open if no hours set

    final now = DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayKey = dayNames[now.weekday - 1];
    
    final dayData = hours[dayKey] as Map<String, dynamic>?;
    if (dayData == null || dayData['isOpen'] != true) return false;

    final openStr = dayData['open'] as String? ?? '00:00';
    final closeStr = dayData['close'] as String? ?? '23:59';

    final openParts = openStr.split(':');
    final closeParts = closeStr.split(':');

    final openTime = DateTime(now.year, now.month, now.day, int.parse(openParts[0]), int.parse(openParts[1]));
    final closeTime = DateTime(now.year, now.month, now.day, int.parse(closeParts[0]), int.parse(closeParts[1]));

    return now.isAfter(openTime) && now.isBefore(closeTime);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final selectedCat = _categories[_selectedCategory.clamp(0, _categories.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('businesses')
                .snapshots(),
            builder: (context, snap) {
              List<Map<String, dynamic>> businesses = [];

              if (snap.hasData) {
                businesses = snap.data!.docs.map((d) {
                  return {'_id': d.id, ...(d.data() as Map<String, dynamic>)};
                }).where((b) {
                  final status = b['status'] == 'approved';
                  final notPaused = b['isPaused'] != true;
                  final matchesSearch = _searchQuery.isEmpty || 
                      (b['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                  return status && notPaused && matchesSearch;
                }).toList();

                if (selectedCat != 'All Nearby') {
                  businesses = businesses
                      .where((b) => b['category'] == selectedCat)
                      .toList();
                }

                businesses.sort(
                    (a, b) => _metersTo(a).compareTo(_metersTo(b)));
              }

              final leftCol = <Map<String, dynamic>>[];
              final rightCol = <Map<String, dynamic>>[];
              for (var i = 0; i < businesses.length; i++) {
                (i.isEven ? leftCol : rightCol).add(businesses[i]);
              }

              return CustomScrollView(
                slivers: [
                  // Location bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
                      child: _LocationBar(
                        locState: _locState,
                        locationName: _locationName,
                        locationFull: _locationFull,
                        position: _position,
                        onRetry: _initLocation,
                        onOpenSettings: Geolocator.openAppSettings,
                      ),
                    ),
                  ),

                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search businesses...',
                            hintStyle: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              color: AppColors.onSecondaryContainer.withOpacity(0.5),
                            ),
                            prefixIcon: Icon(
                              PhosphorIcons.magnifyingGlass(),
                              color: AppColors.onSecondaryContainer,
                              size: 18,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                                      color: AppColors.onSecondaryContainer,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Editorial header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 28, 20, 4),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final active = _selectedCategory == index;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedCategory = index),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.secondaryContainer,
                                borderRadius:
                                    BorderRadius.circular(9999),
                              ),
                              child: Text(
                                _categories[index],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? AppColors.onPrimary
                                      : AppColors
                                          .onSecondaryContainer,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 24)),

                  // Business list
                  if (snap.connectionState == ConnectionState.waiting)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                    )
                  else if (businesses.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 48),
                        child: Center(
                          child: Text(
                            selectedCat == 'All Nearby'
                                ? 'No businesses yet.\nCheck back soon!'
                                : 'No $selectedCat businesses yet.',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 15,
                              color: AppColors.onSecondaryContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: leftCol
                                    .asMap()
                                    .entries
                                    .map((e) => _BusinessCard(
                                          data: e.value,
                                          distanceLabel:
                                              _distanceLabel(e.value),
                                          isOpen: _isOpenNow(e.value),
                                          aspectRatio: e.key.isEven
                                              ? 4 / 3
                                              : 3 / 4,
                                          onTap: () => _showBusinessSheet(
                                              e.value),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: rightCol
                                    .asMap()
                                    .entries
                                    .map((e) => _BusinessCard(
                                          data: e.value,
                                          distanceLabel:
                                              _distanceLabel(e.value),
                                          isOpen: _isOpenNow(e.value),
                                          aspectRatio: e.key.isEven
                                              ? 3 / 4
                                              : 4 / 3,
                                          onTap: () => _showBusinessSheet(
                                              e.value),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 120)),
                ],
              );
            },
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Location bar — handles all states
// ─────────────────────────────────────────────────────────────────

class _LocationBar extends StatelessWidget {
  final _LocState locState;
  final String? locationName;
  final String? locationFull;
  final Position? position;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  const _LocationBar({
    required this.locState,
    required this.locationName,
    required this.locationFull,
    required this.position,
    required this.onRetry,
    required this.onOpenSettings,
  });

  void _showFullAddress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Location',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSecondaryContainer,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locationName ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (locationFull != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  locationFull!,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSecondaryContainer,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget trailing = const SizedBox.shrink();
    String label;
    Color? labelColor;

    switch (locState) {
      case _LocState.loading:
        label = 'Detecting location…';
        trailing = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        );
      case _LocState.active:
        label = locationName ?? 'Locating neighbourhood…';
        trailing = locationName != null
            ? Icon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                color: AppColors.onSecondaryContainer,
                size: 16,
              )
            : const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              );
      case _LocState.denied:
        label = 'Location denied — tap to retry';
        labelColor = AppColors.error;
        trailing = Icon(
          PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
          color: AppColors.error,
          size: 18,
        );
      case _LocState.deniedForever:
        label = 'Enable location in Settings';
        labelColor = AppColors.error;
        trailing = Icon(
          PhosphorIcons.arrowSquareOut(PhosphorIconsStyle.bold),
          color: AppColors.error,
          size: 18,
        );
      case _LocState.serviceOff:
        label = 'Location services are off';
        labelColor = AppColors.onSecondaryContainer;
        trailing = Icon(
          PhosphorIcons.wifiSlash(PhosphorIconsStyle.bold),
          color: AppColors.onSecondaryContainer,
          size: 18,
        );
    }

    return GestureDetector(
      onTap: () {
        if (locState == _LocState.active && locationName != null) {
          _showFullAddress(context);
        } else if (locState == _LocState.deniedForever ||
            locState == _LocState.serviceOff) {
          onOpenSettings();
        } else if (locState == _LocState.denied) {
          onRetry();
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.25)),
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
                    'Your Location',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSecondaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: labelColor ?? AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Business card
// ─────────────────────────────────────────────────────────────────

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String distanceLabel;
  final bool isOpen;
  final double aspectRatio;
  final VoidCallback? onTap;

  const _BusinessCard({
    required this.data,
    required this.distanceLabel,
    required this.isOpen,
    required this.aspectRatio,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
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
                      aspectRatio: aspectRatio,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _Placeholder(aspectRatio: aspectRatio),
                            )
                          : _Placeholder(aspectRatio: aspectRatio),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOpen ? const Color(0xFF00875A) : AppColors.error).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOpen ? 'OPEN' : 'CLOSED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (distanceLabel.isNotEmpty)
                            Flexible(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9999),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    color: AppColors.surfaceContainerLowest.withValues(alpha: 0.82),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                                          color: AppColors.primary,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            distanceLabel,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
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
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.toUpperCase(),
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
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double aspectRatio;
  const _Placeholder({required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: AppColors.surfaceContainerHigh,
        child: Center(
          child: Icon(
            PhosphorIcons.storefront(PhosphorIconsStyle.regular),
            color: AppColors.onSurfaceVariant,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Business join bottom sheet
// ─────────────────────────────────────────────────────────────────

class _BusinessSheet extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> data;
  final String customerId;
  final VoidCallback onJoined;

  const _BusinessSheet({
    required this.businessId,
    required this.data,
    required this.customerId,
    required this.onJoined,
  });

  @override
  State<_BusinessSheet> createState() => _BusinessSheetState();
}

class _BusinessSheetState extends State<_BusinessSheet> {
  bool _joining = false;

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final d = widget.data;
      final stampGoal = (d['stampGoal'] as num?)?.toInt() ?? 10;
      final loyaltyDocId = '${widget.customerId}_${widget.businessId}';
      debugPrint('[Discovery] joining loyalty docId=$loyaltyDocId');
      await FirebaseFirestore.instance
          .collection('loyalties')
          .doc(loyaltyDocId)
          .set({
        'customerId': widget.customerId,
        'businessId': widget.businessId,
        'businessName': d['name'] as String? ?? '',
        'businessCategory': d['category'] as String? ?? '',
        'businessImageUrl': d['imageUrl'] as String?,
        'stampCount': 0,
        'stampGoal': stampGoal,
        'rewardDescription': d['rewardDescription'] as String? ?? '',
        'rewardCount': 0,
        'redeemedCount': 0,
        'canRate': false,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[Discovery] loyalty created: $loyaltyDocId');
      widget.onJoined();
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _formatBusinessHours(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return 'Contact for hours';

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabels = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday'
    };

    List<String> groups = [];
    String? startDay;
    String? lastDay;
    String? currentHours;

    for (final day in dayNames) {
      final data = hours[day] as Map<String, dynamic>?;
      final timeStr = (data?['isOpen'] == true)
          ? '${data!['open']} - ${data['close']}'
          : 'Closed';

      if (timeStr == currentHours) {
        lastDay = day;
      } else {
        if (startDay != null) {
          groups.add(_formatGroup(startDay, lastDay, currentHours!, dayLabels));
        }
        startDay = day;
        lastDay = day;
        currentHours = timeStr;
      }
    }
    if (startDay != null) {
      groups.add(_formatGroup(startDay, lastDay, currentHours!, dayLabels));
    }

    return groups.join('\n');
  }

  String _formatGroup(String start, String? end, String hours, Map<String, String> labels) {
    if (start == end) return '${labels[start]}: $hours';
    return '${labels[start]} - ${labels[end!]}: $hours';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final d = widget.data;
    final name = d['name'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final imageUrl = d['imageUrl'] as String?;
    final stampGoal = (d['stampGoal'] as num?)?.toInt() ?? 10;
    final rewardDesc = d['rewardDescription'] as String? ?? '';
    final phoneNumber = d['phoneNumber'] as String? ?? '';
    final loyaltyDocId = '${widget.customerId}_${widget.businessId}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 32),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null
                        ? Center(
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.toUpperCase(),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Address & Hours Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (d['address'] != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  d['address'] as String,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, thickness: 0.5, color: AppColors.outlineVariant),
                          ),
                        ],
                        if (phoneNumber.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                PhosphorIcons.phone(PhosphorIconsStyle.fill),
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  phoneNumber,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, thickness: 0.5, color: AppColors.outlineVariant),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIcons.clock(PhosphorIconsStyle.fill),
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatBusinessHours(d['businessHours'] as Map<String, dynamic>?),
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reward info box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.gift(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Collect $stampGoal stamps to earn:',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSecondaryContainer,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                rewardDesc.isEmpty
                                    ? 'A special reward'
                                    : rewardDesc,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Live loyalty status
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('loyalties')
                        .doc(loyaltyDocId)
                        .snapshots(),
                    builder: (context, snap) {
                      final isJoined = snap.data?.exists ?? false;
                      final ld = isJoined
                          ? snap.data!.data() as Map<String, dynamic>
                          : null;
                      final stampCount =
                          (ld?['stampCount'] as num?)?.toInt() ?? 0;
                      final rewardCount =
                          (ld?['rewardCount'] as num?)?.toInt() ?? 0;
                      final goal =
                          (ld?['stampGoal'] as num?)?.toInt() ?? stampGoal;

                      return Column(
                        children: [
                          if (isJoined) ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Your stamps',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  '$stampCount / $goal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9999),
                              child: LinearProgressIndicator(
                                value:
                                    goal > 0 ? stampCount / goal : 0,
                                minHeight: 10,
                                backgroundColor:
                                    AppColors.surfaceContainerLow,
                                color: AppColors.primary,
                              ),
                            ),
                            if (rewardCount > 0) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    PhosphorIcons.gift(
                                        PhosphorIconsStyle.fill),
                                    color: const Color(0xFF7C3AED),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$rewardCount reward${rewardCount > 1 ? 's' : ''} earned',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],

                          // Action button
                          if (snap.connectionState ==
                                  ConnectionState.waiting &&
                              !isJoined)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          else if (!isJoined)
                            GestureDetector(
                              onTap: _joining ? null : _join,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryContainer,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(9999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.30),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _joining
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.onPrimary,
                                          ),
                                        )
                                      : Text(
                                          'Start collecting stamps',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.checkCircle(
                                        PhosphorIconsStyle.fill),
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Already collecting stamps',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
