import 'package:flutter/material.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/onboarding/birthday_sheet.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/features/onboarding/onboarding_layout.dart';

class RoleInfo {
  const RoleInfo(this.id, this.title, this.support, this.icon, this.categories, this.defaultSize, this.batchHint);
  final String id;
  final String title;
  final String support;
  final IconData icon;
  final List<String> categories;
  final int defaultSize;
  final String batchHint;
}

const roles = [
  RoleInfo('student', 'Student', 'Hostel, PG, college trips', Icons.school_outlined, ['rent', 'food', 'travel', 'subscriptions', 'other'], 3, 'College house'),
  RoleInfo('flat', 'Sharing a flat', 'Roommates and monthly bills', Icons.apartment_outlined, ['rent', 'groceries', 'electricity', 'internet', 'cleaning', 'other'], 3, 'Our flat'),
  RoleInfo('couple', 'Couple', 'Everyday life together', Icons.favorite_outline, ['groceries', 'dining', 'rent', 'travel', 'subscriptions', 'other'], 2, 'Home'),
  RoleInfo('family', 'Family', 'Home and household costs', Icons.home_outlined, ['groceries', 'utilities', 'school', 'health', 'travel', 'other'], 4, 'Home'),
  RoleInfo('trip', 'Trip planner', 'Holidays with friends', Icons.flight_outlined, ['stay', 'transport', 'food', 'activities', 'other'], 4, 'Goa trip'),
  RoleInfo('team', 'Team or office', 'Lunches, gifts, events', Icons.work_outline, ['food', 'gifts', 'events', 'supplies', 'other'], 5, 'Office lunch'),
];

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingDraft draft = OnboardingDraft();
  bool loaded = false;
  int index = 0; // 0 gender, 1 birthday, 2 role, 3 splits, 4 household

  @override
  void initState() {
    super.initState();
    OnboardingDraft.load().then((d) {
      setState(() {
        draft = d;
        index = d.step.clamp(0, 3);
        loaded = true;
      });
    });
  }

  void _save() => draft..step = index..save();

  void _next() {
    if (index < 3) {
      setState(() => index++);
      _save();
    } else {
      _save();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateAccountScreen(draft: draft)));
    }
  }

  void _back() {
    if (index > 0) {
      setState(() => index--);
      _save();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator()));
    }
    switch (index) {
      case 0:
        return _gender();
      case 1:
        return _birthday();
      case 2:
        return _role();
      case 3:
      default:
        return _splits();
    }
  }

  Widget _gender() {
    const options = ['Woman', 'Man', 'Non-binary', 'Prefer not to say'];
    return OnboardingLayout(
      step: 0,
      question: 'How do you identify?',
      support: 'Helps us personalise your experience. It is never shown to others.',
      body: Column(
        children: options
            .map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OptionTile(title: o, selected: draft.gender == o, onTap: () => setState(() {
                    draft.gender = o;
                    _save();
                  })),
                ))
            .toList(),
      ),
      canContinue: draft.gender != null,
      onContinue: _next,
      onBack: _back,
      onSkip: () {
        setState(() => draft.gender = 'Prefer not to say');
        _next();
      },
    );
  }

  Widget _birthday() {
    return OnboardingLayout(
      step: 1,
      question: 'When is your birthday?',
      support: 'We use this to confirm your age. It is never shown to others.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Text(
                draft.birthDate == null ? 'Select your birthday' : '${draft.birthDate!.day}/${draft.birthDate!.month}/${draft.birthDate!.year}',
                style: AppTypography.bodyLarge.copyWith(color: draft.birthDate == null ? AppColors.textTertiary : AppColors.textPrimary),
              ),
            ),
          ),
          if (_underAge()) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You need to be at least ${AppConfig.minimumAge} to use ${AppConfig.appName}.',
              style: AppTypography.body.copyWith(color: AppColors.oweText),
            ),
          ],
        ],
      ),
      canContinue: draft.birthDate != null && !_underAge(),
      onContinue: _next,
      onBack: _back,
    );
  }

  bool _underAge() {
    final b = draft.birthDate;
    if (b == null) return false;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) age--;
    return age < AppConfig.minimumAge;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final fallback = DateTime(now.year - 22, 1, 1);
    final initial = draft.birthDate ?? fallback;
    final picked = await showBirthdaySheet(context: context, initial: initial, maxDate: now);
    if (picked != null) setState(() => draft.birthDate = picked);
    _save();
  }

  Widget _role() {
    return OnboardingLayout(
      step: 2,
      question: 'What brings you here?',
      support: 'Pick the one that fits best. You can add more groups later.',
      body: Column(
        children: roles
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OptionTile(
                    title: r.title,
                    support: r.support,
                    leading: Icon(r.icon, color: AppColors.textSecondary),
                    selected: draft.role == r.id,
                    onTap: () {
                      setState(() {
                        draft.role = r.id;
                        draft.splitTypes = List.of(r.categories);
                        draft.householdSize = r.defaultSize;
                      });
                      _save();
                    },
                  ),
                ))
            .toList(),
      ),
      canContinue: draft.role != null,
      onContinue: _next,
      onBack: _back,
    );
  }

  Widget _splits() {
    final role = roles.firstWhere((r) => r.id == draft.role, orElse: () => roles[1]);
    return OnboardingLayout(
      step: 3,
      question: 'What will you split?',
      support: 'Pick at least one. This sets up your first batch.',
      body: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: role.categories.map((c) {
          final sel = draft.splitTypes.contains(c);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (sel) {
                  draft.splitTypes.remove(c);
                } else {
                  draft.splitTypes.add(c);
                }
              });
              _save();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: sel ? AppColors.surface : AppColors.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: sel ? AppColors.textPrimary : AppColors.border, width: sel ? 1.5 : 1),
              ),
              child: Text(c, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
            ),
          );
        }).toList(),
      ),
      canContinue: draft.splitTypes.isNotEmpty,
      onContinue: _next,
      onBack: _back,
    );
  }
}
