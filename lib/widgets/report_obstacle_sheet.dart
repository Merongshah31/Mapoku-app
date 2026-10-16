import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../services/geocoding_service.dart';
import '../state/app_scope.dart';

/// Form for reporting a new accessibility obstacle.
///
/// Wrapped in a bottom sheet by the Reports screen. On success it awards
/// points through [AppState.submitReport] and shows a confirmation.
class ReportObstacleSheet extends StatefulWidget {
  const ReportObstacleSheet({super.key});

  @override
  State<ReportObstacleSheet> createState() => _ReportObstacleSheetState();
}

class _ReportObstacleSheetState extends State<ReportObstacleSheet> {
  final _geocoder = GeocodingService();
  final _description = TextEditingController();
  final _location = TextEditingController(text: 'Mid Valley, Kuala Lumpur');

  ObstacleType _type = ObstacleType.noRamp;
  List<PlaceSuggestion> _suggestions = const [];
  LatLng _position = const LatLng(3.118, 101.696);
  String? _imagePath;
  Timer? _debounce;
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _geocoder.search(value, limit: 5);
      if (!mounted) return;
      setState(() => _suggestions = results);
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _location.text = suggestion.label;
      _position = suggestion.position;
      _suggestions = const [];
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final state = AppScope.of(context);
    final location = _location.text.trim();

    // Best-effort geocode for free-text locations.
    try {
      final point = await _geocoder.geocode(location);
      _position = point;
    } catch (_) {
      // Fall back to the last known position.
    }

    state.submitReport(
      type: _type,
      position: _position,
      location: location.isEmpty ? 'Mid Valley, Kuala Lumpur' : location,
      description: _description.text.trim(),
      imagePath: _imagePath,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Report submitted · +${AppConfig.pointsPerReport} points earned 🪙'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report an obstacle', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Help others move through the city.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            const _SectionLabel('WHAT DID YOU FIND?'),
            const SizedBox(height: 10),
            _TypeSelector(selected: _type, onSelected: (value) => setState(() => _type = value)),
            const SizedBox(height: 20),
            const _SectionLabel('LOCATION'),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              onChanged: _onLocationChanged,
              decoration: const InputDecoration(
                hintText: 'Search a place',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              _SuggestionList(suggestions: _suggestions, onSelected: _selectSuggestion),
            ],
            const SizedBox(height: 20),
            const _SectionLabel('DETAILS'),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add a short description of the obstacle…'),
            ),
            const SizedBox(height: 14),
            _PhotoPicker(
              imagePath: _imagePath,
              onPick: _pickImage,
              onClear: () => setState(() => _imagePath = null),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_outlined, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                        children: [
                          const TextSpan(text: 'Earn '),
                          TextSpan(
                            text: '+${AppConfig.pointsPerReport} pts',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: ' now, '),
                          TextSpan(
                            text: '+${AppConfig.pointsPerConfirmation}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: ' when confirmed.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: Text(_submitting ? 'Submitting…' : 'Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onSelected});

  final ObstacleType selected;
  final ValueChanged<ObstacleType> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 50) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ObstacleType.values.map((type) {
        final isSelected = type == selected;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelected(type),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.mint : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.sage : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onSelected});

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final suggestion in suggestions)
            InkWell(
              onTap: () => onSelected(suggestion),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        suggestion.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.imagePath, required this.onPick, required this.onClear});

  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(imagePath!),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(height: 150),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClear,
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 18)),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Add a photo (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}