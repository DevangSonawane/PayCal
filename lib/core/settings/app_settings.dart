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
  bool darkMode = false;
  int batchesFilterIndex = 0;
  int batchesSortIndex = 0;

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
      darkMode = json['darkMode'] as bool? ?? darkMode;
      batchesFilterIndex =
          json['batchesFilterIndex'] as int? ?? batchesFilterIndex;
      batchesSortIndex = json['batchesSortIndex'] as int? ?? batchesSortIndex;
      AppPalette.current = darkMode ? AppPalette.dark : AppPalette.light;
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
        'darkMode': darkMode,
        'batchesFilterIndex': batchesFilterIndex,
        'batchesSortIndex': batchesSortIndex,
      }),
    );
  }

  void update({
    String? userName,
    String? userEmail,
    String? currencyCode,
    bool? amountHidden,
    bool? notificationsOn,
    bool? darkMode,
    int? batchesFilterIndex,
    int? batchesSortIndex,
  }) {
    if (userName != null) {
      this.userName = userName.trim().isEmpty ? this.userName : userName.trim();
    }
    if (userEmail != null) this.userEmail = userEmail;
    if (currencyCode != null) this.currencyCode = currencyCode;
    if (amountHidden != null) this.amountHidden = amountHidden;
    if (notificationsOn != null) this.notificationsOn = notificationsOn;
    if (darkMode != null) {
      this.darkMode = darkMode;
      AppPalette.current = darkMode ? AppPalette.dark : AppPalette.light;
    }
    if (batchesFilterIndex != null) {
      this.batchesFilterIndex = batchesFilterIndex;
    }
    if (batchesSortIndex != null) this.batchesSortIndex = batchesSortIndex;
    notifyListeners();
    unawaitedSave();
  }

  Future<void> unawaitedSave() => save();
}
