import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple persisted app settings (user identity, currency, toggles).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  String userName = 'You';
  String userEmail = 'you@example.com';
  String currencyCode = 'INR';
  bool amountHidden = false;
  bool notificationsOn = true;
  int cribsFilterIndex = 0;
  int cribsSortIndex = 0;

  String get currencySymbol => switch (currencyCode) {
    'INR' => '₹',
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currencyCode ',
  };

  static final Map<String, String> symbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
  };

  static String symbolForCode(String code) => symbols[code] ?? code;

  static const _key = 'paycal_app_settings_v1';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      userName = json['userName'] as String? ?? userName;
      userEmail = json['userEmail'] as String? ?? userEmail;
      currencyCode = json['currencyCode'] as String? ?? currencyCode;
      amountHidden = json['amountHidden'] as bool? ?? amountHidden;
      notificationsOn = json['notificationsOn'] as bool? ?? notificationsOn;
      cribsFilterIndex =
          json['cribsFilterIndex'] as int? ??
          json['batchesFilterIndex'] as int? ??
          cribsFilterIndex;
      cribsSortIndex =
          json['cribsSortIndex'] as int? ??
          json['batchesSortIndex'] as int? ??
          cribsSortIndex;
      // PayCal intentionally ships a single, carefully tuned light theme.
      AppPalette.current = AppPalette.light;
    } on FormatException {
      // Keep defaults when the blob is unusable.
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode({
        'userName': userName,
        'userEmail': userEmail,
        'currencyCode': currencyCode,
        'amountHidden': amountHidden,
        'notificationsOn': notificationsOn,
        'cribsFilterIndex': cribsFilterIndex,
        'cribsSortIndex': cribsSortIndex,
      }),
    );
  }

  void update({
    String? userName,
    String? userEmail,
    String? currencyCode,
    bool? amountHidden,
    bool? notificationsOn,
    int? cribsFilterIndex,
    int? cribsSortIndex,
  }) {
    if (userName != null) {
      this.userName = userName.trim().isEmpty ? this.userName : userName.trim();
    }
    if (userEmail != null) this.userEmail = userEmail;
    if (currencyCode != null) this.currencyCode = currencyCode;
    if (amountHidden != null) this.amountHidden = amountHidden;
    if (notificationsOn != null) this.notificationsOn = notificationsOn;
    if (cribsFilterIndex != null) {
      this.cribsFilterIndex = cribsFilterIndex;
    }
    if (cribsSortIndex != null) this.cribsSortIndex = cribsSortIndex;
    notifyListeners();
    unawaitedSave();
  }

  Future<void> clearIdentity() async {
    userName = 'You';
    userEmail = '';
    await save();
    notifyListeners();
  }

  Future<void> unawaitedSave() => save();
}
