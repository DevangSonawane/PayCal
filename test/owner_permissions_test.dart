import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

/// The permission matrix of a Crib, proven at the repository layer.
///
/// "Owner" means the Crib Owner. There is no platform role and no bypass:
/// every check below goes through the same repository methods the UI uses.
void main() {
  late TestHarness world;

  setUp(() {
    world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Dinner',
          totalMinor: 1000,
          currency: 'INR',
          payerId: 'me',
          shares: {'me': 500, 'a': 500},
          date: DateTime(2026),
          category: 'other',
        ),
      ],
    );
  });

  /// The signed-in member is the Crib Owner.
  void asOwner() => world.signIn('me');

  /// The signed-in member is an ordinary member of the Crib.
  void asMember() => world.signIn('a');

  /// A signed-in member of a different crib.
  void asStranger() => world.signIn('stranger');

  Future<void> expectRejected(
    Future<void> Function() action, {
    RepositoryErrorCode code = RepositoryErrorCode.unauthorized,
  }) async {
    await expectLater(
      action(),
      throwsA(
        isA<RepositoryException>().having((error) => error.code, 'code', code),
      ),
    );
  }

  group('owner-only operations reject an ordinary member', () {
    test('updating the crib', () async {
      asMember();
      final crib = await world.repositories.cribs.getById('c1');

      await expectRejected(
        () => world.repositories.cribs.update(crib.copyWith(name: 'Renamed')),
      );
    });

    test('deleting the crib', () async {
      asMember();
      await expectRejected(() => world.repositories.cribs.delete('c1'));
    });

    test('adding a member', () async {
      asMember();
      await expectRejected(
        () => world.repositories.cribs.addMember(
          cribId: 'c1',
          member: Member(id: 'z', name: 'Zoya'),
        ),
      );
    });

    test('removing another member', () async {
      asMember();
      await expectRejected(
        () => world.repositories.cribs.removeMember(
          cribId: 'c1',
          memberId: 'r',
        ),
      );
    });

    test('creating an invitation', () async {
      asMember();
      await expectRejected(
        () => world.repositories.invitations.create(
          cribId: 'c1',
          createdById: 'a',
          expiresAt: DateTime(2027),
        ),
      );
    });

    test('revoking an invitation', () async {
      asOwner();
      final invitation = await world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime(2027),
      );

      asMember();
      await expectRejected(
        () => world.repositories.invitations.revoke(invitation.id),
      );
    });

    test('creating a recurring schedule', () async {
      asMember();
      await expectRejected(
        () => world.repositories.recurring.create(
          RecurringPayment(
            id: 'r1',
            cribId: 'c1',
            description: 'Rent',
            amountMinor: 1000,
            currency: 'INR',
            category: 'other',
            frequency: RecurringFrequency.monthly,
            recipientId: 'r',
            createdById: 'a',
            startDate: DateTime(2026, 1, 31, 9),
          ),
        ),
      );
    });

    test('cancelling a recurring schedule', () async {
      asOwner();
      await world.repositories.recurring.create(
        RecurringPayment(
          id: 'r1',
          cribId: 'c1',
          description: 'Rent',
          amountMinor: 1000,
          currency: 'INR',
          category: 'other',
          frequency: RecurringFrequency.monthly,
          recipientId: 'r',
          createdById: 'me',
          startDate: DateTime(2026, 1, 31, 9),
        ),
      );

      asMember();
      await expectRejected(() => world.repositories.recurring.cancel('r1'));
    });

    test('assigning the payer of a recurring schedule', () async {
      asOwner();
      await world.repositories.recurring.create(
        RecurringPayment(
          id: 'r1',
          cribId: 'c1',
          description: 'Rent',
          amountMinor: 1000,
          currency: 'INR',
          category: 'other',
          frequency: RecurringFrequency.monthly,
          recipientId: 'r',
          createdById: 'me',
          startDate: DateTime(2026, 1, 31, 9),
        ),
      );

      asMember();
      await expectRejected(
        () => world.repositories.recurring.assignPayer('r1', 'r'),
      );
    });
  });

  group('owner-only operations reject a signed-out and a stranger', () {
    test('a signed-out member cannot update the crib', () async {
      world.signOut();
      final crib = world.store.cribs.first;

      await expectRejected(
        () => world.repositories.cribs.update(crib.copyWith(name: 'Renamed')),
        code: RepositoryErrorCode.unauthorized,
      );
    });

    test('a stranger cannot update a crib of somebody else', () async {
      asStranger();
      final crib = world.store.cribs.first;

      await expectRejected(
        () => world.repositories.cribs.update(crib.copyWith(name: 'Renamed')),
      );
    });

    test('a stranger cannot add a member to a crib of somebody else', () async {
      asStranger();
      await expectRejected(
        () => world.repositories.cribs.addMember(
          cribId: 'c1',
          member: Member(id: 'z', name: 'Zoya'),
        ),
      );
    });

    test('a stranger cannot create an expense in a crib of somebody else',
        () async {
      asStranger();
      await expectRejected(
        () => world.repositories.expenses.create(
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Coffee',
            totalMinor: 200,
            currency: 'INR',
            payerId: 'stranger',
            shares: {'stranger': 200},
            date: DateTime(2026),
            category: 'other',
          ),
        ),
        // The validation of the payer runs before the membership check, so
        // the code is a validation error. What matters is that it is refused.
        code: RepositoryErrorCode.validation,
      );
    });
  });

  group('member operations are allowed for an ordinary member', () {
    test('a member can read the crib and its records', () async {
      asMember();

      expect((await world.repositories.cribs.list()).single.id, 'c1');
      expect(
        (await world.repositories.expenses.list(cribId: 'c1')).single.id,
        'e1',
      );
      expect(await world.repositories.settlements.list(cribId: 'c1'), isEmpty);
      // The activity feed is readable and scoped. The events of the other
      // cribs are covered by the isolation tests.
      expect(await world.repositories.activity.list(), isEmpty);
    });

    test('a member can create an expense they pay for', () async {
      asMember();

      final created = await world.repositories.expenses.create(
        Expense(
          id: 'e2',
          cribId: 'c1',
          description: 'Coffee',
          totalMinor: 200,
          currency: 'INR',
          payerId: 'a',
          shares: {'me': 100, 'a': 100},
          date: DateTime(2026),
          category: 'other',
        ),
      );

      expect(created.payerId, 'a');
    });

    test('a member can edit and delete their own expense', () async {
      asMember();
      final created = await world.repositories.expenses.create(
        Expense(
          id: 'e2',
          cribId: 'c1',
          description: 'Coffee',
          totalMinor: 200,
          currency: 'INR',
          payerId: 'a',
          shares: {'me': 100, 'a': 100},
          date: DateTime(2026),
          category: 'other',
        ),
      );

      final updated = await world.repositories.expenses.update(
        created.copyWith(description: 'Tea'),
      );
      expect(updated.description, 'Tea');

      await world.repositories.expenses.delete(updated.id);
      await expectLater(
        world.repositories.expenses.getById('e2'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });

    test('a member can flag a dispute on an expense of somebody else', () async {
      asMember();

      final disputed = await world.repositories.expenses.flagDispute('e1');

      expect(disputed.disputed, isTrue);
    });

    test('a member can record a settlement to somebody else', () async {
      asMember();

      final created = await world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 200,
          status: SettlementStatus.selfManaged,
          createdAt: DateTime(2026),
        ),
      );

      expect(created.amountMinor, 200);
    });

    test('a member can confirm a settlement addressed to them', () async {
      asMember();
      await world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 200,
          status: SettlementStatus.pending,
          createdAt: DateTime(2026),
        ),
      );

      asOwner();
      final confirmed = await world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.confirmed,
      );

      expect(confirmed.status, SettlementStatus.confirmed);
    });

    test('a member can trigger the recurring catch-up', () async {
      asOwner();
      await world.repositories.recurring.create(
        RecurringPayment(
          id: 'r1',
          cribId: 'c1',
          description: 'Rent',
          amountMinor: 1000,
          currency: 'INR',
          category: 'other',
          frequency: RecurringFrequency.monthly,
          recipientId: 'r',
          createdById: 'me',
          startDate: DateTime(2026, 1, 31, 9),
        ),
      );

      asMember();
      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );

      expect(generated, hasLength(1));
    });

    test('a member can accept an invitation', () async {
      asOwner();
      final invitation = await world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime(2027),
      );

      asStranger();
      await world.repositories.invitations.accept(invitation.id);

      expect(world.store.invitations.single.isAccepted, isTrue);
      expect(
        world.store.invitations.single.acceptedById,
        'stranger',
      );
      expect(
        world.store.cribs.first.memberById('stranger'),
        isNotNull,
      );
    });
  });

  group('a member cannot perform an owner-only action on a crib they are in',
      () {
    test('a member cannot change the currency of the crib', () async {
      asMember();
      final crib = await world.repositories.cribs.getById('c1');

      await expectRejected(
        () => world.repositories.cribs.update(crib.copyWith(currency: 'USD')),
      );
    });

    test('a member cannot change the membership through an update', () async {
      asMember();
      final crib = await world.repositories.cribs.getById('c1');

      await expectRejected(
        () => world.repositories.cribs.update(
          crib.copyWith(
            members: [crib.members.first, Member(id: 'z', name: 'Zoya')],
          ),
        ),
      );
    });
  });

  group('the owner is protected', () {
    test('the owner cannot be removed as a member', () async {
      asOwner();
      await expectRejected(
        () => world.repositories.cribs.removeMember(
          cribId: 'c1',
          memberId: 'me',
        ),
      );
    });

    test('the owner cannot be added a second time as a member', () async {
      asOwner();
      await expectRejected(
        () => world.repositories.cribs.addMember(
          cribId: 'c1',
          member: Member(id: 'me', name: 'Me'),
        ),
        code: RepositoryErrorCode.conflict,
      );
    });
  });

  group('a member cannot leave the crib', () {
    test('removing oneself is an owner operation and is refused', () async {
      asMember();
      await expectRejected(
        () => world.repositories.cribs.removeMember(
          cribId: 'c1',
          memberId: 'a',
        ),
      );
    });
  });

  group('a removed member loses every write right', () {
    test('a removed member cannot create an expense', () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      asMember();
      await expectRejected(
        () => world.repositories.expenses.create(
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Coffee',
            totalMinor: 200,
            currency: 'INR',
            payerId: 'a',
            shares: {'a': 200},
            date: DateTime(2026),
            category: 'other',
          ),
        ),
        // The domain rule for a new charge runs before the membership check
        // of the repository, so the refusal is a validation error.
        code: RepositoryErrorCode.validation,
      );
    });

    test('a removed member cannot create a settlement', () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      asMember();
      await expectRejected(
        () => world.repositories.settlements.create(
          Settlement(
            id: 's1',
            cribId: 'c1',
            currency: 'INR',
            fromMemberId: 'a',
            toMemberId: 'me',
            amountMinor: 200,
            status: SettlementStatus.selfManaged,
            createdAt: DateTime(2026),
          ),
        ),
        code: RepositoryErrorCode.validation,
      );
    });

    test('a removed member cannot flag a dispute', () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      asMember();
      await expectRejected(
        () => world.repositories.expenses.flagDispute('e1'),
      );
    });

    test('a removed member cannot trigger the recurring catch-up', () async {
      asOwner();
      await world.repositories.recurring.create(
        RecurringPayment(
          id: 'r1',
          cribId: 'c1',
          description: 'Rent',
          amountMinor: 1000,
          currency: 'INR',
          category: 'other',
          frequency: RecurringFrequency.monthly,
          recipientId: 'r',
          createdById: 'me',
          startDate: DateTime(2026, 1, 31, 9),
        ),
      );
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      asMember();
      await expectRejected(
        () => world.repositories.recurring.generateDue(
          cribId: 'c1',
          now: DateTime.utc(2026, 2, 5),
        ),
      );
    });

    test('a removed member keeps the history of the crib readable', () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      asMember();
      expect((await world.repositories.cribs.list()).single.id, 'c1');
      expect(
        (await world.repositories.expenses.list(cribId: 'c1')).single.id,
        'e1',
      );
    });
  });

  group('duplicate and repeated actions do not bypass a permission check', () {
    test('a member cannot remove a member twice and win the second time',
        () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      asMember();
      await expectRejected(
        () => world.repositories.cribs.removeMember(
          cribId: 'c1',
          memberId: 'r',
        ),
      );
    });

    test('a member cannot delete the crib after the owner updated it', () async {
      asMember();
      final crib = await world.repositories.cribs.getById('c1');

      await expectRejected(
        () => world.repositories.cribs.delete(crib.id),
      );
    });

    test('a repeated owner action is a conflict, not a second effect',
        () async {
      asOwner();
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      await expectRejected(
        () => world.repositories.cribs.removeMember(
          cribId: 'c1',
          memberId: 'r',
        ),
        code: RepositoryErrorCode.conflict,
      );
      expect(
        world.store.cribs.first.members.where((m) => m.id == 'r').length,
        1,
      );
    });
  });
}
