import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

enum ChipStatus { pending, confirmed, selfManaged, disputed, outstanding, paid }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.status});

  final String label;
  final ChipStatus status;

  Color get _text {
    switch (status) {
      case ChipStatus.pending:
        return AppPalette.current.pendingText;
      case ChipStatus.confirmed:
        return AppPalette.current.owedText;
      case ChipStatus.selfManaged:
        return AppPalette.current.textSecondary;
      case ChipStatus.disputed:
        return AppPalette.current.oweText;
      case ChipStatus.outstanding:
        return AppPalette.current.textSecondary;
      case ChipStatus.paid:
        return AppPalette.current.owedText;
    }
  }

  Color get _bg {
    switch (status) {
      case ChipStatus.pending:
        return AppPalette.current.pendingTint;
      case ChipStatus.confirmed:
        return AppPalette.current.owedTint;
      case ChipStatus.selfManaged:
        return AppPalette.current.surface;
      case ChipStatus.disputed:
        return AppPalette.current.oweTint;
      case ChipStatus.outstanding:
        return AppPalette.current.surface;
      case ChipStatus.paid:
        return AppPalette.current.owedTint;
    }
  }

  IconData get _icon {
    switch (status) {
      case ChipStatus.pending:
        return Icons.schedule;
      case ChipStatus.confirmed:
        return Icons.check_circle_outline;
      case ChipStatus.selfManaged:
        return Icons.info_outline;
      case ChipStatus.disputed:
        return Icons.error_outline;
      case ChipStatus.outstanding:
        return Icons.remove_circle_outline;
      case ChipStatus.paid:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadii.chipPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: _text),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.caption.copyWith(color: _text)),
        ],
      ),
    );
  }
}
