import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/features/onboarding/onboarding_flow.dart';

/// A quick, product-led introduction shown before collecting setup details.
/// The previews deliberately mirror the app's core flows instead of using
/// generic marketing images: organise, split, and settle shared expenses.
class ProductTourScreen extends StatefulWidget {
  const ProductTourScreen({super.key});

  @override
  State<ProductTourScreen> createState() => _ProductTourScreenState();
}

class _ProductTourScreenState extends State<ProductTourScreen> {
  final _controller = PageController();
  var _page = 0;

  static const _slides = [
    _TourSlide(
      eyebrow: 'ONE HOME FOR SHARED MONEY',
      title: 'Keep every shared expense in one place.',
      body: 'Make a batch for your flat, trip, couple, or crew. Everyone sees the same running picture.',
      accent: AppColors.purple,
      icon: Icons.folder_shared_outlined,
    ),
    _TourSlide(
      eyebrow: 'NO MENTAL MATHS',
      title: 'Add it once. We split it fairly.',
      body: 'Log dinner, rent, taxis, and more. Choose the people involved and PayCal keeps each share clear.',
      accent: AppColors.pink,
      icon: Icons.call_split_rounded,
    ),
    _TourSlide(
      eyebrow: 'LESS CHASING PEOPLE',
      title: 'Settle up with the fewest transfers.',
      body: 'When it is time to square up, PayCal works out who pays whom so your group can move on.',
      accent: AppColors.lime,
      icon: Icons.done_all_rounded,
    ),
  ];

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: const PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: AppTypography.label.copyWith(
                        color: AppPalette.current.grey,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (_, index) => _TourPage(slide: _slides[index]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppPalette.current.ink
                            : AppPalette.current.ink.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: last ? 'Set up my account' : 'Next',
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TourSlide {
  const _TourSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
}

class _TourPage extends StatelessWidget {
  const _TourPage({required this.slide});
  final _TourSlide slide;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _PhonePreview(slide: slide),
        const SizedBox(height: AppSpacing.xl),
        Text(
          slide.eyebrow,
          style: AppTypography.caption.copyWith(
            color: AppPalette.current.grey,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          slide.title,
          style: AppTypography.display.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
            height: 1.04,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          slide.body,
          style: AppTypography.bodyLarge.copyWith(
            color: AppPalette.current.grey,
          ),
        ),
      ],
    ),
  );
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.slide});
  final _TourSlide slide;

  @override
  Widget build(BuildContext context) {
    final page = slide.icon;
    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.current.ink,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppPalette.current.ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.current.page,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: page == Icons.folder_shared_outlined
              ? const _BatchesPreview()
              : page == Icons.call_split_rounded
              ? const _SplitPreview()
              : const _SettlePreview(),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppPalette.current.ink, size: 20),
      const SizedBox(width: 7),
      Text(
        label,
        style: AppTypography.label.copyWith(
          color: AppPalette.current.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _BatchesPreview extends StatelessWidget {
  const _BatchesPreview();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PreviewHeader('Your batches', Icons.folder_shared_outlined),
      const SizedBox(height: 13),
      const _PreviewRow('Our flat', 'Rent · groceries · bills', '₹1,240 owed'),
      const SizedBox(height: 9),
      const _PreviewRow('Goa trip', 'Stay · food · travel', 'All square'),
      const Spacer(),
      _PreviewPill(label: '+ Create a batch', color: AppColors.purple),
    ],
  );
}

class _SplitPreview extends StatelessWidget {
  const _SplitPreview();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PreviewHeader('Add expense', Icons.call_split_rounded),
      const SizedBox(height: 13),
      Text(
        'Friday dinner',
        style: AppTypography.label.copyWith(
          color: AppPalette.current.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '₹1,200',
        style: AppTypography.headline.copyWith(
          color: AppPalette.current.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: const [
          _Avatar('Y'),
          _Avatar('A'),
          _Avatar('M'),
          _Avatar('R'),
          SizedBox(width: 9),
          Text('₹300 each'),
        ],
      ),
      const Spacer(),
      _PreviewPill(label: 'Split equally with 4', color: AppColors.pink),
    ],
  );
}

class _SettlePreview extends StatelessWidget {
  const _SettlePreview();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PreviewHeader('Settle up', Icons.done_all_rounded),
      const SizedBox(height: 13),
      Text(
        'The fewest moves to square up',
        style: AppTypography.label.copyWith(
          color: AppPalette.current.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 11),
      const _Transfer('Aisha', 'Rohan', '₹340'),
      const SizedBox(height: 8),
      const _Transfer('Maya', 'Rohan', '₹180'),
      const Spacer(),
      _PreviewPill(label: '2 transfers · all square', color: AppColors.lime),
    ],
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.title, this.subtitle, this.trailing);
  final String title, subtitle, trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppPalette.current.card,
      border: Border.all(color: AppPalette.current.ink, width: 1.2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.group_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppPalette.current.grey,
                ),
              ),
            ],
          ),
        ),
        Text(
          trailing,
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: AppPalette.current.ink, width: 1.3),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      label,
      style: AppTypography.label.copyWith(
        color: AppPalette.current.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.initial);
  final String initial;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    width: 27,
    height: 27,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.purple,
      shape: BoxShape.circle,
      border: Border.all(color: AppPalette.current.ink),
    ),
    child: Text(
      initial,
      style: AppTypography.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Transfer extends StatelessWidget {
  const _Transfer(this.from, this.to, this.amount);
  final String from, to, amount;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppPalette.current.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Text(
          from,
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 16),
        ),
        Text(
          to,
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          amount,
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
