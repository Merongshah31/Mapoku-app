import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_pins.dart';
import '../../widgets/obstacle_ui.dart';

/// Full view of one report: photo, where, when, details and votes.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report, required this.mine});

  final CommunityReport report;
  final bool mine;

  static Future<void> open(BuildContext context, CommunityReport report, {required bool mine}) {
    return Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(builder: (_) => ReportDetailScreen(report: report, mine: mine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read the live copy so vote counts update while this page is open.
    final c = context.watch<ReportsController>();
    final list = mine ? c.mine : c.community;
    final r = list.firstWhere((x) => x.id == report.id, orElse: () => report);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasPhoto = r.localPhotoPath != null || r.photoUrl != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(r.kind.label),
            previousPageTitle: 'Report',
            backgroundColor: Palette.page.withValues(alpha: 0.9),
            border: null,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 32),
            sliver: SliverList.list(
              children: [
                if (hasPhoto) ...[
                  _Photo(report: r),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(r.summary, style: TextStyles.title2)),
                    if (mine) ...[const SizedBox(width: 8), _status(r.status)],
                  ],
                ),
                if (r.details != null && r.details!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(r.details!, style: TextStyles.body.copyWith(color: Palette.secondary)),
                ],
                if (!hasPhoto) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.photo, size: 16, color: Palette.tertiary),
                      const SizedBox(width: 6),
                      Text('No photo with this report', style: TextStyles.footnote),
                    ],
                  ),
                ],
                if (mine && r.status == ReportStatus.flagged && r.flagReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Palette.dangerSoft, borderRadius: BorderRadius.circular(Radii.control)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.flag_fill, size: 16, color: Palette.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r.flagReason!, style: TextStyles.callout.copyWith(color: Palette.danger))),
                      ],
                    ),
                  ),
                ],

                const SectionTitle('Where'),
                Group(
                  children: [
                    SizedBox(
                      height: 170,
                      child: IgnorePointer(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: r.position,
                            initialZoom: 16.5,
                            backgroundColor: Palette.field,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mapoku',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: r.position,
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const LetterPin(letter: '!', color: Palette.amber),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    _Row(icon: CupertinoIcons.location_fill, title: r.placeName),
                    _Row(
                      icon: CupertinoIcons.map,
                      title: '${r.position.latitude.toStringAsFixed(6)}, ${r.position.longitude.toStringAsFixed(6)}',
                      subtitle: 'Latitude, longitude',
                      tabular: true,
                    ),
                  ],
                ),

                const SectionTitle('When'),
                Group(
                  children: [
                    _Row(
                      icon: CupertinoIcons.clock,
                      title: '${longDate(r.seenAt)}, ${clockTime(r.seenAt)}',
                      subtitle: 'Seen ${timeAgo(r.seenAt)}',
                    ),
                  ],
                ),

                const SectionTitle('Category'),
                Group(children: [_Row(iconData: obstacleIcon(r.kind), title: r.kind.label)]),

                if (!mine) ...[
                  const SectionTitle('Is it still there?'),
                  Row(
                    children: [
                      Expanded(
                        child: _VoteBig(
                          label: 'Still there',
                          count: r.stillThere,
                          selected: r.myVote == true,
                          onTap: () => c.vote(r, stillThere: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VoteBig(
                          label: "It's gone",
                          count: r.gone,
                          selected: r.myVote == false,
                          onTap: () => c.vote(r, stillThere: false),
                        ),
                      ),
                    ],
                  ),
                  SectionFooter(
                    r.myVote == null
                        ? 'You get 5 points for checking. It keeps routes accurate for everyone.'
                        : 'Thanks. You can change your answer if things change.',
                  ),
                ] else if (r.status != ReportStatus.flagged) ...[
                  const SectionTitle('Confirmations'),
                  Group(
                    children: [
                      _Row(
                        icon: CupertinoIcons.hand_thumbsup,
                        title: '${r.stillThere} ${r.stillThere == 1 ? 'person says' : 'people say'} it is still there',
                        subtitle: r.status == ReportStatus.verified
                            ? 'Confirmed. You got 40 points.'
                            : 'You get 40 points once others confirm it.',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(ReportStatus s) => switch (s) {
        ReportStatus.verified => const Tag('Confirmed'),
        ReportStatus.pending => const Tag('Pending', color: Palette.secondary, background: Palette.field),
        ReportStatus.flagged => const Tag('Flagged', color: Palette.danger, background: Palette.dangerSoft),
      };
}

/// Report photo. Tap to see it full screen and pinch to zoom.
class _Photo extends StatelessWidget {
  const _Photo({required this.report});

  final CommunityReport report;

  ImageProvider get _image => report.localPhotoPath != null
      ? FileImage(File(report.localPhotoPath!))
      : NetworkImage(report.photoUrl!);

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Photo of the obstacle. Open full screen',
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _PhotoViewer(image: _image),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.group),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image(
            image: _image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Palette.field,
              alignment: Alignment.center,
              child: const Text("Photo couldn't load", style: TextStyles.footnote),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: Image(image: image, fit: BoxFit.contain)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Pressable(
                semanticLabel: 'Close photo',
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(CupertinoIcons.xmark_circle_fill, size: 34, color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({this.icon, this.iconData, required this.title, this.subtitle, this.tabular = false});

  final IconData? icon;
  final IconData? iconData;
  final String title;
  final String? subtitle;
  final bool tabular;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon ?? iconData, size: 20, color: Palette.moss),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyles.body.copyWith(fontFeatures: tabular ? TextStyles.tabular : null),
                  ),
                  if (subtitle != null) Text(subtitle!, style: TextStyles.footnote),
                ],
              ),
            ),
          ],
        ),
      );
}

class _VoteBig extends StatelessWidget {
  const _VoteBig({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Palette.ink;
    return Pressable(
      selected: selected,
      semanticLabel: '$label, $count ${count == 1 ? 'vote' : 'votes'}',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.moss : Palette.surface,
          borderRadius: BorderRadius.circular(Radii.group),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyles.title2.copyWith(color: fg, fontFeatures: TextStyles.tabular)),
            Text(label, style: TextStyles.subhead.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
