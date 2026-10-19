import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../models/report.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/report_card.dart';
import '../widgets/ui_kit.dart';

/// Full view of one report: photo, where, when, details and votes.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.mine,
  });

  final Report report;
  final bool mine;

  static Future<void> open(
    BuildContext context,
    Report report, {
    required bool mine,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report, mine: mine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final r = _live(state);
    final details = r.details;
    final position = r.position;
    final photo = r.imagePath;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: Text(r.type)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 32),
        children: [
          if (photo != null) ...[
            _Photo(path: photo),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.summary,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (mine) ...[const SizedBox(width: 8), StatusTag(r.status)],
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 10),
            Text(
              details,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (photo == null) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.photo_outlined,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: 6),
                Text('No photo with this report', style: kFootnoteStyle),
              ],
            ),
          ],
          if (mine && r.status == ReportStatus.flagged) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.flagReason ?? 'Needs review',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SectionTitle('Where'),
          AppGroup(
            children: [
              if (position != null)
                SizedBox(
                  height: 170,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: 16.5,
                        backgroundColor: AppColors.field,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: AppConfig.osmTileUrl,
                          userAgentPackageName: 'com.example.mapoku',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: position,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const _MapPin(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              _InfoRow(icon: Icons.place, title: r.place),
              if (position != null)
                _InfoRow(
                  icon: Icons.map_outlined,
                  title:
                      '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                  subtitle: 'Latitude, longitude',
                ),
            ],
          ),
          const SectionTitle('When'),
          AppGroup(
            children: [
              _InfoRow(
                icon: Icons.schedule,
                title: DateFormat('EEE d MMM, h:mm a').format(r.createdAt),
                subtitle: 'Seen ${reportTimeAgo(r.createdAt)}',
              ),
            ],
          ),
          const SectionTitle('Category'),
          AppGroup(
            children: [_InfoRow(emoji: r.icon, title: r.type)],
          ),
          if (!mine) ...[
            const SectionTitle('Is it still there?'),
            Row(
              children: [
                Expanded(
                  child: _VoteBig(
                    label: 'Still there',
                    count: r.confirmations,
                    onTap: () => state.confirmObstacle(r.id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoteBig(
                    label: "It's gone",
                    count: r.clearances,
                    onTap: () => state.clearObstacle(r.id),
                  ),
                ),
              ],
            ),
            const SectionFooter(
              'You get 2 points for checking. It keeps routes accurate for everyone.',
            ),
          ] else if (r.status != ReportStatus.flagged) ...[
            const SectionTitle('Confirmations'),
            AppGroup(
              children: [
                _InfoRow(
                  icon: Icons.thumb_up_alt_outlined,
                  title:
                      '${r.confirmations} ${r.confirmations == 1 ? 'person says' : 'people say'} it is still there',
                  subtitle: r.status == ReportStatus.verified
                      ? 'Confirmed. You got +${AppConfig.pointsPerConfirmation} points.'
                      : 'You get +${AppConfig.pointsPerConfirmation} points once others confirm it.',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Reads the live copy so vote counts update while this page is open.
  Report _live(AppState state) {
    if (mine) {
      for (final candidate in state.myReports) {
        if (candidate.id == report.id) return candidate;
      }
      return report;
    }
    for (final obstacle in state.communityObstacles) {
      if (obstacle.id == report.id) {
        return Report(
          id: obstacle.id,
          type: report.type,
          icon: report.icon,
          location: report.location,
          description: report.description,
          position: report.position,
          createdAt: report.createdAt,
          confirmations: obstacle.confirms,
          clearances: obstacle.clearances,
        );
      }
    }
    return report;
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.location_on, size: 40, color: AppColors.accent);
}

/// Report photo. Tap to see it full screen and pinch to zoom.
class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final image = FileImage(File(path));
    return Semantics(
      button: true,
      label: 'Photo of the obstacle. Open full screen',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _PhotoViewer(image: image),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.field,
                alignment: Alignment.center,
                child: const Text("Photo couldn't load", style: kFootnoteStyle),
              ),
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
              child: Center(
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close photo',
                onPressed: () => Navigator.pop(context),
                iconSize: 32,
                color: Colors.white70,
                icon: const Icon(Icons.cancel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({this.icon, this.emoji, required this.title, this.subtitle});

  final IconData? icon;
  final String? emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        SizedBox(
          width: 24,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 18))
              : Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kBodyStyle),
              if (subtitle != null) Text(subtitle!, style: kFootnoteStyle),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoteBig extends StatelessWidget {
  const _VoteBig({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count ${count == 1 ? 'vote' : 'votes'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
