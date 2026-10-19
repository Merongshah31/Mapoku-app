import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/sime_darby/data/sime_darby_demo_data.dart';
import '../features/sime_darby/models/sime_darby_hub.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../services/geocoding_service.dart';
import '../state/app_scope.dart';
import '../widgets/report_card.dart';
import '../widgets/ui_kit.dart';

/// Full-screen form for a new obstacle report. Pops with `true` once sent.
///
/// The location is picked from the Sime Darby Property sites and the
/// wayfinding point nearest the barrier, so no coordinates are typed.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key, this.initialHub});

  /// Preselects this site (e.g. the one being viewed on the route map).
  final SimeDarbyHub? initialHub;

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

/// Where the obstacle is: a named place and the point it sits at.
class _Place {
  const _Place({
    required this.label,
    required this.position,
    this.icon = CupertinoIcons.location_solid,
    this.site,
  });

  final String label;
  final LatLng position;
  final IconData icon;

  /// Sime Darby site the place belongs to, if it is one of ours.
  final String? site;

  String get fullName => site == null ? label : '$label · $site';
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _picker = ImagePicker();
  final _geocoder = GeocodingService();
  final _search = TextEditingController();
  final _summary = TextEditingController();
  final _details = TextEditingController();

  late SimeDarbyHub _hub = widget.initialHub ?? SimeDarbyDemoData.hubs.first;
  _Place? _place;
  ObstacleType? _type;
  String? _photoPath;

  Timer? _debounce;
  List<PlaceSuggestion> _remote = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _summary.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _summary.dispose();
    _details.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ location

  String get _query => _search.text.trim();

  _Place _siteSpot(SimeDarbyHub hub, HubNode node) => _Place(
    label: node.label,
    position: node.position,
    icon: node.iconData,
    site: hub.name,
  );

  /// Our own named points that match what was typed, across every site.
  List<_Place> get _localMatches {
    final q = _query.toLowerCase();
    return [
      for (final hub in SimeDarbyDemoData.hubs)
        for (final node in hub.nodes)
          if (node.label.toLowerCase().contains(q) ||
              hub.name.toLowerCase().contains(q))
            _siteSpot(hub, node),
    ];
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _remote = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await _geocoder.search(value, limit: 5);
      if (!mounted) return;
      setState(() {
        _remote = results;
        _searching = false;
      });
    });
  }

  void _choose(_Place place) {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    setState(() {
      _place = place;
      _search.clear();
      _remote = const [];
      _searching = false;
    });
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

  // ------------------------------------------------------------ review & send

  bool get _ready =>
      _place != null && _type != null && _summary.text.trim().length >= 5;

  String get _description {
    final summary = _summary.text.trim();
    final details = _details.text.trim();
    return details.isEmpty ? summary : '$summary\n$details';
  }

  String get _placeName => _place!.fullName;

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    final type = _type!;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        type: type,
        position: _place!.position,
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
    final label = _place == null
        ? 'Choose where it is'
        : _type == null
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
            if (_place != null)
              AppGroup(
                children: [
                  _SelectedPlace(
                    place: _place!,
                    onChange: () => setState(() => _place = null),
                  ),
                ],
              )
            else ...[
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SimeDarbyDemoData.hubs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final hub = SimeDarbyDemoData.hubs[index];
                    return _HubChoice(
                      label: hub.name,
                      selected: hub.id == _hub.id,
                      onTap: () => setState(() => _hub = hub),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AppGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _search,
                      onChanged: _onQueryChanged,
                      style: kBodyStyle,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Search for another place',
                        prefixIcon: const Icon(
                          CupertinoIcons.search,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(
                                  CupertinoIcons.xmark,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _search.clear();
                                  _onQueryChanged('');
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              _ListHeading(
                _query.isEmpty ? 'Suggested at ${_hub.name}' : 'Results',
              ),
              AppGroup(
                dividerIndent: 64,
                children: [
                  if (_query.isEmpty) ...[
                    for (final node in _hub.nodes)
                      _PlaceRow(
                        leading: Icon(
                          node.iconData,
                          size: 19,
                          color: AppColors.primary,
                        ),
                        title: node.label,
                        onTap: () => _choose(_siteSpot(_hub, node)),
                      ),
                  ] else ...[
                    for (final place in _localMatches)
                      _PlaceRow(
                        leading: Icon(
                          place.icon,
                          size: 19,
                          color: AppColors.primary,
                        ),
                        title: place.label,
                        subtitle: place.site,
                        onTap: () => _choose(place),
                      ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Searching places…', style: kFootnoteStyle),
                          ],
                        ),
                      ),
                    for (final suggestion in _remote)
                      _PlaceRow(
                        leading: const Icon(
                          CupertinoIcons.location,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        title: suggestion.label.split(',').first.trim(),
                        subtitle: suggestion.label,
                        onTap: () => _choose(
                          _Place(
                            label: suggestion.label.split(',').first.trim(),
                            position: suggestion.position,
                          ),
                        ),
                      ),
                    if (!_searching &&
                        _remote.isEmpty &&
                        _localMatches.isEmpty &&
                        _query.length >= 3)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No places found. Try a different name.',
                          style: kFootnoteStyle,
                        ),
                      ),
                  ],
                ],
              ),
              const SectionFooter(
                'Choosing a point on a Sime Darby walkway lets routes there avoid the obstacle.',
              ),
            ],
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

class _HubChoice extends StatelessWidget {
  const _HubChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small label above a list, outside the rounded card (iOS grouped style).
class _ListHeading extends StatelessWidget {
  const _ListHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: leading,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kBodyStyle),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kFootnoteStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The place that was picked, with a way to change it.
class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({required this.place, required this.onChange});

  final _Place place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(place.icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.label, style: kBodyStyle),
                if (place.site != null)
                  Text(place.site!, style: kFootnoteStyle),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
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
                Icon(
                  type.icon,
                  size: 22,
                  color: selected ? Colors.white : AppColors.accent,
                ),
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
                    CupertinoIcons.camera,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add a photo', style: kBodyStyle)),
                  Icon(
                    CupertinoIcons.chevron_right,
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
                  CupertinoIcons.trash,
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
              _Line('Location', widget.placeName),
              _Line('Photo', widget.photoPath == null ? 'None' : 'Added'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
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
