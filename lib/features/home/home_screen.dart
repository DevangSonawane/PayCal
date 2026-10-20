import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/solid_bottom_nav.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';
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
          .push(MaterialPageRoute<void>(builder: (_) => SearchScreen()));
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
          painter: _StripePainter(),
          child: SizedBox.expand(
            child: Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.indigo,
                  onRefresh: () async {},
                  child: ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      40,
                      24,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    children: [
                      _TopBar(onTap: _onTopAction),
                      SizedBox(height: 18),
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
                      SizedBox(height: 22),
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
                      SizedBox(height: 18),
                      const _GoodVibesStub(),
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
}

/// Faint vertical pinstripes across the whole screen.
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
        decoration: BoxDecoration(
          color: _HomePalette.current.ink,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.change_history,
          color: _HomePalette.current.page,
          size: 20,
        ),
      ),
      SizedBox(width: 8),
      Text(
        'PayCal',
        style: AppTypography.title.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: _HomePalette.current.ink,
        ),
      ),
      Spacer(),
      IconButton(
        onPressed: () => onTap('Search'),
        icon: Icon(Icons.search_rounded, color: _HomePalette.current.ink),
      ),
      IconButton(
        onPressed: () => onTap('Scan'),
        icon: Icon(Icons.qr_code_scanner, color: _HomePalette.current.ink),
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
          duration: Duration(milliseconds: 700),
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
                    color: _HomePalette.current.ink.withValues(
                      alpha: lift.abs() * .16,
                    ),
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
      Positioned.fill(child: CustomPaint(painter: _HeroPainter())),
      // Name block (white area)
      Positioned(
        left: 44,
        top: 22,
        right: w * .40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
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
            _OverlapCircles(),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.amount >= 0 ? 'You are owed:' : 'You owe:',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 2),
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
                            color: AppColors.ink,
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
                            color: AppColors.ink,
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
            color: AppPalette.current.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.link_rounded, color: _HomePalette.current.ink),
        ),
      ),
    ],
  );

  Widget _buildBack(double w) => Container(
    decoration: BoxDecoration(
      color: AppPalette.current.card,
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
              decoration: BoxDecoration(
                color: _HomePalette.current.ink,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_rounded, color: Colors.white, size: 15),
            ),
            SizedBox(width: 8),
            Text(
              'Scan to pay & split',
              style: AppTypography.label.copyWith(
                color: _HomePalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        QrImageView(
          data: 'paycal://user/${MockData.meId}',
          version: QrVersions.auto,
          size: 104,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: _HomePalette.current.ink,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: _HomePalette.current.ink,
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap to flip back',
              style: AppTypography.caption.copyWith(
                color: _HomePalette.current.grey,
              ),
            ),
            SizedBox(width: 10),
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _HomePalette.current.pink,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: _HomePalette.current.ink,
                    width: 1.5,
                  ),
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
              color: AppPalette.current.card,
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
            decoration: BoxDecoration(
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
  _HeroPainter();
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(28));
    c.save();
    c.clipRRect(rr);

    // A raised surface in dark mode keeps the hero copy readable.
    c.drawPaint(Paint()..color = _HomePalette.current.card);
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
  bool shouldRepaint(CustomPainter o) => true;
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
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        _Pick(
          label: 'Add',
          sub: '',
          onTap: onAdd,
          child: Icon(Icons.add, size: 31, color: _HomePalette.current.ink),
        ),
        SizedBox(
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
  _DashedLinePainter();
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
    padding: EdgeInsets.only(right: 10),
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
                        ? Border.all(
                            color: _HomePalette.current.ink,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: SizedBox(
                    width: selected ? 64 : 66,
                    height: selected ? 64 : 66,
                    child: child,
                  ),
                ),
                if (selected)
                  Positioned(
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
            SizedBox(height: 6),
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

class _BatchDeck extends StatefulWidget {
  const _BatchDeck({
    required this.batches,
    required this.balanceFor,
    required this.spentFor,
    required this.onCreate,
    required this.onOpen,
  });
  final List<Batch> batches;
  final int Function(Batch) balanceFor;
  final int Function(Batch) spentFor;
  final VoidCallback onCreate;
  final ValueChanged<Batch> onOpen;

  @override
  State<_BatchDeck> createState() => _BatchDeckState();
}

class _BatchDeckState extends State<_BatchDeck> {
  late final PageController _controller;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.batches.isEmpty) {
      return _EmptyDeck(onCreate: widget.onCreate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your money, in motion',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w800,
                color: _HomePalette.current.ink,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: widget.onCreate,
              tooltip: 'Create a batch',
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _HomePalette.current.ink,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        Text(
          'Swipe through your shared worlds.',
          style: AppTypography.caption.copyWith(
            color: _HomePalette.current.grey,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 205,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.batches.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) => AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: index == _page ? 1 : .94,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _BatchCard(
                  batch: widget.batches[index],
                  balance: widget.balanceFor(widget.batches[index]),
                  spent: widget.spentFor(widget.batches[index]),
                  color: index.isEven ? AppColors.purple : AppColors.pink,
                  onTap: () => widget.onOpen(widget.batches[index]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < widget.batches.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 5),
                width: i == _page ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page
                      ? _HomePalette.current.ink
                      : _HomePalette.current.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            const Spacer(),
            Text(
              'tap a card to open',
              style: AppTypography.caption.copyWith(
                color: _HomePalette.current.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.balance,
    required this.spent,
    required this.color,
    required this.onTap,
  });
  final Batch batch;
  final int balance, spent;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _HomePalette.current.ink, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -21,
            child: _OrbitDot(color: AppColors.lime, size: 72),
          ),
          Positioned(
            right: 31,
            bottom: -26,
            child: _OrbitDot(color: Colors.white, size: 54),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _HomePalette.current.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      batch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                balance >= 0 ? 'YOU ARE OWED' : 'YOU OWE',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: .8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Money.format(balance.abs(), batch.currency),
                style: AppTypography.headline.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${batch.members.length} people · ${Money.format(spent, batch.currency)} tracked',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .86, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.elasticOut,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: _HomePalette.current.ink, width: 1.5),
      ),
    ),
  );
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onCreate,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      height: 170,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _HomePalette.current.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 30),
          const Spacer(),
          Text(
            'Make your first money world',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'A flat, trip, or whatever you share.',
            style: AppTypography.body.copyWith(
              color: _HomePalette.current.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A non-interactive, hand-tag-inspired breather for the lower home area.
class _GoodVibesStub extends StatelessWidget {
  const _GoodVibesStub();

  @override
  Widget build(BuildContext context) {
    const words = 'all good\nin the hood, bro.';
    final tagStyle = AppTypography.display.copyWith(
      fontFamily: 'SedgwickAveDisplay',
      fontSize: 44,
      fontWeight: FontWeight.w400,
      height: .9,
      letterSpacing: .2,
    );
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Center(
        child: Transform.rotate(
          angle: -.045,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -2,
                top: -2,
                child: Text(
                  words,
                  textAlign: TextAlign.center,
                  style: tagStyle.copyWith(color: Colors.white),
                ),
              ),
              Positioned(
                left: 4,
                top: 5,
                child: Text(
                  words,
                  textAlign: TextAlign.center,
                  style: tagStyle.copyWith(color: AppColors.pink),
                ),
              ),
              Text(
                words,
                textAlign: TextAlign.center,
                style: tagStyle.copyWith(
                  color: _HomePalette.current.ink,
                  shadows: const [
                    Shadow(color: Color(0x22000000), offset: Offset(1, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
