import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_pins.dart';
import '../../widgets/obstacle_ui.dart';
import 'report_card.dart';

enum _Fix { locating, gps, moved, unavailable }

/// Full-screen form for a new obstacle report.
/// Pops with a [ReportReceipt] once the report is sent.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _map = MapController();
  final _place = TextEditingController();
  final _summary = TextEditingController();
  final _details = TextEditingController();
  final _picker = ImagePicker();

  LatLng _pin = MockMapokuRepository.defaultPosition;
  _Fix _fix = _Fix.locating;
  bool _mapReady = false;
  DateTime _seenAt = DateTime.now();
  ObstacleKind? _kind;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _summary.addListener(() => setState(() {}));
    _locate();
  }

  @override
  void dispose() {
    _place.dispose();
    _summary.dispose();
    _details.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ location

  /// Gets a GPS fix and centres the map on it. Falls back to a default spot
  /// if location is off or not allowed; the user can still move the map.
  Future<void> _locate() async {
    setState(() => _fix = _Fix.locating);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('off');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      if (!mounted) return;
      setState(() {
        _pin = LatLng(pos.latitude, pos.longitude);
        _fix = _Fix.gps;
      });
      if (_mapReady) _map.move(_pin, 17);
    } catch (_) {
      if (mounted) setState(() => _fix = _Fix.unavailable);
    }
  }

  String get _fixText => switch (_fix) {
        _Fix.locating => 'Finding your location…',
        _Fix.gps => 'From your GPS. Move the map if the pin is off.',
        _Fix.moved => 'Set by moving the map.',
        _Fix.unavailable => "Location is off, so this is a default spot. Move the map to where the barrier is.",
      };

  // ------------------------------------------------------------ date & time

  void _pickSeenAt() {
    var picked = _seenAt;
    final now = DateTime.now();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: Palette.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
                  const Spacer(),
                  CupertinoButton(
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      setState(() => _seenAt = picked);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: _seenAt,
                  minimumDate: now.subtract(const Duration(days: 30)),
                  maximumDate: now.add(const Duration(minutes: 1)),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ photo

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file != null && mounted) setState(() => _photoPath = file.path);
    } on PlatformException {
      if (!mounted) return;
      _alert(source == ImageSource.camera
          ? 'mapOKU needs camera access. Turn it on in Settings › mapOKU › Camera.'
          : 'mapOKU needs photo access. Turn it on in Settings › mapOKU › Photos.');
    }
  }

  void _choosePhoto() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.camera);
            },
            child: const Text('Take photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.gallery);
            },
            child: const Text('Choose from library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _alert(String text) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(text),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  // ------------------------------------------------------------ review & send

  bool get _ready => _kind != null && _summary.text.trim().length >= 5;

  ReportDraft _draft() => ReportDraft(
        kind: _kind!,
        position: _pin,
        placeName: _place.text.trim().isEmpty ? 'Pinned location' : _place.text.trim(),
        seenAt: _seenAt,
        summary: _summary.text.trim(),
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
        photoPath: _photoPath,
      );

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    final receipt = await showModalBottomSheet<ReportReceipt>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(draft: _draft()),
    );
    if (receipt != null && mounted) Navigator.pop(context, receipt);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        middle: const Text('New report'),
        backgroundColor: Palette.page.withValues(alpha: 0.9),
        border: null,
        transitionBetweenRoutes: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 24),
          children: [
            // Where
            const SectionTitle('Where is it?'),
            Group(
              children: [
                SizedBox(height: 210, child: _pinMap()),
                _CoordinatesRow(pin: _pin, fix: _fix, onLocate: _locate),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _place,
                    style: TextStyles.body,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Place name',
                      labelStyle: TextStyles.footnote,
                      floatingLabelStyle: TextStyles.footnote,
                      hintText: 'e.g. KL Sentral, Entrance C',
                      hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
                    ),
                  ),
                ),
              ],
            ),
            SectionFooter(_fixText),

            // When
            const SectionTitle('When did you see it?'),
            Group(
              children: [
                Pressable(
                  semanticLabel: 'Seen ${longDate(_seenAt)} at ${clockTime(_seenAt)}. Change',
                  onTap: _pickSeenAt,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.clock, size: 20, color: Palette.moss),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(longDate(_seenAt), style: TextStyles.body),
                              Text(clockTime(_seenAt), style: TextStyles.footnote),
                            ],
                          ),
                        ),
                        Text('Change', style: TextStyles.body.copyWith(color: Palette.moss)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SectionFooter('Set to now. Change it if you saw it earlier.'),

            // What
            const SectionTitle("What's in the way?"),
            _KindGrid(selected: _kind, onSelect: (k) => setState(() => _kind = k)),

            // Summary
            const SectionTitle('Summary'),
            Group(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _summary,
                    maxLength: 80,
                    style: TextStyles.body,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g. Lift to platform 2 out of service',
                      hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
                      counterStyle: TextStyles.caption,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _details,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 280,
                    style: TextStyles.body,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'More details (optional), e.g. use the lift at Entrance C instead',
                      hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
                      counterStyle: TextStyles.caption,
                    ),
                  ),
                ),
              ],
            ),
            const SectionFooter('The summary is the headline others see in Community.'),

            // Photo
            const SectionTitle('Photo'),
            _PhotoRow(path: _photoPath, onAdd: _choosePhoto, onRemove: () => setState(() => _photoPath = null)),
            const SectionFooter('Reports with a clear photo get confirmed faster.'),

            const SizedBox(height: 24),
            PrimaryButton(
              label: _kind == null
                  ? "Choose what's in the way"
                  : (_summary.text.trim().length < 5 ? 'Add a summary' : 'Review report'),
              onPressed: _ready ? _review : null,
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
            backgroundColor: Palette.field,
            onMapReady: () {
              _mapReady = true;
              if (_fix == _Fix.gps) _map.move(_pin, 17);
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mapoku',
            ),
          ],
        ),
        // Pin tip sits exactly on the map centre.
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: LetterPin(letter: '!', color: Palette.amber, size: 34),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 4,
          child: Text('© OpenStreetMap contributors', style: TextStyles.caption.copyWith(fontSize: 10)),
        ),
      ],
    );
  }
}

class _CoordinatesRow extends StatelessWidget {
  const _CoordinatesRow({required this.pin, required this.fix, required this.onLocate});

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
                  Expanded(child: _Coord(label: 'Latitude', value: lat)),
                  Expanded(child: _Coord(label: 'Longitude', value: lng)),
                ],
              ),
            ),
          ),
          Pressable(
            semanticLabel: 'Use my current location',
            onTap: fix == _Fix.locating ? null : onLocate,
            child: SizedBox(
              width: 44,
              height: 44,
              child: fix == _Fix.locating
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      fix == _Fix.unavailable ? CupertinoIcons.location_slash : CupertinoIcons.location_fill,
                      size: 20,
                      color: Palette.moss,
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
          Text(label, style: TextStyles.footnote),
          Text(value, style: TextStyles.callout.copyWith(fontFeatures: TextStyles.tabular)),
        ],
      );
}

/// Compact two-column grid of all obstacle categories.
class _KindGrid extends StatelessWidget {
  const _KindGrid({required this.selected, required this.onSelect});

  final ObstacleKind? selected;
  final ValueChanged<ObstacleKind> onSelect;

  @override
  Widget build(BuildContext context) {
    const kinds = ObstacleKind.values;
    final rows = <Widget>[];
    for (var i = 0; i < kinds.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _KindTile(kind: kinds[i], selected: selected == kinds[i], onTap: onSelect)),
            const SizedBox(width: 8),
            Expanded(
              child: i + 1 < kinds.length
                  ? _KindTile(kind: kinds[i + 1], selected: selected == kinds[i + 1], onTap: onSelect)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind, required this.selected, required this.onTap});

  final ObstacleKind kind;
  final bool selected;
  final ValueChanged<ObstacleKind> onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Palette.ink;
    return Pressable(
      selected: selected,
      semanticLabel: kind.label,
      onTap: () => onTap(kind),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Palette.moss : Palette.surface,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            Icon(obstacleIcon(kind), size: 22, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(kind.label, style: TextStyles.subhead.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.path, required this.onAdd, required this.onRemove});

  final String? path;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) {
      return Group(
        children: [
          Pressable(
            onTap: onAdd,
            semanticLabel: 'Add a photo',
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(CupertinoIcons.camera_fill, size: 22, color: Palette.moss),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add a photo', style: TextStyles.body)),
                  Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Group(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(p), width: 64, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Photo added', style: TextStyles.body)),
              Pressable(
                onTap: onAdd,
                semanticLabel: 'Replace photo',
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Replace', style: TextStyles.body.copyWith(color: Palette.moss)),
                ),
              ),
              Pressable(
                onTap: onRemove,
                semanticLabel: 'Remove photo',
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(CupertinoIcons.trash, size: 20, color: Palette.secondary),
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
  const _ReviewSheet({required this.draft});

  final ReportDraft draft;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final receipt = await context.read<AppState>().submitReport(widget.draft);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, receipt);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = "Your report wasn't sent. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final preview = CommunityReport(
      id: 'preview',
      kind: d.kind,
      summary: d.summary,
      details: d.details,
      placeName: d.placeName,
      position: d.position,
      seenAt: d.seenAt,
      localPhotoPath: d.photoPath,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Check your report', style: TextStyles.title2),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('This is how it will look in Community.', style: TextStyles.subhead),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.group),
              border: Border.all(color: Palette.hairline),
            ),
            child: ReportCard(report: preview),
          ),
          const SizedBox(height: 16),
          Group(
            color: Palette.field,
            children: [
              _Line('Category', d.kind.label),
              _Line('Seen', '${longDate(d.seenAt)}, ${clockTime(d.seenAt)}'),
              _Line(
                'Coordinates',
                '${d.position.latitude.toStringAsFixed(6)}, ${d.position.longitude.toStringAsFixed(6)}',
              ),
              _Line('Photo', d.photoPath == null ? 'None' : 'Added'),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyles.footnote.copyWith(color: Palette.amberText)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Send report',
            icon: CupertinoIcons.paperplane_fill,
            loading: _sending,
            onPressed: _send,
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Edit',
            tone: ButtonTone.plain,
            onPressed: _sending ? null : () => Navigator.pop(context),
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
            SizedBox(width: 108, child: Text(label, style: TextStyles.callout.copyWith(color: Palette.secondary))),
            Expanded(
              child: Text(value, style: TextStyles.callout.copyWith(fontFeatures: TextStyles.tabular)),
            ),
          ],
        ),
      );
}
