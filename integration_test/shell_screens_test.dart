import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_theme.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/shell/main_shell.dart';

/// The four tabs of the shell, on a real device.
///
/// The shell is the screen a user spends the most time in, so it is the one
/// that matters for the visual check. A layout that overflows throws, and the
/// test framework catches it, so `takeException` is the overflow check.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSettings.instance.load();
  });

  testWidgets('the four tabs of the shell render without an overflow',
      (tester) async {
    PayCalRepositories.instance = PayCalRepositories.forStore(
      InMemoryStore(
        cribs: [
          Crib(
            id: 'c1',
            name: 'Our flat',
            currency: 'INR',
            ownerId: 'me',
            members: [
              Member(id: 'me', name: 'Me', role: MemberRole.owner),
              Member(id: 'a', name: 'Asha'),
              Member(id: 'r', name: 'Ravi'),
            ],
            categories: const ['groceries', 'other'],
          ),
        ],
        expenses: [
          Expense(
            id: 'e1',
            cribId: 'c1',
            description: 'Weekly groceries',
            totalMinor: 125000,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 62500, 'a': 62500},
            date: DateTime(2026),
            category: 'groceries',
            createdById: 'me',
          ),
        ],
        settlements: [],
        activity: [],
        currentUser: AuthUser(id: 'me', name: 'Me', email: 'me@test.com'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const MainShell()),
    );
    await tester.pump(const Duration(milliseconds: 800));

    // --- Home --------------------------------------------------------
    // The balance of the crib is right: me paid 125.00 and carried 62.50 of
    // it, so me is owed 62.50.
    expect(find.text('You are owed:'), findsOneWidget);
    expect(find.text('₹625.00'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // --- Cribs -------------------------------------------------------
    await _tap(tester, find.text('Cribs'));
    expect(find.text('Our flat'), findsWidgets);
    expect(tester.takeException(), isNull);

    // --- Activity ----------------------------------------------------
    await _tap(tester, find.text('Activity'));
    expect(tester.takeException(), isNull);

    // --- Profile -----------------------------------------------------
    await _tap(tester, find.text('Profile'));
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // And back to the home tab.
    await _tap(tester, find.text('Home'));
    expect(find.text('You are owed:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}
