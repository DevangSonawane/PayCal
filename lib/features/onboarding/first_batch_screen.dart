import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confetti_burst.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/segmented_control.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/features/onboarding/invite_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/features/onboarding/onboarding_flow.dart';

const currencies = ['INR', 'USD', 'EUR', 'GBP'];

class FirstBatchScreen extends StatefulWidget {
  const FirstBatchScreen({super.key, required this.draft});
  final OnboardingDraft draft;
  @override
  State<FirstBatchScreen> createState() => _FirstBatchScreenState();
}

class _FirstBatchScreenState extends State<FirstBatchScreen> {
  int _tab = 0;
  late final TextEditingController _name;
  String _currency = 'INR';
  late List<String> _cats;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    final role = roles.firstWhere(
      (r) => r.id == widget.draft.role,
      orElse: () => roles[1],
    );
    _name = TextEditingController(text: role.batchHint);
    _cats = List.of(
      widget.draft.splitTypes.isEmpty
          ? role.categories
          : widget.draft.splitTypes,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _continue() {
    if (_tab == 1 && _code.text.trim().isEmpty) {
      showAppToast(context, 'Paste the invite link or code first');
      return;
    }
    if (_tab == 0 &&
        (Validators.batchName(_name.text) != null || _cats.isEmpty)) {
      if (Validators.batchName(_name.text) != null) {
        showAppToast(
          context,
          'This batch needs a name — even "The Fund" works.',
        );
        return;
      }
      if (_cats.isEmpty) {
        showAppToast(
          context,
          'Pick at least one — it knows where the money goes.',
        );
        return;
      }
    }
    // Apply the onboarding answers to the live data: the batch the user just
    // named becomes a real batch, and the household size fills it with
    // placeholder members so the demo has someone to split with.
    final household = widget.draft.householdSize.clamp(1, 10);
    final members = <Member>[
      MockData.me,
      for (var i = 1; i < household; i++)
        Member(id: 'ob$i', name: 'Housemate $i'),
    ];
    MockData.batches.add(
      Batch(
        id: 'ob${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        currency: _currency,
        members: members,
        categories: _cats.isEmpty ? ['other'] : _cats,
      ),
    );
    widget.draft.clear();
    showConfettiBurst(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => InviteScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppPalette.current.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.current.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          size: 26,
                          color: AppPalette.current.ink,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppPalette.current.lime,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppPalette.current.ink, width: 2),
                        ),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 19,
                        color: AppPalette.current.ink,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Your first batch',
                        style: AppTypography.headline.copyWith(
                          color: AppPalette.current.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Batches keep shared money in one tidy place. Name it, pick categories, done.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                SegmentedControl(
                  tabs: ['Create a batch', 'Join with a link'],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, ?currentChild],
                    ),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_tab),
                      child: _tab == 0 ? _create() : _join(),
                    ),
                  ),
                ),
                PrimaryButton(
                  label: _tab == 0 ? 'Create batch' : 'Request to join',
                  onPressed: _continue,
                ),
                SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _create() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(label: 'Batch name', controller: _name),
        SizedBox(height: AppSpacing.lg),
        Text(
          'Currency',
          style: AppTypography.label.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: currencies
              .map(
                (c) => StickerPill(
                  label: c,
                  selected: _currency == c,
                  vertical: AppSpacing.sm,
                  onTap: () => setState(() => _currency = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Everyone in this batch uses this currency. You can change it later; amounts will not be converted.',
          style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Categories',
          style: AppTypography.label.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _cats
              .map(
                (c) => GestureDetector(
                  onTap: () => setState(() => _cats.remove(c)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.current.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c,
                          style: AppTypography.label.copyWith(
                            color: AppPalette.current.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: AppPalette.current.pink,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _join() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Invite link or code',
          hint: 'Paste your invite link',
          controller: _code,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'New members need admin approval before they can join.',
          style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
        ),
      ],
    );
  }
}
