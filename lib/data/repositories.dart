import 'package:paycal/data/models.dart';

enum RepositoryErrorCode {
  validation,
  notFound,
  unauthorized,
  conflict,
  transient,
}

class RepositoryException implements Exception {
  const RepositoryException(this.code, this.message);
  final RepositoryErrorCode code;
  final String message;

  @override
  String toString() => 'RepositoryException($code): $message';
}

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Future<AuthUser?> restoreSession();
  Future<AuthUser> signIn({required String email, required String password});

  /// Starts the browser-based Google OAuth flow. The app resumes through the
  /// configured custom URL scheme and receives the session from Supabase.
  Future<void> signInWithGoogle();
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<void> resetPassword({required String email});

  /// Sends the account confirmation mail once more.
  Future<void> resendConfirmation(String email);

  Future<AuthUser> updateProfile({required String name, required String email});

  /// Sets a password for the signed-in member.
  ///
  /// A member who arrived through Google has no password yet. Setting one
  /// lets them sign in with their email address later.
  Future<void> setPassword(String password);

  /// Updates the display name of the signed-in member without touching the
  /// email address.
  Future<void> setDisplayName(String name);
}

/// Crib metadata and membership.
///
/// Every read is scoped to the signed-in member: a member only ever sees the
/// cribs they belong to. A member that was removed keeps read access to the
/// cribs they were in, so their own history stays visible, but loses every
/// write right.
///
/// Membership is never changed through [CribRepository.update]: owners add or
/// remove members with [addMember] and [removeMember] so every membership
/// change is authorised, versioned and recorded in the activity feed.
abstract interface class CribRepository {
  /// The cribs of the signed-in member. Empty when nobody is signed in.
  List<Crib> get cachedCribs;

  /// The cribs of the signed-in member. Sign in is required.
  Future<List<Crib>> list();

  /// A crib of the signed-in member. A crib of somebody else is not found.
  Future<Crib> getById(String id);

  Future<Crib> create(Crib crib);

  /// Updates name, currency and categories. The membership list and the owner
  /// are preserved. [Crib.version] carries the version the caller read.
  Future<Crib> update(Crib crib);

  /// Deletes the crib. The financial history of the crib is kept, so the
  /// expenses and settlements of the other members stay reachable. Owner
  /// only.
  Future<void> delete(String id, {int? expectedVersion});

  /// Adds a member. Owner only.
  Future<Crib> addMember({required String cribId, required Member member});

  /// Removes a member. The member stays in the crib history so earlier
  /// expenses and settlements keep validating. Owner only.
  Future<Crib> removeMember({required String cribId, required String memberId});

  /// Leaves the crib on the member's own initiative.
  ///
  /// The membership keeps its history, so the expenses and settlements of the
  /// past keep validating, but the member is never charged again. A schedule
  /// the member paid for is paused. The owner of a crib has to hand it over
  /// before they can leave it, so a crib never ends up without an owner.
  Future<void> leave(String id);

  /// Hands the crib over to another active member. Owner only.
  ///
  /// The new owner gets the owner rights and the old owner becomes a plain
  /// member. Every other member of the crib is untouched.
  Future<Crib> transferOwnership({
    required String cribId,
    required String newOwnerId,
  });
}

abstract interface class ExpenseRepository {
  /// The expenses of the cribs of the signed-in member. Empty when nobody is
  /// signed in.
  List<Expense> get cachedExpenses;

  /// The expenses of one crib. The signed-in member has to be a member of
  /// that crib.
  Future<List<Expense>> list({required String cribId});

  /// An expense of a crib of the signed-in member. An expense of somebody
  /// else's crib is not found.
  Future<Expense> getById(String id);

  /// Creates an expense. The signed-in member has to be an active member of
  /// the crib and has to be the payer. Every participant has to be an active
  /// member as well, so a member that left is never charged again.
  Future<Expense> create(Expense expense);

  /// Updates an expense. The creator, the payer and the Crib Owner may edit
  /// it, because the owner manages the whole crib.
  Future<Expense> update(Expense expense);

  /// Flags an expense as disputed. Any active member of the crib may do it.
  Future<Expense> flagDispute(String id);

  /// Deletes an expense. The creator, the payer and the Crib Owner may delete
  /// it.
  Future<void> delete(String id, {int? expectedVersion});
}

abstract interface class SettlementRepository {
  /// The settlements of the cribs of the signed-in member. Empty when nobody
  /// is signed in.
  List<Settlement> get cachedSettlements;

  /// The settlements of one crib. The signed-in member has to be a member of
  /// that crib.
  Future<List<Settlement>> list({required String cribId});

  /// Creates a pending or self-managed settlement. The sender is the signed-in
  /// member. A confirmed settlement can only be reached through
  /// [updateStatus] so the recipient is the one confirming it.
  ///
  /// The amount may not exceed the debt of the sender to the recipient, so a
  /// member never pays off a debt they do not have with that person.
  Future<Settlement> create(Settlement settlement);

  /// Moves a pending settlement to confirmed or cancelled.
  Future<Settlement> updateStatus(
    String id,
    SettlementStatus status, {
    int? expectedVersion,
  });
}

abstract interface class ActivityRepository {
  /// The activity of the cribs of the signed-in member. Empty when nobody is
  /// signed in.
  List<ActivityEvent> get cachedEvents;

  /// The activity of the cribs of the signed-in member, optionally narrowed
  /// down to one crib name.
  Future<List<ActivityEvent>> list({String? cribName});

  /// Records an activity event. The signed-in member has to be a member of
  /// the crib the event belongs to.
  Future<void> record(ActivityEvent event);
}

/// Invitations carry an opaque random token. A crib id is never a
/// credential: joining always goes through [accept] with the token.
abstract interface class InvitationRepository {
  Future<Invitation> create({
    required String cribId,
    required String createdById,
    required DateTime expiresAt,
  });

  /// The invitation for a token. Sign in is required, the token itself stays
  /// the only credential.
  Future<Invitation> getById(String id);

  /// Invitations the signed-in member may see.
  Future<List<Invitation>> list({String? cribId});

  /// Checks a token without joining. Revoked, expired and already accepted
  /// tokens are rejected.
  Future<Invitation> validate(String token);

  /// Joins the crib of a valid token. The signed-in member becomes an active
  /// member.
  Future<Crib> accept(String token);

  /// Revokes an invitation. Owner only. Accepting members stay in the crib.
  Future<void> revoke(String id);
}

/// Recurring schedules and their generated occurrences.
///
/// Generation is on demand: the app catches up missed runs when a crib is
/// opened. There is no background job in v1, so nothing is generated while the
/// app is closed.
///
/// A schedule is paid by one member at a time. When that member leaves the
/// crib the schedule is paused and generates nothing until the owner assigns
/// an active member as the new payer. A pause never creates a backlog of the
/// occurrences that were missed while it was paused.
abstract interface class RecurringPaymentRepository {
  List<RecurringPayment> get cachedSchedules;

  /// Occurrences that were already generated, used as the idempotency ledger.
  List<RecurringOccurrence> get cachedOccurrences;

  /// Creates a schedule. Owner only. The creator is the payer of the
  /// generated occurrences.
  Future<RecurringPayment> create(RecurringPayment schedule);

  /// Changes the details of a schedule. The occurrences that were generated
  /// already stay in the ledger. Owner only.
  Future<RecurringPayment> update(RecurringPayment schedule);

  /// Cancels a schedule. Only future occurrences stop.
  Future<void> cancel(String id);

  /// Assigns an active member as the payer of a schedule. A paused schedule
  /// resumes, an active schedule changes its payer for the occurrences that
  /// are still to come. Owner only.
  Future<RecurringPayment> assignPayer(String id, String payerId);

  /// Generates every occurrence that is due at [now] and was not generated
  /// before. Each occurrence is created at most once. A paused schedule
  /// generates nothing.
  Future<List<Expense>> generateDue({
    required String cribId,
    required DateTime now,
  });
}
