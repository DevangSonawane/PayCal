import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

void main() {
  Future<Invitation> inviteFor(TestHarness world) =>
      world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

  test('a signed out member cannot accept an invitation', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    world.store.currentUser = null;

    await expectLater(
      world.repositories.invitations.accept(invitation.token),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('an unknown token is not an invitation', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.invitations.accept('not-a-real-token'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.notFound,
        ),
      ),
    );
  });

  test('a crib id alone never grants membership', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.invitations.accept('c1'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.notFound,
        ),
      ),
    );
    final crib = await world.repositories.cribs.getById('c1');
    expect(crib.memberById('a'), isNotNull);
    expect(crib.memberById('a')!.isActive, isTrue);
  });

  test('a revoked invitation cannot be accepted', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    await world.repositories.invitations.revoke(invitation.id);
    world.store.currentUser = testUser('newcomer');

    await expectLater(
      world.repositories.invitations.accept(invitation.token),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('an expired invitation cannot be accepted', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    final index = world.store.invitations.indexWhere(
      (item) => item.id == invitation.id,
    );
    world.store.invitations[index] = Invitation(
      id: invitation.id,
      cribId: invitation.cribId,
      createdById: invitation.createdById,
      createdAt: invitation.createdAt,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    world.store.currentUser = testUser('newcomer');

    await expectLater(
      world.repositories.invitations.accept(invitation.token),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('an invitation cannot be created with an expiry in the past', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.validation,
        ),
      ),
    );
  });

  test('accepting an invitation adds the member to the crib', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    world.store.currentUser = testUser('newcomer');

    final crib = await world.repositories.invitations.accept(invitation.token);

    expect(crib.memberById('newcomer'), isNotNull);
    expect(crib.memberById('newcomer')!.isActive, isTrue);
    expect(crib.memberById('newcomer')!.role, MemberRole.member);
    expect(
      world.store.invitations.single.acceptedById,
      'newcomer',
    );
  });

  test('the same invitation cannot be accepted twice', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    world.store.currentUser = testUser('newcomer');
    await world.repositories.invitations.accept(invitation.token);

    await expectLater(
      world.repositories.invitations.accept(invitation.token),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('an existing member cannot accept an invitation again', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.invitations.accept(invitation.token),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('only the owner can create and revoke invitations', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'a',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );

    world.store.currentUser = testUser('me');
    final invitation = await inviteFor(world);
    world.store.currentUser = testUser('a');
    await expectLater(
      world.repositories.invitations.revoke(invitation.id),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('the token is opaque and is not the crib id', () async {
    final world = TestHarness();
    final invitation = await inviteFor(world);

    expect(invitation.token, isNot('c1'));
    expect(invitation.token.length, greaterThanOrEqualTo(32));
    expect(invitation.token, isNot(invitation.token.toLowerCase()));
  });
}
