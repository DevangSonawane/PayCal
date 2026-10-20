import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/empty_state.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';
import 'package:paycal/features/batches/batch_edit_sheet.dart';
import 'package:paycal/features/batches/create_batch_popup.dart';

enum _Filter { all, owed, owe, settled }

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});
  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late _Filter filter;

  @override
  void initState() {
    super.initState();
    const filters = _Filter.values;
    final s = AppSettings.instance;
    filter = filters[s.batchesFilterIndex.clamp(0, filters.length - 1)];
  }

  void _setFilter(_Filter f) {
    setState(() => filter = f);
    AppSettings.instance.update(batchesFilterIndex: _Filter.values.indexOf(f));
  }

  int _netFor(Batch b) {
    final inputs = MockData.expenses
        .where((e) => e.batchId == b.id)
        .map(
          (e) => ExpenseInput(
            totalMinor: e.totalMinor,
            payerId: e.payerId,
            shares: e.shares,
          ),
        )
        .toList();
    return BalanceEngine.nets(
          inputs,
          b.members.map((m) => m.id).toList(),
        )[MockData.meId] ??
        0;
  }

  bool _matches(int net) => switch (filter) {
    _Filter.all => true,
    _Filter.owed => net > 0,
    _Filter.owe => net < 0,
    _Filter.settled => net == 0,
  };

  void _open(Batch b) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b)));

  Future<void> _onCreate() async {
    final created = await showCreateBatch(context);
    if (created && mounted) {
      setState(() {});
      showQuirkyConfirm(context, 'All set! Batch created');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MockData.batches.isEmpty) {
      return Scaffold(
        backgroundColor: AppPalette.current.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              title: 'No batches yet',
              body: 'Batches are where shared money lives. Start one — rent, trips, that suspiciously expensive team lunch.',
              actionLabel: 'Create batch',
              onAction: _onCreate,
            ),
          ),
        ),
      );
    }

    final nets = {for (final b in MockData.batches) b.id: _netFor(b)};
    var owed = 0, owe = 0;
    for (final n in nets.values) {
      if (n > 0) {
        owed += n;
      } else {
        owe -= n;
      }
    }
    final visible = MockData.batches
        .where((b) => _matches(nets[b.id] ?? 0))
        .toList();

    return Scaffold(
      backgroundColor: _BPalette.current.page,
      body: CustomPaint(
        painter: _StripePainter(),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              40,
              24,
              MediaQuery.of(context).padding.bottom + 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(onCreate: _onCreate),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'To receive',
                        amount: owed,
                        dot: _BPalette.current.lime,
                        icon: Icons.south_west_rounded,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'To pay',
                        amount: owe,
                        dot: _BPalette.current.pink,
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22),
                Row(
                  children: [
                    WedgeBullet(),
                    SizedBox(width: 8),
                    Text(
                      'Your batches',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _BPalette.current.ink,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${visible.length} shown',
                      style: AppTypography.caption.copyWith(
                        color: _BPalette.current.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _FilterRow(selected: filter, onChanged: _setFilter),
                SizedBox(height: 16),
                if (visible.isEmpty)
                  _NoMatches()
                else
                  for (final b in visible)
                    _BatchCard(
                      batch: b,
                      net: nets[b.id] ?? 0,
                      onTap: () => _open(b),
                      onEdit: () async {
                        await showBatchEdit(
                          context,
                          b,
                          onDone: () => setState(() {}),
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BPalette {
  static AppPalette get current => AppPalette.current;
}

class _StripePainter extends CustomPainter {
  _StripePainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x080A0A0A), Color(0x080A0A0A), Color(0x000A0A0A)],
        stops: [0, .58, 1],
      ).createShader(Rect.fromLTWH(0, 0, s.width, 180))
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < math.min(s.height, 180); y += 6) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter o) => true;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _BPalette.current.ink,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.layers_outlined,
            color: _BPalette.current.page,
            size: 19,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'Batches',
          style: AppTypography.title.copyWith(
            color: _BPalette.current.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        InkWell(
          onTap: onCreate,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _BPalette.current.pink,
              border: Border.all(color: _BPalette.current.ink, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '+ Create',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.dot,
    required this.icon,
  });
  final String label;
  final int amount;
  final Color dot;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppPalette.current.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _BPalette.current.ink, width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            border: Border.all(color: _BPalette.current.ink, width: 1.5),
          ),
          child: Icon(
            icon,
            size: 18,
            color: dot == _BPalette.current.pink
                ? Colors.white
                : _BPalette.current.ink,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: _BPalette.current.grey,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(amount, 'INR'),
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _BPalette.current.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});
  final _Filter selected;
  final ValueChanged<_Filter> onChanged;

  static const _labels = {
    _Filter.all: 'All',
    _Filter.owed: 'Owed to you',
    _Filter.owe: 'You owe',
    _Filter.settled: 'Settled',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.symmetric(horizontal: 4),
      children: [
        for (final f in _Filter.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StickerPill(
              label: _labels[f]!,
              selected: selected == f,
              horizontal: 16,
              vertical: 8,
              onTap: () => onChanged(f),
            ),
          ),
      ],
    ),
  );
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.net,
    required this.onTap,
    required this.onEdit,
  });
  final Batch batch;
  final int net;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final direction = net > 0
        ? MoneyDirection.owed
        : (net < 0 ? MoneyDirection.owe : null);
    final status = net > 0 ? 'Owed' : (net < 0 ? 'You owe' : 'Settled');
    final statusBg = net > 0
        ? _BPalette.current.lime
        : (net < 0 ? _BPalette.current.pink : _BPalette.current.chip);
    final statusFg = net < 0 ? Colors.white : _BPalette.current.ink;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppPalette.current.card,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          onLongPress: onEdit,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _BPalette.current.ink, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _BPalette.current.ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.groups_2_outlined,
                        color: _BPalette.current.page,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _BPalette.current.ink,
                            ),
                          ),
                          Text(
                            '${batch.members.length} members · ${batch.currency}',
                            style: AppTypography.caption.copyWith(
                              color: _BPalette.current.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(99),
                        border: net > 0
                            ? Border.all(color: _BPalette.current.ink, width: 1)
                            : null,
                      ),
                      child: Text(
                        status,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: statusFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: _BPalette.current.hairline),
                const SizedBox(height: 14),
                Row(
                  children: [
                    AvatarStack(
                      initials: batch.members.map((m) => m.initials).toList(),
                      size: 30,
                      max: 3,
                    ),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: MoneyText(
                          amount: net.abs(),
                          currency: batch.currency,
                          direction: direction,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, color: _BPalette.current.ink),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Text(
      'Tumbleweeds — no batches match this filter.',
      style: AppTypography.caption.copyWith(color: _BPalette.current.grey),
      textAlign: TextAlign.center,
    ),
  );
}
