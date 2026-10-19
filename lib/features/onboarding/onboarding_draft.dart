import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDraft {
  OnboardingDraft({
    this.gender,
    this.birthDate,
    this.role,
    this.splitTypes = const [],
    this.householdSize = 3,
    this.step = 0,
  });

  String? gender;
  DateTime? birthDate;
  String? role;
  List<String> splitTypes;
  int householdSize;
  int step;

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'birthDate': birthDate?.toIso8601String(),
    'role': role,
    'splitTypes': splitTypes,
    'householdSize': householdSize,
    'step': step,
  };

  static OnboardingDraft fromJson(Map<String, dynamic> j) => OnboardingDraft(
    gender: j['gender'] as String?,
    birthDate: j['birthDate'] == null
        ? null
        : DateTime.tryParse(j['birthDate'] as String),
    role: j['role'] as String?,
    splitTypes: List<String>.from(j['splitTypes'] ?? const []),
    householdSize: (j['householdSize'] as int?) ?? 3,
    step: (j['step'] as int?) ?? 0,
  );

  static const _key = 'onboarding_draft';

  static Future<OnboardingDraft> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return OnboardingDraft();
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return OnboardingDraft();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
