import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/report.dart';

/// A community or personal report row, matching the web `ReportCard`.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    this.onConfirm,
    this.onClear,
    this.isMine = false,
  });

  final Report report;
  final VoidCallback? onConfirm;
  final VoidCallback? onClear;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('d MMM · h:mm a').format(report.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1E2B22), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.type, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      report.location.isEmpty ? 'Kuala Lumpur' : report.location,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateLabel, style: theme.textTheme.bodySmall),
                  if (isMine) ...[
                    const SizedBox(height: 6),
                    _StatusPill(status: report.status),
                  ],
                ],
              ),
            ],
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              report.description,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ],
          if (report.imagePath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(report.imagePath!),
                height: 148,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (isMine)
            _MyReportFooter(report: report)
          else
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    icon: '👍',
                    label: 'Still there (${report.confirmations})',
                    color: AppColors.success,
                    background: AppColors.successSoft,
                    onTap: onConfirm,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoteButton(
                    icon: '👎',
                    label: "It's gone (${report.clearances})",
                    color: AppColors.accent,
                    background: AppColors.accentSoft,
                    onTap: onClear,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MyReportFooter extends StatelessWidget {
  const _MyReportFooter({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    return switch (report.status) {
      ReportStatus.verified => const Row(
          children: [
            Icon(Icons.verified, size: 18, color: AppColors.success),
            SizedBox(width: 8),
            Text('Verified by the community', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
          ],
        ),
      ReportStatus.flagged => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.flag, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flagged · ${report.flagReason ?? 'Needs review'}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ReportStatus.pending => const Row(
          children: [
            Icon(Icons.hourglass_bottom, size: 18, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Pending verification', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
          ],
        ),
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color(status.backgroundValue),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(status.textColorValue)),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}