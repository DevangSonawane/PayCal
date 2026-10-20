import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/data/supabase_auth_repository.dart';
import 'package:paycal/data/supabase_crib_repository.dart';
import 'package:paycal/data/supabase_expense_repository.dart';
import 'package:paycal/domain/financial_ledger.dart';
import 'package:paycal/domain/recurring_scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'dart:math';

/// Shared in-memory storage. It deliberately has no Flutter dependency and is
/// also the seam a future API/cache implementation will replace.
class InMemoryStore {
  InMemoryStore({
    required this.cribs,
    required this.expenses,
    required this.settlements,
    required this.activity,
    required this.currentUser,
    List<RecurringPayment>? schedules,
    List<Invitation>? invitations,
    List<RecurringOccurrence>? occurrences,
  }) : schedules = schedules ?? <RecurringPayment>[],
       invitations = invitations ?? <Invitation>[],
       occurrences = occurrences ?? <RecurringOccurrence>[];

  factory InMemoryStore.prototype() => InMemoryStore(
    cribs: MockData.cribs,
    expenses: MockData.expenses,
    settlements: MockData.settlements,
    activity: MockData.activity,
    currentUser: AuthUser(
      id: MockData.meId,
      name: MockData.me.name,
      email: 'you@example.com',
    ),
    schedules: MockData.recurringPayments,
  );

  final List<Crib> cribs;
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final List<ActivityEvent> activity;
  final List<Invitation> invitations;
  final List<RecurringPayment> schedules;
  final List<RecurringOccurrence> occurrences;
  AuthUser? currentUser;

  /// The clock the repositories use for "now".
  ///
  /// The moment a member leaves, the moment an invitation expires and the
  /// timestamps of the activity feed all come from here, so a test can pin
  /// them. The prototype still uses the device clock.
  DateTime Function() clock = DateTime.now;

  /// The current moment of the store.
  DateTime get now => clock();
}

class PayCalRepositories {
  PayCalRepositories._({
    required this.store,
    required this.auth,
    required this.cribs,
    required this.expenses,
    required this.settlements,
    required this.activity,
    required this.invitations,
    required this.recurring,
  });

  factory PayCalRepositories._inMemory(InMemoryStore store) =>
      PayCalRepositories._(
        store: store,
        auth: InMemoryAuthRepository(store),
        cribs: InMemoryCribRepository(store),
        expenses: InMemoryExpenseRepository(store),
        settlements: InMemorySettlementRepository(store),
        activity: InMemoryActivityRepository(store),
        invitations: InMemoryInvitationRepository(store),
        recurring: InMemoryRecurringPaymentRepository(store),
      );

  /// Builds a repository set around an explicit store. Tests use this to get
  /// an isolated world.
  factory PayCalRepositories.forStore(InMemoryStore store) =>
      PayCalRepositories._inMemory(store);

  factory PayCalRepositories.prototype() =>
      PayCalRepositories._inMemory(InMemoryStore.prototype());

  /// The production bundle.  The in-memory store stays empty solely to keep
  /// the existing test seam available; no production read or write uses it.
  factory PayCalRepositories.supabase(SupabaseClient client) {
    final emptyStore = InMemoryStore(
      cribs: <Crib>[],
      expenses: <Expense>[],
      settlements: <Settlement>[],
      activity: <ActivityEvent>[],
      currentUser: null,
    );
    return PayCalRepositories._(
      store: emptyStore,
      auth: SupabaseAuthRepository(client),
      cribs: SupabaseCribRepository(client),
      expenses: SupabaseExpenseRepository(client),
      // These repositories will be moved to their RPC-backed counterparts in
      // the next backend slice.  Keeping them empty is safer than presenting
      // prototype financial data to a real signed-in account.
      settlements: InMemorySettlementRepository(emptyStore),
      activity: InMemoryActivityRepository(emptyStore),
      invitations: InMemoryInvitationRepository(emptyStore),
      recurring: InMemoryRecurringPaymentRepository(emptyStore),
    );
  }

  static PayCalRepositories _instance = PayCalRepositories.prototype();

  /// The repository set the app talks to.
  // ignore: unnecessary_getters_setters
  static PayCalRepositories get instance => _instance;

  /// Swaps the repository set. Used by tests to run against an isolated
  /// in-memory store.
  static set instance(PayCalRepositories value) => _instance = value;

  /// Loads the remote account's cribs and their expenses after an auth
  /// transition. Widgets consume the repository caches synchronously.
  Future<void> hydrate() async {
    final cribsForUser = await cribs.list();
    await Future.wait([
      for (final crib in cribsForUser) expenses.list(cribId: crib.id),
    ]);
  }

  /// The id of the signed-in member. Empty when nobody is signed in.
  String get currentUserId => auth.currentUser?.id ?? '';

  final InMemoryStore store;
  final AuthRepository auth;
  final CribRepository cribs;
  final ExpenseRepository expenses;
  final SettlementRepository settlements;
  final ActivityRepository activity;
  final InvitationRepository invitations;
  final RecurringPaymentRepository recurring;
}

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._store);
  final InMemoryStore _store;
  @override
  AuthUser? get currentUser => _store.currentUser;

  @override
  Future<AuthUser?> restoreSession() async => currentUser;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@') || password.isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'A valid email and password are required.',
      );
    }
    final user = AuthUser(
      id: _store.currentUser?.id ?? 'me',
      name: _store.currentUser?.name ?? email.split('@').first,
      email: email.trim(),
    );
    _store.currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async => _store.currentUser = null;

  @override
  Future<void> deleteAccount() => signOut();

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => signIn(email: email, password: password);

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) => signIn(email: email, password: 'local-test-password');
}

class InMemoryCribRepository implements CribRepository {
  InMemoryCribRepository(this._store);
  final InMemoryStore _store;
  @override
  List<Crib> get cachedCribs => List.unmodifiable(
    _store.cribs.where((crib) => _memberCribIds(_store).contains(crib.id)),
  );

  @override
  Future<List<Crib>> list() async {
    _requireUser(_store);
    return cachedCribs;
  }

  @override
  Future<Crib> getById(String id) async {
    _requireUser(_store);
    return _memberCrib(_store, id);
  }

  @override
  Future<Crib> create(Crib crib) async {
    final actor = _requireUser(_store);
    if (_store.cribs.any((item) => item.id == crib.id)) {
      _conflict('Crib');
    }
    final owner = crib.ownerId ?? actor.id;
    if (owner != actor.id) {
      _unauthorized('Only the creator can own a new crib.');
    }
    final members = [
      Member(id: actor.id, name: actor.name, role: MemberRole.owner),
      for (final member in crib.members)
        if (member.id != actor.id)
          Member(id: member.id, name: member.name, role: MemberRole.member),
    ];
    final created = crib.copyWith(ownerId: owner, members: members);
    _store.cribs.add(created);
    _recordActivity(_store, 'crib_created', created, created.id);
    return created;
  }

  @override
  Future<Crib> update(Crib crib) async {
    final actor = _requireUser(_store);
    final index = _store.cribs.indexWhere((item) => item.id == crib.id);
    if (index < 0) {
      _notFound('Crib');
    }
    final existing = _store.cribs[index];
    if (existing.isDeleted) {
      _notFound('Crib');
    }
    _requireOwner(existing, actor.id);
    if (existing.version != crib.version) _conflict('Crib version');
    if (!_sameMembership(existing.members, crib.members)) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Membership changes go through addMember and removeMember.',
      );
    }
    final hasFinancialActivity =
        _store.expenses.any((e) => e.cribId == crib.id) ||
        _store.settlements.any((s) => s.cribId == crib.id);
    if (hasFinancialActivity && existing.currency != crib.currency) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Currency cannot change after financial activity exists.',
      );
    }
    final updated = crib.copyWith(
      ownerId: existing.ownerId,
      members: existing.members,
      version: existing.version + 1,
    );
    _store.cribs[index] = updated;
    _recordActivity(_store, 'crib_updated', updated, updated.id);
    return updated;
  }

  @override
  Future<void> delete(String id, {int? expectedVersion}) async {
    final actor = _requireUser(_store);
    final crib = _liveCrib(_store, id);
    _requireOwner(crib, actor.id);
    if (expectedVersion != null && expectedVersion != crib.version) {
      _conflict('Crib version');
    }
    // The crib keeps its row, so the expenses, the settlements and the
    // activity of it still point at something that exists. The members lose
    // access to it, the history stays complete.
    final index = _store.cribs.indexWhere((item) => item.id == crib.id);
    _store.cribs[index] = crib.copyWith(
      deletedAt: DateTime.now(),
      version: crib.version + 1,
    );
    _recordActivity(_store, 'crib_deleted', crib, id);
  }

  @override
  Future<Crib> addMember({
    required String cribId,
    required Member member,
  }) async {
    final actor = _requireUser(_store);
    final crib = _liveCrib(_store, cribId);
    _requireOwner(crib, actor.id);
    if (member.id == crib.ownerId) {
      _conflict('Member');
    }
    final existing = crib.memberById(member.id);
    if (existing != null && existing.isActive) {
      _conflict('Member');
    }
    final members = [
      for (final item in crib.members)
        if (item.id == member.id) item.reactivated() else item,
      if (existing == null)
        Member(id: member.id, name: member.name, role: MemberRole.member),
    ];
    final index = _store.cribs.indexWhere((item) => item.id == crib.id);
    final updated = crib.copyWith(members: members, version: crib.version + 1);
    _store.cribs[index] = updated;
    _recordActivity(_store, 'member_added', updated, member.id);
    return updated;
  }

  @override
  Future<Crib> removeMember({
    required String cribId,
    required String memberId,
  }) async {
    final actor = _requireUser(_store);
    final crib = _liveCrib(_store, cribId);
    _requireOwner(crib, actor.id);
    if (memberId == crib.ownerId) {
      _unauthorized('The crib owner cannot be removed.');
    }
    final member = crib.memberById(memberId);
    if (member == null) {
      _notFound('Member');
    }
    if (!member.isActive) {
      _conflict('Member removal');
    }
    final removedAt = _store.now;
    final members = [
      for (final item in crib.members)
        if (item.id == memberId)
          item.copyWith(isActive: false, leftAt: removedAt)
        else
          item,
    ];
    final index = _store.cribs.indexWhere((item) => item.id == crib.id);
    final updated = crib.copyWith(members: members, version: crib.version + 1);
    _store.cribs[index] = updated;
    // A schedule that is paid by the member who left is paused. It generates
    // nothing until the owner assigns an active member as the new payer. The
    // occurrences that were generated already stay in the ledger.
    final paused = _pauseSchedulesOf(_store, updated, memberId, removedAt);
    _recordActivity(_store, 'member_removed', updated, member.id);
    for (final scheduleId in paused) {
      _recordActivity(_store, 'recurring_paused', updated, scheduleId);
    }
    return updated;
  }

  bool _sameMembership(List<Member> a, List<Member> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].isActive != b[i].isActive) return false;
    }
    return true;
  }
}

class InMemoryExpenseRepository implements ExpenseRepository {
  InMemoryExpenseRepository(this._store);
  final InMemoryStore _store;
  @override
  List<Expense> get cachedExpenses => List.unmodifiable(
    _store.expenses.where(
      (expense) => _memberCribIds(_store).contains(expense.cribId),
    ),
  );

  @override
  Future<List<Expense>> list({required String cribId}) async {
    _requireUser(_store);
    _requireMemberCrib(_store, cribId);
    return List.unmodifiable(
      _store.expenses.where((item) => item.cribId == cribId),
    );
  }

  @override
  Future<Expense> getById(String id) async {
    _requireUser(_store);
    return _memberExpense(_store, id);
  }

  @override
  Future<Expense> create(Expense expense) async {
    final actor = _requireUser(_store);
    if (_store.expenses.any((item) => item.id == expense.id)) {
      _conflict('Expense');
    }
    _validate(expense);
    _requireActiveMember(_store, expense.cribId, actor.id);
    if (expense.payerId != actor.id) {
      _unauthorized('Only the payer may create this expense.');
    }
    _store.expenses.add(expense);
    _recordActivity(
      _store,
      'expense_created',
      _cribFor(_store, expense.cribId),
      expense.id,
    );
    return expense;
  }

  @override
  Future<Expense> update(Expense expense) async {
    final actor = _requireUser(_store);
    final index = _store.expenses.indexWhere((item) => item.id == expense.id);
    if (index < 0) {
      _notFound('Expense');
    }
    final existing = _store.expenses[index];
    if (existing.version != expense.version) {
      _conflict('Expense version');
    }
    if (!_canManageExpense(_store, existing, actor.id)) {
      _unauthorized(
        'Only the payer, the author or the crib owner may edit this expense.',
      );
    }
    if (existing.payerId != expense.payerId) {
      _unauthorized('The payer cannot be changed.');
    }
    if (existing.currency != expense.currency) {
      _unauthorized('The currency of an expense cannot be changed.');
    }
    final financialChanged =
        existing.totalMinor != expense.totalMinor ||
        existing.payerId != expense.payerId ||
        !FinancialLedger.sameShares(existing.shares, expense.shares);
    if (financialChanged) {
      _requireSettledHistoryAllows(existing.cribId);
      // A new charge may only involve active members.
      _validate(expense);
    } else {
      // A metadata-only edit keeps the participants of the expense, including
      // the ones that left in the meantime, so the history stays complete.
      _validateExisting(expense);
    }
    final updated = expense.copyWith(version: existing.version + 1);
    _store.expenses[index] = updated;
    _recordActivity(
      _store,
      'expense_updated',
      _cribFor(_store, expense.cribId),
      updated.id,
    );
    return updated;
  }

  @override
  Future<Expense> flagDispute(String id) async {
    final actor = _requireUser(_store);
    final index = _store.expenses.indexWhere((item) => item.id == id);
    if (index < 0) {
      _notFound('Expense');
    }
    final existing = _store.expenses[index];
    if (existing.disputed) return existing;
    _requireActiveMember(_store, existing.cribId, actor.id);
    final updated = existing.copyWith(
      disputed: true,
      version: existing.version + 1,
    );
    _store.expenses[index] = updated;
    _recordActivity(
      _store,
      'expense_disputed',
      _cribFor(_store, existing.cribId),
      existing.id,
    );
    return updated;
  }

  @override
  Future<void> delete(String id, {int? expectedVersion}) async {
    final actor = _requireUser(_store);
    final expense = _expense(id);
    if (!_canManageExpense(_store, expense, actor.id)) {
      _unauthorized(
        'Only the payer, the author or the crib owner may delete this expense.',
      );
    }
    if (expectedVersion != null && expectedVersion != expense.version) {
      _conflict('Expense version');
    }
    _requireSettledHistoryAllows(expense.cribId);
    _store.expenses.remove(expense);
    _recordActivity(
      _store,
      'expense_deleted',
      _cribFor(_store, expense.cribId),
      id,
    );
  }

  Expense _expense(String id) =>
      _store.expenses.where((item) => item.id == id).firstOrNull ??
      (_notFound('Expense'));

  /// Validates an expense that is about to be recorded. A member that left
  /// can never be charged again.
  void _validate(Expense expense) {
    final crib = _store.cribs
        .where((item) => item.id == expense.cribId)
        .firstOrNull;
    if (crib == null) {
      _notFound('Crib');
    }
    try {
      FinancialLedger.validateNewExpense(crib: crib, expense: expense);
    } on FinancialValidationException catch (error) {
      throw RepositoryException(RepositoryErrorCode.validation, error.message);
    }
  }

  /// Validates an expense that already exists. Members that left stay part of
  /// the history, so their expenses keep validating.
  void _validateExisting(Expense expense) {
    final crib = _store.cribs
        .where((item) => item.id == expense.cribId)
        .firstOrNull;
    if (crib == null) {
      _notFound('Crib');
    }
    try {
      FinancialLedger.validateExpense(crib: crib, expense: expense);
    } on FinancialValidationException catch (error) {
      throw RepositoryException(RepositoryErrorCode.validation, error.message);
    }
  }

  /// A confirmed transfer is part of the settled history of a crib. Editing
  /// an old expense underneath it would silently rewrite that history.
  void _requireSettledHistoryAllows(String cribId) {
    final settled = _store.settlements.any(
      (item) =>
          item.cribId == cribId &&
          (item.status == SettlementStatus.confirmed ||
              item.status == SettlementStatus.selfManaged),
    );
    if (settled) {
      throw const RepositoryException(
        RepositoryErrorCode.conflict,
        'This crib already has a settled transfer. Its history stays intact.',
      );
    }
  }
}

class InMemorySettlementRepository implements SettlementRepository {
  InMemorySettlementRepository(this._store);
  final InMemoryStore _store;
  @override
  List<Settlement> get cachedSettlements => List.unmodifiable(
    _store.settlements.where(
      (item) => _memberCribIds(_store).contains(item.cribId),
    ),
  );

  @override
  Future<List<Settlement>> list({required String cribId}) async {
    _requireUser(_store);
    _requireMemberCrib(_store, cribId);
    return List.unmodifiable(
      _store.settlements.where((item) => item.cribId == cribId),
    );
  }

  @override
  Future<Settlement> create(Settlement settlement) async {
    final actor = _requireUser(_store);
    if (settlement.fromMemberId != actor.id) {
      _unauthorized('Only the sender may create a settlement.');
    }
    if (settlement.status == SettlementStatus.confirmed) {
      _unauthorized(
        'Only the recipient may confirm a settlement. Ask them to confirm it.',
      );
    }
    if (settlement.status == SettlementStatus.cancelled) {
      _unauthorized('A cancelled settlement cannot be created.');
    }
    if (settlement.idempotencyKey != null) {
      final previous = _store.settlements
          .where(
            (item) =>
                item.cribId == settlement.cribId &&
                item.idempotencyKey == settlement.idempotencyKey &&
                item.fromMemberId == actor.id,
          )
          .firstOrNull;
      if (previous != null) {
        if (previous.amountMinor != settlement.amountMinor ||
            previous.toMemberId != settlement.toMemberId) {
          throw const RepositoryException(
            RepositoryErrorCode.conflict,
            'Idempotency key reused with a different payload.',
          );
        }
        return previous;
      }
    }
    if (_store.settlements.any((item) => item.id == settlement.id)) {
      _conflict('Settlement');
    }
    final crib = _store.cribs
        .where((item) => item.id == settlement.cribId)
        .firstOrNull;
    if (crib == null) {
      _notFound('Crib');
    }
    try {
      FinancialLedger.validateNewSettlement(crib: crib, settlement: settlement);
    } on FinancialValidationException catch (error) {
      throw RepositoryException(RepositoryErrorCode.validation, error.message);
    }
    _requireActiveMember(_store, settlement.cribId, actor.id);
    // The overpayment rule is about the debt of the sender to the recipient,
    // not about the net position of the sender in the crib. A member may
    // never pay off a debt they do not have with that person, and never pays
    // more than they owe to that person.
    final debt = FinancialLedger.pairwiseDebt(
      crib: crib,
      expenses: _store.expenses.where(
        (expense) => expense.cribId == settlement.cribId,
      ),
      settlements: _store.settlements.where(
        (item) => item.cribId == settlement.cribId,
      ),
      fromId: settlement.fromMemberId,
      toId: settlement.toMemberId,
    );
    if (settlement.amountMinor > debt) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Settlement exceeds the outstanding debt to the recipient.',
      );
    }
    _store.settlements.add(settlement);
    _recordActivity(_store, 'settlement_created', crib, settlement.id);
    return settlement;
  }

  @override
  Future<Settlement> updateStatus(
    String id,
    SettlementStatus status, {
    int? expectedVersion,
  }) async {
    final actor = _requireUser(_store);
    final index = _store.settlements.indexWhere((item) => item.id == id);
    if (index < 0) {
      _notFound('Settlement');
    }
    final current = _store.settlements[index];
    if (expectedVersion != null && expectedVersion != current.version) {
      _conflict('Settlement version');
    }
    if (current.status == SettlementStatus.confirmed ||
        current.status == SettlementStatus.selfManaged) {
      _conflict('Confirmed settlement');
    }
    final allowed =
        (current.status == SettlementStatus.pending &&
        ((status == SettlementStatus.confirmed &&
                actor.id == current.toMemberId) ||
            (status == SettlementStatus.cancelled &&
                actor.id == current.fromMemberId)));
    if (!allowed) _unauthorized('This settlement transition is not allowed.');
    final updated = current.copyWith(
      status: status,
      version: current.version + 1,
    );
    _store.settlements[index] = updated;
    _recordActivity(
      _store,
      'settlement_${status.name}',
      _cribFor(_store, current.cribId),
      current.id,
    );
    return updated;
  }
}

class InMemoryActivityRepository implements ActivityRepository {
  InMemoryActivityRepository(this._store);
  final InMemoryStore _store;
  @override
  List<ActivityEvent> get cachedEvents => List.unmodifiable(
    _store.activity.where(
      (event) => _memberCribIds(_store).contains(event.cribId),
    ),
  );

  @override
  Future<List<ActivityEvent>> list({String? cribName}) async {
    _requireUser(_store);
    final cribIds = _memberCribIds(_store);
    return List.unmodifiable(
      _store.activity.where(
        (item) =>
            cribIds.contains(item.cribId) &&
            (cribName == null || item.cribName == cribName),
      ),
    );
  }

  @override
  Future<void> record(ActivityEvent event) async {
    _requireUser(_store);
    if (!_memberCribIds(_store).contains(event.cribId)) {
      _unauthorized('Only a member of a crib can record its activity.');
    }
    _store.activity.insert(0, event);
  }
}

class InMemoryRecurringPaymentRepository implements RecurringPaymentRepository {
  InMemoryRecurringPaymentRepository(this._store);
  final InMemoryStore _store;

  @override
  List<RecurringPayment> get cachedSchedules =>
      List.unmodifiable(_store.schedules);

  @override
  List<RecurringOccurrence> get cachedOccurrences =>
      List.unmodifiable(_store.occurrences);

  @override
  Future<RecurringPayment> create(RecurringPayment schedule) async {
    final actor = _requireUser(_store);
    final crib = _cribFor(_store, schedule.cribId);
    _requireOwner(crib, actor.id);
    if (schedule.createdById != actor.id) {
      _unauthorized('Only the creator can set up a recurring transfer.');
    }
    if (schedule.timeZone.trim().isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'A timezone is required.',
      );
    }
    if (!RecurringScheduler.isKnownTimeZone(schedule.timeZone)) {
      throw RepositoryException(
        RepositoryErrorCode.validation,
        'Unknown timezone "${schedule.timeZone}".',
      );
    }
    // The payer of a schedule has to be an active member of the crib.
    final payerId = schedule.payerId ?? schedule.createdById;
    if (!_isActiveMember(crib, payerId)) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'The payer of a recurring transfer must be an active crib member.',
      );
    }
    if (_store.schedules.any((item) => item.id == schedule.id)) {
      _conflict('Recurring schedule');
    }
    final created = schedule.copyWith(payerId: payerId);
    _store.schedules.add(created);
    _recordActivity(_store, 'recurring_created', crib, created.id);
    return created;
  }

  @override
  Future<RecurringPayment> update(RecurringPayment schedule) async {
    final actor = _requireUser(_store);
    final index = _store.schedules.indexWhere((item) => item.id == schedule.id);
    if (index < 0) {
      _notFound('Recurring schedule');
    }
    final existing = _store.schedules[index];
    final crib = _cribFor(_store, existing.cribId);
    _requireOwner(crib, actor.id);
    if (!existing.active) {
      throw const RepositoryException(
        RepositoryErrorCode.conflict,
        'This recurring transfer was cancelled.',
      );
    }
    if (schedule.timeZone.trim().isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'A timezone is required.',
      );
    }
    if (!RecurringScheduler.isKnownTimeZone(schedule.timeZone)) {
      throw RepositoryException(
        RepositoryErrorCode.validation,
        'Unknown timezone "${schedule.timeZone}".',
      );
    }
    // The payer stays the member it is, and it has to be an active member.
    final payerId = schedule.payerId ?? existing.payerId;
    if (payerId != null && !_isActiveMember(crib, payerId)) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'The payer of a recurring transfer must be an active crib member.',
      );
    }
    final updated = schedule.copyWith(payerId: payerId);
    _store.schedules[index] = updated;
    _recordActivity(_store, 'recurring_updated', crib, schedule.id);
    return updated;
  }

  @override
  Future<void> cancel(String id) async {
    final actor = _requireUser(_store);
    final schedule =
        _store.schedules.where((item) => item.id == id).firstOrNull ??
        (_notFound('Recurring schedule'));
    final crib = _cribFor(_store, schedule.cribId);
    _requireOwner(crib, actor.id);
    final index = _store.schedules.indexWhere((item) => item.id == id);
    _store.schedules[index] = schedule.copyWith(active: false);
    _recordActivity(_store, 'recurring_cancelled', crib, schedule.id);
  }

  @override
  Future<RecurringPayment> assignPayer(String id, String payerId) async {
    final actor = _requireUser(_store);
    final schedule =
        _store.schedules.where((item) => item.id == id).firstOrNull ??
        (_notFound('Recurring schedule'));
    final crib = _cribFor(_store, schedule.cribId);
    _requireOwner(crib, actor.id);
    if (!schedule.active) {
      throw const RepositoryException(
        RepositoryErrorCode.conflict,
        'This recurring transfer was cancelled.',
      );
    }
    // Only an active member of the crib can pay the generated occurrences.
    if (!_isActiveMember(crib, payerId)) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Only an active crib member can pay a recurring transfer.',
      );
    }
    final wasPaused = schedule.isPaused;
    final index = _store.schedules.indexWhere((item) => item.id == id);
    final updated = schedule.copyWith(payerId: payerId);
    _store.schedules[index] = updated;
    _recordActivity(_store, 'recurring_payer_assigned', crib, schedule.id);
    if (wasPaused) {
      _recordActivity(_store, 'recurring_resumed', crib, schedule.id);
    }
    return updated;
  }

  /// Catches up every occurrence that is due at [now].
  ///
  /// Generation is on demand, not a background job: nothing runs while the
  /// app is closed. Each occurrence is keyed by schedule id plus due date, so
  /// running it twice never creates a second expense.
  @override
  Future<List<Expense>> generateDue({
    required String cribId,
    required DateTime now,
  }) async {
    final actor = _requireUser(_store);
    final crib = _cribFor(_store, cribId);
    _requireActiveMember(_store, cribId, actor.id);
    final generated = <Expense>[];
    final schedules = _store.schedules
        .where((item) => item.cribId == cribId && item.active)
        .toList();
    for (final schedule in schedules) {
      // A paused schedule has no payer, so it generates nothing. A schedule
      // whose payer is not an active member any more is skipped as well, so
      // a removed member is never charged again.
      final payerId = schedule.payerId;
      if (payerId == null) continue;
      if (!_isActiveMember(crib, payerId)) continue;
      // A pause never creates a backlog: the schedule continues at the due
      // date it was paused at.
      var due = schedule.resumeFrom ?? schedule.startDate;
      var guard = 0;
      while (guard++ < 5000) {
        final instant = RecurringScheduler.instantFor(
          localDate: due,
          timeZone: schedule.timeZone,
          hour: schedule.localHour,
          minute: schedule.localMinute,
        );
        if (instant.isAfter(now)) break;
        final key = RecurringScheduler.occurrenceKey(
          scheduleId: schedule.id,
          dueDate: due,
        );
        final alreadyGenerated = _store.occurrences
            .where((item) => item.idempotencyKey == key)
            .firstOrNull;
        if (alreadyGenerated == null) {
          final expenseId = RecurringScheduler.occurrenceExpenseId(
            scheduleId: schedule.id,
            dueDate: due,
          );
          final expense = Expense(
            id: expenseId,
            cribId: cribId,
            description:
                '${schedule.description} to ${_memberName(crib, schedule.recipientId)}',
            totalMinor: schedule.amountMinor,
            currency: schedule.currency,
            payerId: payerId,
            shares: {payerId: schedule.amountMinor},
            date: instant,
            category: schedule.category,
            createdById: payerId,
          );
          try {
            FinancialLedger.validateNewExpense(crib: crib, expense: expense);
          } on FinancialValidationException catch (error) {
            throw RepositoryException(
              RepositoryErrorCode.validation,
              error.message,
            );
          }
          _store.expenses.add(expense);
          _store.occurrences.add(
            RecurringOccurrence(
              idempotencyKey: key,
              scheduleId: schedule.id,
              dueDate: due,
              expenseId: expense.id,
              createdAt: _store.now,
            ),
          );
          generated.add(expense);
          _recordActivity(_store, 'recurring_generated', crib, expense.id);
        }
        due = RecurringScheduler.nextDueDate(
          current: due,
          frequency: schedule.frequency,
          anchorDay: schedule.anchorDay,
        );
      }
    }
    return List.unmodifiable(generated);
  }

  String _memberName(Crib crib, String memberId) =>
      crib.memberById(memberId)?.name ?? memberId;
}

class InMemoryInvitationRepository implements InvitationRepository {
  InMemoryInvitationRepository(this._store);
  final InMemoryStore _store;
  @override
  Future<Invitation> create({
    required String cribId,
    required String createdById,
    required DateTime expiresAt,
  }) async {
    final actor = _requireUser(_store);
    final crib = _cribFor(_store, cribId);
    _requireOwner(crib, actor.id);
    if (createdById != actor.id) {
      _unauthorized('Invitation creator does not match the signed-in user.');
    }
    if (!expiresAt.isAfter(_store.now)) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Invitation expiry must be in the future.',
      );
    }
    final invitation = Invitation(
      id: _token(),
      cribId: cribId,
      createdById: createdById,
      createdAt: _store.now,
      expiresAt: expiresAt,
    );
    _store.invitations.add(invitation);
    _recordActivity(_store, 'invitation_created', crib, invitation.id);
    return invitation;
  }

  @override
  Future<Invitation> getById(String id) async {
    _requireUser(_store);
    return _store.invitations.where((item) => item.id == id).firstOrNull ??
        (_notFound('Invitation'));
  }

  @override
  Future<List<Invitation>> list({String? cribId}) async {
    final actor = _requireUser(_store);
    if (cribId != null) {
      final crib = _cribFor(_store, cribId);
      _requireOwner(crib, actor.id);
      return List.unmodifiable(
        _store.invitations.where((item) => item.cribId == cribId),
      );
    }
    return List.unmodifiable(
      _store.invitations.where((item) => item.createdById == actor.id),
    );
  }

  @override
  Future<Invitation> validate(String token) async {
    final invitation = await getById(token);
    if (invitation.revoked) _unauthorized('This invitation has been revoked.');
    if (invitation.isExpiredAt(_store.now)) {
      _unauthorized('This invitation has expired.');
    }
    if (invitation.isAccepted) _conflict('Invitation acceptance');
    return invitation;
  }

  @override
  Future<Crib> accept(String token) async {
    final actor = _requireUser(_store);
    final invitation = await validate(token);
    final crib = _cribFor(_store, invitation.cribId);
    final member = crib.memberById(actor.id);
    if (member != null && member.isActive) _conflict('Invitation acceptance');
    final members = [
      for (final item in crib.members)
        if (item.id == actor.id) item.reactivated() else item,
      if (member == null)
        Member(id: actor.id, name: actor.name, role: MemberRole.member),
    ];
    final index = _store.cribs.indexWhere((item) => item.id == crib.id);
    final updated = crib.copyWith(members: members, version: crib.version + 1);
    _store.cribs[index] = updated;
    final inviteIndex = _store.invitations.indexWhere(
      (item) => item.id == token,
    );
    _store.invitations[inviteIndex] = invitation.copyWith(
      acceptedById: actor.id,
      acceptedAt: _store.now,
    );
    _recordActivity(_store, 'invitation_accepted', updated, token);
    return updated;
  }

  @override
  Future<void> revoke(String id) async {
    final actor = _requireUser(_store);
    final index = _store.invitations.indexWhere((item) => item.id == id);
    if (index < 0) {
      _notFound('Invitation');
    }
    final invitation = _store.invitations[index];
    final crib = _cribFor(_store, invitation.cribId);
    _requireOwner(crib, actor.id);
    _store.invitations[index] = invitation.copyWith(revoked: true);
    _recordActivity(_store, 'invitation_revoked', crib, invitation.id);
  }

  String _token() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

Never _notFound(String type) =>
    throw RepositoryException(RepositoryErrorCode.notFound, '$type not found.');

Never _conflict(String type) => throw RepositoryException(
  RepositoryErrorCode.conflict,
  '$type already exists.',
);

AuthUser _requireUser(InMemoryStore store) {
  final user = store.currentUser;
  if (user == null) {
    throw const RepositoryException(
      RepositoryErrorCode.unauthorized,
      'Sign in is required for this operation.',
    );
  }
  return user;
}

Crib _cribFor(InMemoryStore store, String cribId) =>
    store.cribs.where((crib) => crib.id == cribId).firstOrNull ??
    (_notFound('Crib'));

/// A crib that is not deleted.
///
/// A deleted crib keeps its row for the history, but it is gone for the
/// members: it cannot be changed, deleted again, or have its membership
/// touched.
Crib _liveCrib(InMemoryStore store, String cribId) {
  final crib = _cribFor(store, cribId);
  if (crib.isDeleted) {
    _notFound('Crib');
  }
  return crib;
}

/// Whether [memberId] is an active member of [crib].
bool _isActiveMember(Crib crib, String memberId) {
  final member = crib.memberById(memberId);
  return member != null && member.isActive;
}

/// Pauses the schedules of a crib that are paid by [memberId].
///
/// A schedule without a payer generates nothing, so the occurrences are not
/// charged to a member that left. The schedule continues at the first due
/// date after the pause, so the paused time does not create a backlog.
///
/// Returns the ids of the schedules that were paused.
List<String> _pauseSchedulesOf(
  InMemoryStore store,
  Crib crib,
  String memberId,
  DateTime now,
) {
  final paused = <String>[];
  for (var i = 0; i < store.schedules.length; i++) {
    final schedule = store.schedules[i];
    if (schedule.cribId != crib.id) continue;
    if (!schedule.active) continue;
    if (schedule.payerId != memberId) continue;
    DateTime resumeFrom;
    try {
      resumeFrom = RecurringScheduler.nextDueDateAfter(
        schedule: schedule,
        now: now,
      );
    } on RecurrenceException {
      // The recurrence rule cannot be resolved, so the schedule is paused
      // without a resume point and has to be looked at by the owner.
      resumeFrom = schedule.startDate;
    }
    store.schedules[i] = schedule.copyWith(
      payerId: null,
      resumeFrom: resumeFrom,
    );
    paused.add(schedule.id);
  }
  return paused;
}

/// The ids of the cribs the signed-in member belongs to.
///
/// A member that was removed keeps read access to the cribs they were in, so
/// their own history stays visible. The signed-out case returns nothing.
Set<String> _memberCribIds(InMemoryStore store) {
  final user = store.currentUser;
  if (user == null) return <String>{};
  return store.cribs
      .where(
        (crib) =>
            !crib.isDeleted &&
            crib.members.any((member) => member.id == user.id),
      )
      .map((crib) => crib.id)
      .toSet();
}

/// A crib of the signed-in member. A crib of somebody else is not found, so
/// the ids of other people cannot be probed.
Crib _memberCrib(InMemoryStore store, String cribId) =>
    store.cribs
        .where(
          (crib) =>
              crib.id == cribId &&
              !crib.isDeleted &&
              crib.members.any((member) => member.id == store.currentUser?.id),
        )
        .firstOrNull ??
    (_notFound('Crib'));

/// Checks that the signed-in member belongs to a crib.
void _requireMemberCrib(InMemoryStore store, String cribId) {
  _memberCrib(store, cribId);
}

/// An expense of a crib of the signed-in member.
Expense _memberExpense(InMemoryStore store, String id) {
  final expense = store.expenses.where((item) => item.id == id).firstOrNull;
  if (expense == null) _notFound('Expense');
  _requireMemberCrib(store, expense.cribId);
  return expense;
}

/// The member that owns a crib.
///
/// The owner id is the source of truth. The fallback to the first member with
/// the owner role only covers a crib whose owner id is missing, which the
/// repository cannot produce.
String? _ownerIdOf(Crib crib) =>
    crib.ownerId ??
    crib.members.where((member) => member.isAdmin).firstOrNull?.id;

void _requireOwner(Crib crib, String actorId) {
  final ownerId = _ownerIdOf(crib);
  if (ownerId == null || ownerId != actorId) {
    _unauthorized('Only the crib owner can perform this action.');
  }
}

/// Whether the actor may change an expense.
///
/// The payer and the author may always change their own expense. The Crib
/// Owner may change any expense of their own crib, because the owner manages
/// the whole crib.
bool _canManageExpense(InMemoryStore store, Expense expense, String actorId) {
  if (expense.payerId == actorId || expense.authorId == actorId) return true;
  return _ownerIdOf(_cribFor(store, expense.cribId)) == actorId;
}

void _requireActiveMember(InMemoryStore store, String cribId, String memberId) {
  final member = _cribFor(
    store,
    cribId,
  ).members.where((item) => item.id == memberId).firstOrNull;
  if (member == null || !member.isActive) {
    _unauthorized('An active crib membership is required.');
  }
}

Never _unauthorized(String message) =>
    throw RepositoryException(RepositoryErrorCode.unauthorized, message);

void _recordActivity(
  InMemoryStore store,
  String action,
  Crib crib,
  String targetId,
) {
  final actor = store.currentUser;
  final now = store.now;
  store.activity.insert(
    0,
    ActivityEvent(
      title: action.replaceAll('_', ' '),
      subtitle: crib.name,
      time: now.toIso8601String(),
      cribName: crib.name,
      actorId: actor?.id,
      targetId: targetId,
      cribId: crib.id,
      action: action,
      occurredAt: now,
    ),
  );
}
