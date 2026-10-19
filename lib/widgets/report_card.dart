import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../models/report.dart';
import 'ui_kit.dart';

/// Reports are stored with a single description. The first line is the
/// headline others see; anything after it is the optional detail text.
extension ReportText on Report {
  String get summary {
    final first = description.split('\n').first.trim();
    return first.isEmpty ? type : first;
  }

  String? get details {
    final index = description.indexOf('\n');
    if (index < 0) return null;
    final rest = description.substring(index + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  String get place => location.isEmpty ? 'Kuala Lumpur' : location;
}

String reportTimeAgo(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM').format(at);
}

/// Short status label + colours for the "My reports" tag.
({String label, Color fg, Color bg}) reportStatusTag(ReportStatus status) =>
    switch (status) {
      ReportStatus.verified => (
        label: 'Confirmed',
        fg: AppColors.success,
        bg: AppColors.successSoft,
      ),
      ReportStatus.pending => (
        label: 'Pending',
        fg: AppColors.textSecondary,
        bg: AppColors.field,
      ),
      ReportStatus.flagged => (
        label: 'Flagged',
        fg: AppColors.danger,
        bg: AppColors.dangerSoft,
      ),
    };

/// One report in the Community feed or My reports.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    this.mine = false,
    this.onVote,
    this.onTap,
  });

  final Report report;
  final bool mine;

  /// `true` = still there, `false` = it's gone. null hides the vote buttons.
  final void Function(bool stillThere)? onVote;

  /// Opens the full report. null in previews.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final details = r.details;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(r.icon, size: 20, color: AppColors.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.summary,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${r.type}, ${reportTimeAgo(r.createdAt)}',
                      style: kFootnoteStyle,
                    ),
                  ],
                ),
              ),
              if (mine) ...[const SizedBox(width: 8), StatusTag(r.status)],
              if (!mine && onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 10),
            Text(
              details,
              maxLines: onTap == null ? null : 3,
              overflow: onTap == null ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (r.imagePath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 150,
                child: Image.file(
                  File(r.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          if (mine && r.status == ReportStatus.flagged) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.flag_fill, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.flagReason ?? 'Needs review',
                      style: kFootnoteStyle.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (mine && r.status != ReportStatus.flagged) ...[
            const SizedBox(height: 10),
            Text(
              r.status == ReportStatus.verified
                  ? 'Confirmed by the community. You got +${AppConfig.pointsPerConfirmation} points.'
                  : 'Waiting for other members to confirm it.',
              style: kFootnoteStyle,
            ),
          ],
        ],
      ),
    );

    return AppGroup(
      dividerIndent: 0,
      children: [
        if (onTap == null)
          body
        else
          Semantics(
            button: true,
            label: '${r.summary}, ${r.place}. Open details',
            excludeSemantics: true,
            child: InkWell(onTap: onTap, child: body),
          ),
        if (onVote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: 'Still there',
                    count: r.confirmations,
                    icon: CupertinoIcons.hand_thumbsup,
                    onTap: () => onVote!(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoteButton(
                    label: "It's gone",
                    count: r.clearances,
                    icon: CupertinoIcons.checkmark_alt,
                    onTap: () => onVote!(false),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final tag = reportStatusTag(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tag.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tag.fg,
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count ${count == 1 ? 'vote' : 'votes'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
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
