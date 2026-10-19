import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../state/app_scope.dart';
import '../widgets/report_card.dart';
import '../widgets/ui_kit.dart';

enum _Fix { locating, gps, moved, searched, preset, unavailable }

/// Full-screen form for a new obstacle report. Pops with `true` once sent.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key, this.initialPosition});

  /// Start the pin here (e.g. the area being viewed) instead of using GPS.
  final LatLng? initialPosition;

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  static const LatLng _defaultPin = LatLng(3.118, 101.696);

  final _map = MapController();
  final _geocoder = GeocodingService();
  final _picker = ImagePicker();
  final _place = TextEditingController();
  final _summary = TextEditingController();
  final _details = TextEditingController();

  LatLng _pin = _defaultPin;
  _Fix _fix = _Fix.locating;
  bool _mapReady = false;
  ObstacleType? _type;
  String? _photoPath;
  List<PlaceSuggestion> _suggestions = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _summary.addListener(() => setState(() {}));
    final start = widget.initialPosition;
    if (start != null) {
      _pin = start;
      _fix = _Fix.preset;
    } else {
      _locate();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _place.dispose();
    _summary.dispose();
    _details.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ location

  Future<void> _locate() async {
    setState(() => _fix = _Fix.locating);
    final here = await const LocationService().currentLatLng();
    if (!mounted) return;
    if (here == null) {
      setState(() => _fix = _Fix.unavailable);
      return;
    }
    setState(() {
      _pin = here;
      _fix = _Fix.gps;
    });
    if (_mapReady) _map.move(here, 17);
  }

  String get _fixText => switch (_fix) {
    _Fix.locating => 'Finding your location…',
    _Fix.gps => 'From your GPS. Move the map if the pin is off.',
    _Fix.moved => 'Set by moving the map.',
    _Fix.searched => 'Set from the place you searched.',
    _Fix.preset =>
      'Starts at the area you were looking at. Move the map to the barrier.',
    _Fix.unavailable =>
      'Location is off, so this is a default spot. Move the map to where the barrier is.',
  };

  void _onPlaceChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _geocoder.search(value, limit: 5);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    setState(() {
      _place.text = suggestion.label.split(',').first.trim();
      _pin = suggestion.position;
      _fix = _Fix.searched;
      _suggestions = const [];
    });
    if (_mapReady) _map.move(suggestion.position, 17);
  }

  // ------------------------------------------------------------ photo

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null && mounted) setState(() => _photoPath = file.path);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'mapOKU needs camera access. Turn it on in Settings.'
                  : 'mapOKU needs photo access. Turn it on in Settings.',
            ),
          ),
        );
    }
  }

  void _choosePhoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ review & send

  bool get _ready => _type != null && _summary.text.trim().length >= 5;

  String get _description {
    final summary = _summary.text.trim();
    final details = _details.text.trim();
    return details.isEmpty ? summary : '$summary\n$details';
  }

  String get _placeName =>
      _place.text.trim().isEmpty ? 'Pinned location' : _place.text.trim();

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    final type = _type!;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        type: type,
        position: _pin,
        placeName: _placeName,
        description: _description,
        photoPath: _photoPath,
      ),
    );
    if (sent == true && mounted) Navigator.pop(context, true);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final label = _type == null
        ? "Choose what's in the way"
        : (_summary.text.trim().length < 5 ? 'Add a summary' : 'Review report');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        title: const Text('New report'),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
          children: [
            const SectionTitle('Where is it?'),
            AppGroup(
              children: [
                SizedBox(height: 210, child: _pinMap()),
                _CoordinatesRow(pin: _pin, fix: _fix, onLocate: _locate),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _place,
                    onChanged: _onPlaceChanged,
                    style: kBodyStyle,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      labelText: 'Place name',
                      hintText: 'Search a place, e.g. KL Sentral',
                    ),
                  ),
                ),
                for (final suggestion in _suggestions)
                  InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              suggestion.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SectionFooter(_fixText),
            const SectionTitle("What's in the way?"),
            _TypeGrid(
              selected: _type,
              onSelect: (type) => setState(() => _type = type),
            ),
            const SectionTitle('Summary'),
            AppGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _summary,
                    maxLength: 80,
                    style: kBodyStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'e.g. Lift to platform 2 out of service',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _details,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 280,
                    style: kBodyStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText:
                          'More details (optional), e.g. use the lift at Entrance C instead',
                    ),
                  ),
                ),
              ],
            ),
            const SectionFooter(
              'The summary is the headline others see in Community.',
            ),
            const SectionTitle('Photo'),
            _PhotoRow(
              path: _photoPath,
              onAdd: _choosePhoto,
              onRemove: () => setState(() => _photoPath = null),
            ),
            const SectionFooter(
              'Reports with a clear photo get confirmed faster.',
            ),
            const SizedBox(height: 16),
            _EarnNote(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _ready ? _review : null,
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  /// Map with a fixed pin in the centre. Moving the map moves the report.
  Widget _pinMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pin,
            initialZoom: 17,
            backgroundColor: AppColors.field,
            onMapReady: () {
              _mapReady = true;
              if (_fix == _Fix.gps ||
                  _fix == _Fix.searched ||
                  _fix == _Fix.preset) {
                _map.move(_pin, 17);
              }
            },
            onPositionChanged: (camera, hasGesture) {
              if (!hasGesture) return;
              setState(() {
                _pin = camera.center;
                _fix = _Fix.moved;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: 'com.example.mapoku',
            ),
          ],
        ),
        // The pin tip sits exactly on the map centre.
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 40, color: AppColors.accent),
            ),
          ),
        ),
        const Positioned(
          right: 6,
          bottom: 4,
          child: Text(
            AppConfig.osmAttribution,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _EarnNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: const Row(
        children: [
          Icon(Icons.monetization_on_outlined, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Earn +${AppConfig.pointsPerReport} points now and '
              '+${AppConfig.pointsPerConfirmation} when others confirm it.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinatesRow extends StatelessWidget {
  const _CoordinatesRow({
    required this.pin,
    required this.fix,
    required this.onLocate,
  });

  final LatLng pin;
  final _Fix fix;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final lat = pin.latitude.toStringAsFixed(6);
    final lng = pin.longitude.toStringAsFixed(6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Latitude $lat, longitude $lng',
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(
                    child: _Coord(label: 'Latitude', value: lat),
                  ),
                  Expanded(
                    child: _Coord(label: 'Longitude', value: lng),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: fix == _Fix.locating
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Use my current location',
                    onPressed: onLocate,
                    icon: Icon(
                      fix == _Fix.unavailable
                          ? Icons.location_disabled
                          : Icons.my_location,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Coord extends StatelessWidget {
  const _Coord({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: kFootnoteStyle),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14.5,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

/// Two-column grid of all obstacle categories.
class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onSelect});

  final ObstacleType? selected;
  final ValueChanged<ObstacleType> onSelect;

  @override
  Widget build(BuildContext context) {
    const types = ObstacleType.values;
    final rows = <Widget>[];
    for (var i = 0; i < types.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TypeTile(
                  type: types[i],
                  selected: selected == types[i],
                  onTap: onSelect,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < types.length
                    ? _TypeTile(
                        type: types[i + 1],
                        selected: selected == types[i + 1],
                        onTap: onSelect,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ObstacleType type;
  final bool selected;
  final ValueChanged<ObstacleType> onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () => onTap(type),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
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

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.path,
    required this.onAdd,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = path;
    if (photo == null) {
      return AppGroup(
        children: [
          InkWell(
            onTap: onAdd,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add a photo', style: kBodyStyle)),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AppGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(photo),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 64, height: 64),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Photo added', style: kBodyStyle)),
              TextButton(onPressed: onAdd, child: const Text('Replace')),
              IconButton(
                tooltip: 'Remove photo',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Final check before sending: shows the report as others will see it.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.type,
    required this.position,
    required this.placeName,
    required this.description,
    required this.photoPath,
  });

  final ObstacleType type;
  final LatLng position;
  final String placeName;
  final String description;
  final String? photoPath;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _sending = false;

  void _send() {
    setState(() => _sending = true);
    AppScope.of(context).submitReport(
      type: widget.type,
      position: widget.position,
      location: widget.placeName,
      description: widget.description,
      imagePath: widget.photoPath,
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = Report(
      id: 'preview',
      type: widget.type.label,
      icon: widget.type.icon,
      location: widget.placeName,
      description: widget.description,
      imagePath: widget.photoPath,
      createdAt: DateTime.now(),
      position: widget.position,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Check your report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'This is how it will look in Community.',
              style: kFootnoteStyle,
            ),
          ),
          const SizedBox(height: 16),
          ReportCard(report: preview),
          const SizedBox(height: 16),
          AppGroup(
            color: AppColors.field,
            bordered: false,
            children: [
              _Line('Category', widget.type.label),
              _Line(
                'Coordinates',
                '${widget.position.latitude.toStringAsFixed(6)}, '
                    '${widget.position.longitude.toStringAsFixed(6)}',
              ),
              _Line('Photo', widget.photoPath == null ? 'None' : 'Added'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send report'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context, false),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}
