import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/obstacle_ui.dart';

/// One report in the Community feed or My reports.
/// Ported from ReportCard.jsx in Merongshah31/Mapoku.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, this.mine = false, this.onVote, this.onTap});

  final CommunityReport report;
  final bool mine;

  /// null hides the vote buttons (My reports, or a preview).
  final void Function(bool stillThere)? onVote;

  /// Opens the full report. null in previews.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = report;
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
                    decoration: const BoxDecoration(color: Palette.amberSoft, shape: BoxShape.circle),
                    child: Icon(obstacleIcon(r.kind), size: 21, color: Palette.amberText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.summary, style: TextStyles.headline),
                        const SizedBox(height: 2),
                        Text(r.placeName, style: TextStyles.subhead),
                        Text('${r.kind.label}, seen ${timeAgo(r.seenAt)}', style: TextStyles.footnote),
                      ],
                    ),
                  ),
                  if (mine) ...[const SizedBox(width: 8), _StatusTag(r.status)],
                  if (!mine && onTap != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
                    ),
                ],
              ),
              if (r.details != null && r.details!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  r.details!,
                  maxLines: onTap == null ? null : 3,
                  overflow: onTap == null ? null : TextOverflow.ellipsis,
                  style: TextStyles.callout.copyWith(color: Palette.secondary),
                ),
              ],
              if (r.localPhotoPath != null || r.photoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 150,
                    child: r.localPhotoPath != null
                        ? Image.file(File(r.localPhotoPath!), fit: BoxFit.cover)
                        : Image.network(r.photoUrl!, fit: BoxFit.cover),
                  ),
                ),
              ],
              if (mine && r.status == ReportStatus.flagged && r.flagReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Palette.dangerSoft, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.flag_fill, size: 15, color: Palette.danger),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.flagReason!, style: TextStyles.footnote.copyWith(color: Palette.danger))),
                    ],
                  ),
                ),
              ],
              if (mine && r.status != ReportStatus.flagged) ...[
                const SizedBox(height: 10),
                Text(
                  r.status == ReportStatus.verified
                      ? 'Confirmed by ${r.stillThere} ${r.stillThere == 1 ? 'person' : 'people'}. You got 40 points.'
                      : 'Waiting for other users to confirm it.',
                  style: TextStyles.footnote,
                ),
              ],
            ],
          ),
        );

    return Group(
      dividerIndent: 0,
      children: [
        if (onTap == null)
          body
        else
          Pressable(onTap: onTap, semanticLabel: '${r.summary}, ${r.placeName}. Open details', child: body),
        if (onVote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: 'Still there',
                    count: r.stillThere,
                    icon: CupertinoIcons.hand_thumbsup,
                    selected: r.myVote == true,
                    onTap: () => onVote!(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoteButton(
                    label: "It's gone",
                    count: r.gone,
                    icon: CupertinoIcons.checkmark,
                    selected: r.myVote == false,
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

class _StatusTag extends StatelessWidget {
  const _StatusTag(this.status);

  final ReportStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        ReportStatus.verified => const Tag('Confirmed'),
        ReportStatus.pending => const Tag('Pending', color: Palette.secondary, background: Palette.field),
        ReportStatus.flagged => const Tag('Flagged', color: Palette.danger, background: Palette.dangerSoft),
      };
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
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
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Palette.moss : Palette.field,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyles.subhead.copyWith(color: fg, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyles.subhead.copyWith(
                color: selected ? Colors.white : Palette.secondary,
                fontFeatures: TextStyles.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
