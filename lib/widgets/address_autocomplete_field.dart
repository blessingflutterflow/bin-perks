import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';

class AddressAutocompleteField extends StatefulWidget {
  final String initialValue;
  final void Function(String address, double lat, double lng) onPlaceSelected;

  const AddressAutocompleteField({
    super.key,
    this.initialValue = '',
    required this.onPlaceSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const _apiKey = 'AIzaSyDZ1detfI_VW8UKuG6K0NnTrwqxeEkfN9c';

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_Prediction> _predictions = [];
  bool _fetching = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialValue;
    _ctrl.addListener(_onChanged);
    _focus.addListener(() {
      if (!_focus.hasFocus) setState(() => _predictions = []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _predictions = [];
        _fetching = false;
      });
      return;
    }
    setState(() => _fetching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _autocomplete(q));
  }

  Future<void> _autocomplete(String input) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {'input': input, 'key': _apiKey},
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['predictions'] as List<dynamic>?) ?? [];
      setState(() {
        _predictions = list
            .map((p) => _Prediction(
                  placeId: p['place_id'] as String,
                  description: p['description'] as String,
                ))
            .toList();
        _fetching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _select(_Prediction p) async {
    _debounce?.cancel();
    _focus.unfocus();
    setState(() {
      _ctrl.text = p.description;
      _predictions = [];
      _fetching = false;
      _resolving = true;
    });
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {'place_id': p.placeId, 'fields': 'geometry', 'key': _apiKey},
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final loc =
          data['result']['geometry']['location'] as Map<String, dynamic>;
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();
      widget.onPlaceSelected(p.description, lat, lng);
    } catch (_) {
      widget.onPlaceSelected(p.description, 0, 0);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _fetching || _resolving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: '123 Main Street, Cape Town',
            hintStyle: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSecondaryContainer.withValues(alpha: 0.5),
            ),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
        ),
        if (_predictions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: List.generate(_predictions.length, (i) {
                final pred = _predictions[i];
                final isLast = i == _predictions.length - 1;
                return GestureDetector(
                  onTap: () => _select(pred),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: isLast
                        ? null
                        : BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pred.description,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _Prediction {
  final String placeId;
  final String description;
  const _Prediction({required this.placeId, required this.description});
}
