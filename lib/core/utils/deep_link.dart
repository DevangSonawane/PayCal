import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';

/// Routes paycal:// links. Opening a batch link joins it (if needed) and
/// pushes its screen; a user link shows their card with the shared batch.
class DeepLinks {
  static final _links = AppLinks();
  static bool _listening = false;

  static void listen(NavigatorState navigator) {
    if (_listening) return;
    _listening = true;
    _links.uriLinkStream.listen(
      (uri) => handle(uri, navigator),
      onError: (Object _) {},
    );
  }

  static void handle(Uri uri, NavigatorState navigator) {
    if (uri.scheme != 'paycal') return;
    switch (uri.host) {
      case 'user':
        _handleUser(uri.path.replaceAll('/', ''), navigator);
      case 'batch':
        _handleBatch(uri.path.replaceAll('/', ''), navigator);
      default:
        // Unknown link target: fill in when new host types exist.
        return;
    }
  }

  static Member? _findUser(String id) {
    for (final b in MockData.batches) {
      for (final m in b.members) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  static void _handleUser(String id, NavigatorState navigator) {
    final member = _findUser(id);
    if (member == null) return;
    final context = navigator.context;
    showPopCard<void>(
      context: context,
      title: 'PayCal user',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(initials: member.initials, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ID $id',
                      style: AppTypography.caption.copyWith(
                        color: AppPalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final b in MockData.batches)
            if (b.members.any((m) => m.id == member.id) &&
                b.members.any((m) => m.id == MockData.meId))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OptionTile(
                  title: 'With ${b.name}',
                  support: 'A batch you both share',
                  onTap: () {
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => BatchDetailScreen(batch: b),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
      footer: PrimaryButton(label: 'Close', onPressed: () => navigator.pop()),
    );
  }

  static void _handleBatch(String id, NavigatorState navigator) {
    final batchId = id;
    for (final b in [...MockData.batches]) {
      if (b.id != batchId) continue;
      if (!b.members.any((m) => m.id == MockData.meId)) {
        b.members.add(Member(id: MockData.meId, name: MockData.me.name));
        showAppToast(navigator.context, 'You joined ${b.name}');
      }
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => BatchDetailScreen(batch: b)),
      );
      return;
    }
    showAppToast(navigator.context, 'That batch invite does not exist');
  }
}
