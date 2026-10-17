import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/segmented_control.dart';
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
    final role = roles.firstWhere((r) => r.id == widget.draft.role, orElse: () => roles[1]);
    _name = TextEditingController(text: role.batchHint);
    _cats = List.of(widget.draft.splitTypes.isEmpty ? role.categories : widget.draft.splitTypes);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _continue() {
    if (_tab == 0 && (Validators.batchName(_name.text) != null || _cats.isEmpty)) {
      if (Validators.batchName(_name.text) != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your batch a name.')));
        return;
      }
      if (_cats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one category.')));
        return;
      }
    }
    widget.draft.clear();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, leading: const BackButton(color: AppColors.textPrimary)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set up your first batch', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              SegmentedControl(tabs: const ['Create a batch', 'Join with a link'], selected: _tab, onSelect: (i) => setState(() => _tab = i)),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: SingleChildScrollView(child: _tab == 0 ? _create() : _join()),
              ),
              PrimaryButton(label: _tab == 0 ? 'Create batch' : 'Request to join', onPressed: _continue),
              const SizedBox(height: AppSpacing.lg),
            ],
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
        const SizedBox(height: AppSpacing.lg),
        Text('Currency', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: currencies
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _currency = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _currency == c ? AppColors.surface : AppColors.bg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _currency == c ? AppColors.textPrimary : AppColors.border),
                      ),
                      child: Text(c, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Everyone in this batch uses this currency. You can change it later; amounts will not be converted.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Categories', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _cats
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _cats.remove(c)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _join() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(label: 'Invite link or code', hint: 'Paste your invite link', controller: _code),
        const SizedBox(height: AppSpacing.sm),
        Text('New members need admin approval before they can join.', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
