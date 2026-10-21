import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/utils/party_mode.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/features/profile/profile_screen.dart';

import 'support/harness.dart';

/// The identity card of the profile.
///
/// The card carries a party mode (triple tap) and, next to it, the control
/// that opens the profile editor. Both listen for taps, so the editor has to
/// win the gesture arena without breaking the party mode.
void main() {
  setUp(() {
    if (PartyMode.instance.isOn) PartyMode.instance.toggle();
  });

  testWidgets('the edit control opens the profile editor', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tap to edit profile'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);

    await tester.tap(find.text('Tap to edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byType(PopCard), findsOneWidget);
  });

  testWidgets('the edit control does not trigger the party mode', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap to edit profile'));
    await tester.pumpAndSettle();

    expect(PartyMode.instance.isOn, isFalse);
  });

  testWidgets('the party mode still reacts to a triple tap on the card', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    // The name of the member sits outside the edit control.
    final name = find.text(AppSettings.instance.userName);
    expect(name, findsOneWidget);

    await tester.ensureVisible(name);
    await tester.pumpAndSettle();

    await tester.tap(name);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(name);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(name);
    await tester.pumpAndSettle();

    expect(PartyMode.instance.isOn, isTrue);

    // The party mode runs a ticker, so it is switched off again before the
    // test ends.
    PartyMode.instance.toggle();
    await tester.pumpAndSettle();
  });
}
