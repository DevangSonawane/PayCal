import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filterAll = 'All';

  Iterable<ActivityEvent> get _events {
    final filtered = PayCalRepositories.instance.activity.cachedEvents
        .where((e) => _filterAll == 'All' || e.cribName == _filterAll)
        .toList();
    return filtered;
  }

  void _showFilters() async {
    final picked = await showPopCard<String>(
      context: context,
      title: 'Filter activity',
      builder: (_) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final name in [
            'All',
            for (final b in PayCalRepositories.instance.cribs.cachedCribs)
              b.name,
          ])
            StickerPill(
              label: name,
              selected: _filterAll == name,
              showCheck: true,
              onTap: () => Navigator.of(context).pop(name),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _filterAll = picked);
      showAppToast(context, 'Showing $picked activity');
    }
  }

  void _showEvent(ActivityEvent event) {
    final crib = PayCalRepositories.instance.cribs.cachedCribs
        .where((b) => b.name == event.cribName)
        .firstOrNull;
    showPopCard<void>(
      context: context,
      title: 'Update',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: AppTypography.titleSmall.copyWith(
              color: AppPalette.current.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            event.subtitle,
            style: AppTypography.body.copyWith(color: AppPalette.current.ink),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '${event.time} · ${event.cribName}',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
            ),
          ),
        ],
      ),
      footer: crib == null
          ? null
          : PrimaryButton(
              label: 'Open ${crib.name}',
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CribDetailScreen(crib: crib),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ActivityPalette.current.page,
    body: CustomPaint(
      painter: _ActivityRulesPainter(),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          24,
          40,
          24,
          MediaQuery.of(context).padding.bottom + 100,
        ),
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _ActivityPalette.current.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: _ActivityPalette.current.page,
                  size: 21,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Activity',
                style: AppTypography.title.copyWith(
                  color: _ActivityPalette.current.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: _showFilters,
                icon: Icon(
                  Icons.tune_rounded,
                  color: _ActivityPalette.current.ink,
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _ActivityPalette.current.lime,
              border: Border.all(color: _ActivityPalette.current.ink, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.ink,
                  size: 29,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Everything your groups have been up to.',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const WedgeBullet(size: 12),
              const SizedBox(width: 8),
              Text(
                'Latest updates',
                style: AppTypography.title.copyWith(
                  color: _ActivityPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_events.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppPalette.current.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _ActivityPalette.current.ink,
                  width: 1.5,
                ),
              ),
              child: Text(
                'Nothing here for this filter yet.',
                style: AppTypography.label.copyWith(
                  color: _ActivityPalette.current.grey,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else ...[
            for (final event in _events) ...[
              if (_filterAll == 'All' &&
                  (event == _events.first ||
                      _events
                              .toList()[_events.toList().indexOf(event) - 1]
                              .cribName !=
                          event.cribName))
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.sm),
                  child: Text(
                    event.cribName.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: _ActivityPalette.current.pink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              _ActivityCard(
                title: event.title,
                subtitle: event.subtitle,
                time: event.time,
                accent: event.title.contains('You')
                    ? _ActivityPalette.current.purple
                    : _ActivityPalette.current.pink,
                onTap: () => _showEvent(event),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _ActivityPalette {
  static AppPalette get current => AppPalette.current;
}

class _ActivityRulesPainter extends CustomPainter {
  const _ActivityRulesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x080A0A0A), Color(0x080A0A0A), Color(0x000A0A0A)],
        stops: [0, .58, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 180))
      ..strokeWidth = 1;
    for (var y = 0.0; y < math.min(size.height, 180); y += 6) {
      canvas.drawLine(Offset.zero + Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.accent,
    this.onTap,
  });
  final String title, subtitle, time;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppPalette.current.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ActivityPalette.current.ink, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _ActivityPalette.current.ink,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label.copyWith(
                        color: _ActivityPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: _ActivityPalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: AppTypography.caption.copyWith(
                  color: _ActivityPalette.current.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
