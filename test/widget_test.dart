import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paycal/app/paycal_app.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/domain/balance_engine.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  test('equal split assigns remainder to payer', () {
    final shares = BalanceEngine.equalSplit(
      totalMinor: 1000,
      memberIds: const ['a', 'b', 'c'],
      payerId: 'a',
    );
    expect(shares.values.reduce((a, b) => a + b), 1000);
    expect(shares['a'], 334);
  });

  testWidgets('app boots to splash', (tester) async {
    await tester.pumpWidget(const PayCalApp());
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });
}
