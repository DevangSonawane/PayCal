import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/press_scale.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/onboarding/birthday_sheet.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/features/onboarding/onboarding_layout.dart';

class RoleInfo {
  const RoleInfo(
    this.id,
    this.title,
    this.support,
    this.icon,
    this.categories,
    this.defaultSize,
    this.batchHint,
  );
  final String id;
  final String title;
  final String support;
  final IconData icon;
  final List<String> categories;
  final int defaultSize;
  final String batchHint;
}

const roles = [
  RoleInfo(
    'student',
    'Student',
    'Hostel, PG, college trips',
    Icons.school_outlined,
    ['rent', 'food', 'travel', 'subscriptions', 'other'],
    3,
    'College house',
  ),
  RoleInfo(
    'flat',
    'Sharing a flat',
    'Roommates and monthly bills',
    Icons.apartment_outlined,
    ['rent', 'groceries', 'electricity', 'internet', 'cleaning', 'other'],
    3,
    'Our flat',
  ),
  RoleInfo(
    'couple',
    'Couple',
    'Everyday life together',
    Icons.favorite_outline,
    ['groceries', 'dining', 'rent', 'travel', 'subscriptions', 'other'],
    2,
    'Home',
  ),
  RoleInfo(
    'family',
    'Family',
    'Home and household costs',
    Icons.home_outlined,
    ['groceries', 'utilities', 'school', 'health', 'travel', 'other'],
    4,
    'Home',
  ),
  RoleInfo(
    'trip',
    'Trip planner',
    'Holidays with friends',
    Icons.flight_outlined,
    ['stay', 'transport', 'food', 'activities', 'other'],
    4,
    'Goa trip',
  ),
  RoleInfo(
    'team',
    'Team or office',
    'Lunches, gifts, events',
    Icons.work_outline,
    ['food', 'gifts', 'events', 'supplies', 'other'],
    5,
    'Office lunch',
  ),
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

  static const _accents = [
    AppColors.pink,
    AppColors.purple,
    AppColors.indigo,
    AppColors.lime,
    AppColors.pink,
  ];
  static const _icons = [
    Icons.face_rounded,
    Icons.cake_outlined,
    Icons.rocket_launch_outlined,
    Icons.call_split_rounded,
    Icons.group_outlined,
  ];
  static const _stickers = [
    'just between us',
    'no presents required',
    'pick your vibe',
    'go on, pick a few',
    'the more the merrier',
  ];

  @override
  void initState() {
    super.initState();
    OnboardingDraft.load().then((d) {
      setState(() {
        draft = d;
        index = d.step.clamp(0, 4);
        loaded = true;
      });
    });
  }

  void _save() => draft
    ..step = index
    ..save();

  void _next() {
    if (index < 4) {
      setState(() => index++);
      _save();
    } else {
      _save();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreateAccountScreen(draft: draft)),
      );
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
      return Scaffold(
        backgroundColor: AppPalette.current.page,
        body: Center(child: WedgeLoader(size: 34)),
      );
    }
    switch (index) {
      case 0:
        return _gender();
      case 1:
        return _birthday();
      case 2:
        return _role();
      case 3:
        return _splits();
      case 4:
      default:
        return _household();
    }
  }

  OnboardingLayout _shell({
    required String question,
    required String support,
    required Widget body,
    required bool canContinue,
    required VoidCallback onContinue,
    VoidCallback? onBack,
    VoidCallback? onSkip,
  }) {
    return OnboardingLayout(
      step: index,
      question: question,
      support: support,
      body: body,
      canContinue: canContinue,
      onContinue: onContinue,
      onBack: onBack,
      onSkip: onSkip,
      accent: _accents[index],
      badgeIcon: _icons[index],
      sticker: _stickers[index],
    );
  }

  Widget _gender() {
    const options = ['Woman', 'Man', 'Non-binary', 'Prefer not to say'];
    return _shell(
      question: 'How do you identify?',
      support: 'Helps us personalise things. It never shows up on anyone else’s screen.',
      body: Column(
        children: options
            .map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OptionTile(
                  title: o,
                  selected: draft.gender == o,
                  onTap: () => setState(() {
                    draft.gender = o;
                    _save();
                  }),
                ),
              ),
            )
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
    final b = draft.birthDate;
    return _shell(
      question: 'When is your birthday?',
      support: 'Just a quick age check. It stays private — no candles, no surprises.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppPalette.current.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.current.ink, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b == null
                          ? 'Tap to pick your date'
                          : '${b.day}/${b.month}/${b.year}',
                      style: AppTypography.titleSmall.copyWith(
                        color: b == null
                            ? AppPalette.current.grey
                            : AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.cake_outlined,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/mascot/penny_pointing.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You need to be at least ${AppConfig.minimumAge} to use ${AppConfig.appName}.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.pink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
    final picked = await showBirthdaySheet(
      context: context,
      initial: initial,
      maxDate: now,
    );
    if (picked != null) setState(() => draft.birthDate = picked);
    _save();
  }

  Widget _role() {
    return _shell(
      question: 'What brings you here?',
      support: 'Pick whatever fits. You can start more groups later.',
      body: Column(
        children: roles
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OptionTile(
                  title: r.title,
                  support: r.support,
                  leading: Icon(r.icon, color: AppPalette.current.grey),
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
              ),
            )
            .toList(),
      ),
      canContinue: draft.role != null,
      onContinue: _next,
      onBack: _back,
    );
  }

  Widget _splits() {
    final role = roles.firstWhere(
      (r) => r.id == draft.role,
      orElse: () => roles[1],
    );
    return _shell(
      question: 'What will you split?',
      support: 'Pick at least one. It sets up your first batch.',
      body: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: role.categories.map((c) {
          final sel = draft.splitTypes.contains(c);
          return StickerPill(
            label: c,
            selected: sel,
            showCheck: true,
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
          );
        }).toList(),
      ),
      canContinue: draft.splitTypes.isNotEmpty,
      onContinue: _next,
      onBack: _back,
    );
  }

  Widget _household() {
    var count = draft.householdSize;
    if (count < 1) count = 1;
    if (count > 10) count = 10;
    const accents = [
      AppColors.lime,
      AppColors.pink,
      AppColors.purple,
      AppColors.indigo,
    ];
    return _shell(
      question: 'How many people split?',
      support:
          'Roommates, family, pets with expensive tastes — who is in the mix?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _roundBtn(
                icon: Icons.remove_rounded,
                bg: Colors.white,
                enabled: count > 1,
                onTap: () => _setCount(count - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.7, end: 1).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '$count',
                        key: ValueKey(count),
                        style: AppTypography.displayAmount.copyWith(
                          color: AppPalette.current.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'people',
                      style: AppTypography.caption.copyWith(
                        color: AppPalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _roundBtn(
                icon: Icons.add_rounded,
                bg: AppColors.lime,
                enabled: count < 10,
                onTap: () => _setCount(count + 1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  ),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(count),
                children: [
                  SizedBox(
                    width: 28.0 * (count - 1) + 40,
                    height: 40,
                    child: Stack(
                      children: [
                        for (var i = 0; i < count; i++)
                          Positioned(
                            left: i * 28.0,
                            top: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accents[i % accents.length],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppPalette.current.ink,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 20,
                                color:
                                    accents[i % accents.length] ==
                                        AppColors.lime
                                    ? AppColors.ink
                                    : Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _vibe(count),
                    style: AppTypography.caption.copyWith(
                      color: AppPalette.current.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      canContinue: true,
      onContinue: _next,
      onBack: _back,
    );
  }

  String _vibe(int n) => switch (n) {
    1 => 'solo act — respect.',
    2 => 'a duo with a shared destiny.',
    3 || 4 => 'a proper crew',
    5 || 6 => 'things are getting social',
    _ => 'chaos (the good kind)',
  };

  void _setCount(int n) {
    if (n < 1 || n > 10) return;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() => draft.householdSize = n);
    _save();
  }

  Widget _roundBtn({
    required IconData icon,
    required Color bg,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: enabled ? bg : AppPalette.current.chip,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? AppColors.ink : AppPalette.current.hairline,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 26,
            color: enabled ? AppColors.ink : AppPalette.current.grey,
          ),
        ),
      ),
    );
  }
}
