import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/solid_bottom_nav.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';
import 'package:paycal/features/batches/batch_edit_sheet.dart';
import 'package:paycal/features/batches/create_batch_popup.dart';
import 'package:paycal/features/scans/scan_flow.dart';
import 'package:paycal/features/search/search_screen.dart';

String _initials(String name) {
  final parts = name.split(' ').where((w) => w.isNotEmpty).take(2);
  final s = parts.map((w) => w[0]).join().toUpperCase();
  return s.isEmpty ? '?' : s;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onDestinationSelected,
    this.showNav = true,
    this.selectedIndex = 0,
  });
  final ValueChanged<int>? onDestinationSelected;
  final bool showNav;
  final int selectedIndex;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selected;

  int net(Batch b) =>
      BalanceEngine.nets(
        MockData.expenses
            .where((e) => e.batchId == b.id)
            .map(
              (e) => ExpenseInput(
                totalMinor: e.totalMinor,
                payerId: e.payerId,
                shares: e.shares,
              ),
            )
            .toList(),
        b.members.map((m) => m.id).toList(),
      )[MockData.meId] ??
      0;

  int spent(Batch b) => MockData.expenses
      .where((e) => e.batchId == b.id)
      .fold<int>(0, (sum, e) => sum + e.totalMinor);

  int paidBy(String memberId) => MockData.expenses
      .where((e) => e.payerId == memberId)
      .fold<int>(0, (sum, e) => sum + e.totalMinor);

  void toast(String s) {
    showAppToast(context, '$s is coming soon.');
  }

  void _onTopAction(String action) {
    if (action == 'Scan') {
      showScanFlow(context);
      return;
    }
    if (action == 'Search') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));
      return;
    }
    if (action == 'Add') {
      showQuickAdd(context);
      return;
    }
    toast(action);
  }

  @override
  Widget build(BuildContext c) {
    var owed = 0, owe = 0;
    for (final b in MockData.batches) {
      final n = net(b);
      if (n > 0) {
        owed += n;
      } else {
        owe -= n;
      }
    }
    final me = MockData.me;
    final contacts = MockData.batches.isEmpty
        ? <Member>[]
        : MockData.batches.first.members
            .where((m) => m.id != me.id)
            .take(4)
            .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _HomePalette.current.page,
        body: CustomPaint(
          painter: const _StripePainter(),
          child: SizedBox.expand(
            child: Stack(
              children: [
                RefreshIndicator(
                  color: _HomePalette.current.indigo,
                  onRefresh: () async {},
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      40,
                      24,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    children: [
                      _TopBar(onTap: _onTopAction),
                      const SizedBox(height: 18),
                      _HeroCard(
                        name: me.name,
                        amount: owed - owe,
                        hidden: AppSettings.instance.amountHidden,
                        onEye: () {
                          AppSettings.instance.update(
                            amountHidden: !AppSettings.instance.amountHidden,
                          );
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 22),
                      _QuickPickRow(
                        contacts: contacts,
                        selected: selected,
                        paidBy: paidBy,
                        onAdd: () => _onTopAction('Add'),
                        onSelect: (m) {
                          setState(() => selected = m.id);
                          showQuickAdd(
                            context,
                            payeeId: m.id,
                            onSaved: () => setState(() {}),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        onCreate: () async {
                          final created = await showCreateBatch(context);
                          if (created == true && mounted) {
                            setState(() {});
                            showQuirkyConfirm(
                              context,
                              'All set! Batch created',
                            );
                          }
                        },
                      ),
                      for (final b in MockData.batches) ...[
                        _GroupRow(
                          batch: b,
                          balance: net(b),
                          spent: spent(b),
                          onOpen: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BatchDetailScreen(batch: b),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          onCopy: () {
                            Clipboard.setData(
                              ClipboardData(text: 'paycal://batch/${b.id}'),
                            );
                            showAppToast(context, 'Batch invite link copied');
                          },
                          onEdit: () async {
                            await showBatchEdit(
                              context,
                              b,
                              onDone: () => setState(() {}),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.showNav)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _FloatingNav(
                      selectedIndex: widget.selectedIndex,
                      onSelect: widget.onDestinationSelected,
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

class _HomePalette {
  static AppPalette get current => AppPalette.current;
  static const page = Color(0xFFFFFEFC),
      lime = Color(0xFFD8FF00),
      ink = Color(0xFF0A0A0A),
      indigo = Color(0xFF2014B8),
      purple = Color(0xFF9B70F2),
      pink = Color(0xFFF0477F),
      grey = Color(0xFF8A8A8A),
      chip = Color(0xFFF1F1F4),
      hairline = Color(0xFFE6E6EA);
}

/// Faint vertical pinstripes across the whole screen.
class _StripePainter extends CustomPainter {
  const _StripePainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x080A0A0A), Color(0x080A0A0A), Color(0x000A0A0A)],
        stops: [0, .58, 1],
      ).createShader(Rect.fromLTWH(0, 0, s.width, 180))
      ..strokeWidth = 1
      ..isAntiAlias = false;
    final stripeHeight = math.min(s.height, 180.0);
    for (double y = 0; y < stripeHeight; y += 6) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter o) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onTap});
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: _HomePalette.current.ink,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.change_history, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 8),
      Text(
        'PayCal',
        style: AppTypography.title.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: _HomePalette.current.ink,
        ),
      ),
      const Spacer(),
      IconButton(
        onPressed: () => onTap('Search'),
        icon: const Icon(Icons.search_rounded, color: _HomePalette.current.ink),
      ),
      IconButton(
        onPressed: () => onTap('Scan'),
        icon: const Icon(Icons.qr_code_scanner, color: _HomePalette.current.ink),
      ),
    ],
  );
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.name,
    required this.amount,
    required this.hidden,
    required this.onEye,
  });
  final String name;
  final int amount;
  final bool hidden;
  final VoidCallback onEye;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  var showCode = false;

  void _flip() {
    HapticFeedback.mediumImpact();
    setState(() => showCode = !showCode);
  }

  @override
  Widget build(BuildContext c) => LayoutBuilder(
    builder: (c, b) {
      final w = b.maxWidth;
      final h = (w * .56).clamp(190.0, 230.0);
      return GestureDetector(
        onTap: _flip,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: showCode ? 1 : 0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (c, t, _) {
            final lift = math.sin(t * math.pi);
            final stretch = (1 + .06 * lift).clamp(.9, 1.2);
            final rot = t * math.pi;
            final rotBack = (1 - t) * math.pi;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _HomePalette.current.ink.withValues(alpha: lift.abs() * .16),
                    blurRadius: 10 + 26 * lift.abs(),
                    offset: Offset(0, 4 + 12 * lift.abs()),
                  ),
                ],
              ),
              child: Transform(
                alignment: Alignment.center,
                // The card is tossed up and stretches a touch mid-flip, like a
                // flicked playing card, then lands with a bounce.
                transform: Matrix4.identity()
                  ..translateByDouble(0.0, -16 * lift, 0.0, 1.0)
                  ..scaleByDouble(stretch, stretch, stretch, 1.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    height: h,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: t < .5 ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: t >= .4,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.002)
                                ..rotateY(rot),
                              child: _buildFront(w),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: t >= .5 ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: t < .6,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.002)
                                ..rotateY(rotBack),
                              child: _buildBack(w),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _buildFront(double w) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Positioned.fill(child: CustomPaint(painter: _HeroPainter())),
      // Name block (white area)
      Positioned(
        left: 44,
        top: 22,
        right: w * .40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hey',
              style: TextStyle(color: _HomePalette.current.grey, fontSize: 13),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.name,
                style: AppTypography.title.copyWith(
                  color: _HomePalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      // Lime area: circles + balance
      Positioned(
        left: 20,
        right: w * .30,
        bottom: 20,
        child: Row(
          children: [
            const _OverlapCircles(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.amount >= 0 ? 'You are owed:' : 'You owe:',
                    style: const TextStyle(
                      color: _HomePalette.current.ink,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.hidden
                              ? '••••'
                              : Money.format(widget.amount.abs(), 'INR'),
                          style: AppTypography.title.copyWith(
                            color: _HomePalette.current.ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: widget.onEye,
                          child: Icon(
                            widget.hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _HomePalette.current.ink,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // White chip with link icon
      Positioned(
        right: 20,
        bottom: 22,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.link_rounded, color: _HomePalette.current.ink),
        ),
      ),
    ],
  );

  Widget _buildBack(double w) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _HomePalette.current.ink, width: 1.5),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: _HomePalette.current.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Scan to pay & split',
              style: AppTypography.label.copyWith(
                color: _HomePalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        QrImageView(
          data: 'paycal://user/${MockData.meId}',
          version: QrVersions.auto,
          size: 104,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: _HomePalette.current.ink,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: _HomePalette.current.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap to flip back',
              style: AppTypography.caption.copyWith(color: _HomePalette.current.grey),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                await SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Pay and split with me on PayCal — '
                        'scan this code or open the link: '
                        'paycal://user/${MockData.meId}',
                    title: 'My PayCal code',
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _HomePalette.current.pink,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _HomePalette.current.ink, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.share_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Share',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OverlapCircles extends StatelessWidget {
  const _OverlapCircles();
  @override
  Widget build(BuildContext c) => SizedBox(
    width: 54,
    height: 38,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _HomePalette.current.ink, width: 1.5),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 4,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _HomePalette.current.pink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter();
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(28),
    );
    c.save();
    c.clipRRect(rr);

    // White top, lime bottom
    c.drawPaint(Paint()..color = Colors.white);
    final split = s.height * .45;
    c.drawRect(
      Rect.fromLTWH(0, split, s.width, s.height - split),
      Paint()..color = _HomePalette.current.lime,
    );

    // One diagonal: (0.66w, 0) -> (0.88w, h)
    final topX = s.width * .66;
    final botX = s.width * .88;
    final splitX = topX + (botX - topX) * (split / s.height);

    // Purple: right of the diagonal, above the split
    c.drawPath(
      Path()
        ..moveTo(topX, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, split)
        ..lineTo(splitX, split)
        ..close(),
      Paint()..color = _HomePalette.current.purple,
    );

    // Black: right of the diagonal, below the split
    c.drawPath(
      Path()
        ..moveTo(splitX, split)
        ..lineTo(s.width, split)
        ..lineTo(s.width, s.height)
        ..lineTo(botX, s.height)
        ..close(),
      Paint()..color = _HomePalette.current.ink,
    );
    c.restore();

    // Border on top, not clipped
    c.drawRRect(
      rr.deflate(1),
      Paint()
        ..color = _HomePalette.current.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CustomPainter o) => false;
}

class _QuickPickRow extends StatelessWidget {
  const _QuickPickRow({
    required this.contacts,
    required this.selected,
    required this.paidBy,
    required this.onAdd,
    required this.onSelect,
  });
  final List<Member> contacts;
  final String? selected;
  final int Function(String memberId) paidBy;
  final VoidCallback onAdd;
  final ValueChanged<Member> onSelect;

  @override
  Widget build(BuildContext c) => SizedBox(
    height: 118,
    child: ListView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _Pick(
          label: 'Add',
          sub: '',
          onTap: onAdd,
          child: const Icon(Icons.add, size: 31, color: _HomePalette.current.ink),
        ),
        const SizedBox(
          width: 25,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 1,
              height: 70,
              child: CustomPaint(painter: _DashedLinePainter()),
            ),
          ),
        ),
        for (final m in contacts)
          _Pick(
            label: m.name.split(' ').first,
            sub: Money.format(paidBy(m.id), 'INR'),
            selected: selected == m.id,
            onTap: () => onSelect(m),
            child: ClipOval(
              child: Avatar(initials: _initials(m.name), size: 66),
            ),
          ),
      ],
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = _HomePalette.current.grey.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (double y = 0; y < s.height; y += 8) {
      c.drawLine(Offset(0, y), Offset(0, math.min(y + 4, s.height)), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter o) => false;
}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.sub,
    required this.onTap,
    required this.child,
    this.selected = false,
  });
  final String label, sub;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _HomePalette.current.chip,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: _HomePalette.current.ink, width: 1.5)
                        : null,
                  ),
                  child: SizedBox(
                    width: selected ? 64 : 66,
                    height: selected ? 64 : 66,
                    child: child,
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: -1,
                    top: -2,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: _HomePalette.current.ink,
                      child: Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: _HomePalette.current.ink,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: _HomePalette.current.grey,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      const WedgeBullet(),
      const SizedBox(width: 8),
      Text(
        'Your groups',
        style: AppTypography.title.copyWith(
          fontWeight: FontWeight.w800,
          color: _HomePalette.current.ink,
        ),
      ),
      const Spacer(),
      TextButton(
        onPressed: onCreate,
        child: Text(
          '+ Create',
          style: AppTypography.label.copyWith(
            color: _HomePalette.current.pink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.batch,
    required this.balance,
    required this.spent,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
  });
  final Batch batch;
  final int balance, spent;
  final VoidCallback onOpen, onCopy, onEdit;

  @override
  Widget build(BuildContext c) => Column(
    children: [
      InkWell(
        onTap: onOpen,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 36,
                decoration: BoxDecoration(
                  color: _HomePalette.current.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
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
                        color: _HomePalette.current.ink,
                      ),
                    ),
                    Text(
                      '${batch.members.length} members',
                      style: AppTypography.caption.copyWith(
                        color: _HomePalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(
                  Icons.copy_outlined,
                  size: 20,
                  color: _HomePalette.current.ink,
                ),
              ),
              Container(width: 1, height: 22, color: _HomePalette.current.hairline),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, color: _HomePalette.current.ink),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 68),
        child: Column(
          children: [
            _amountRow('Your balance', balance),
            const Divider(height: 18, color: _HomePalette.current.hairline),
            _amountRow('Total spent', spent),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ],
  );

  Widget _amountRow(String label, int value) => Row(
    children: [
      const CircleAvatar(
        radius: 14,
        backgroundColor: _HomePalette.current.chip,
        child: Icon(Icons.currency_rupee, size: 14, color: _HomePalette.current.grey),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: AppTypography.bodyLarge.copyWith(
            color: _HomePalette.current.grey,
            fontSize: 14,
          ),
        ),
      ),
      Text(
        Money.format(value.abs(), 'INR'),
        style: AppTypography.label.copyWith(
          fontWeight: FontWeight.w800,
          color: _HomePalette.current.ink,
        ),
      ),
    ],
  );
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({this.onSelect, this.selectedIndex = 0});
  final ValueChanged<int>? onSelect;
  final int selectedIndex;

  @override
  Widget build(BuildContext c) => SafeArea(
    top: false,
    child: SolidBottomNav(
      currentIndex: selectedIndex,
      onDestinationSelected: onSelect ?? (_) {},
    ),
  );
}
