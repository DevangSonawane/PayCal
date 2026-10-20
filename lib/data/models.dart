/// Roles in a crib.
///
/// v1 keeps this deliberately small: the crib creator is the owner and the
/// only admin. Every other member is a plain [MemberRole.member] and cannot
/// manage membership or invitations.
enum MemberRole { owner, member }

class Member {
  Member({
    required this.id,
    required this.name,
    bool isAdmin = false,
    MemberRole? role,
    this.isActive = true,
    this.leftAt,
  }) : role = role ?? (isAdmin ? MemberRole.owner : MemberRole.member);
  final String id;
  final String name;
  final MemberRole role;

  /// False once the owner removed the member. Removed members stay in the
  /// crib so historical expenses and settlements keep validating.
  final bool isActive;

  /// When the member was removed. Null while the member is still active.
  final DateTime? leftAt;
  bool get isAdmin => role == MemberRole.owner;
  bool get isRemoved => leftAt != null || !isActive;

  Member copyWith({
    MemberRole? role,
    bool? isActive,
    String? name,
    DateTime? leftAt,
  }) => Member(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    leftAt: leftAt ?? this.leftAt,
  );

  /// Re-adds a previously removed member. Membership history keeps the
  /// original removal marker in the activity feed.
  Member reactivated() => Member(
    id: id,
    name: name,
    role: role,
    isActive: true,
  );

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;
}

enum InvitationStatus { active, revoked, expired, accepted }

class Invitation {
  const Invitation({
    required this.id,
    required this.cribId,
    required this.createdById,
    required this.createdAt,
    required this.expiresAt,
    this.revoked = false,
    this.acceptedById,
    this.acceptedAt,
  });

  /// The opaque, random credential. It is also the record id so a crib id can
  /// never be used to join a crib.
  final String id;
  final String cribId;
  final String createdById;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool revoked;
  final String? acceptedById;
  final DateTime? acceptedAt;

  /// The secret that gets shared in invite links.
  String get token => id;

  bool get isAccepted => acceptedById != null;
  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  InvitationStatus statusAt(DateTime now) {
    if (revoked) return InvitationStatus.revoked;
    if (isAccepted) return InvitationStatus.accepted;
    if (isExpiredAt(now)) return InvitationStatus.expired;
    return InvitationStatus.active;
  }

  Invitation copyWith({
    bool? revoked,
    String? acceptedById,
    DateTime? acceptedAt,
  }) => Invitation(
    id: id,
    cribId: cribId,
    createdById: createdById,
    createdAt: createdAt,
    expiresAt: expiresAt,
    revoked: revoked ?? this.revoked,
    acceptedById: acceptedById ?? this.acceptedById,
    acceptedAt: acceptedAt ?? this.acceptedAt,
  );
}

class Expense {
  Expense({
    required this.id,
    required this.cribId,
    required this.description,
    required this.totalMinor,
    required this.currency,
    required this.payerId,
    required Map<String, int> shares,
    required this.date,
    required this.category,
    this.disputed = false,
    this.unpaid = false,
    this.createdById,
    this.version = 0,
  }) : shares = Map.unmodifiable(shares);
  final String id;
  final String cribId;
  final String description;
  final int totalMinor;
  final String currency;
  final String payerId;

  /// Who entered the expense. Falls back to the payer for records created
  /// before this field existed.
  final String? createdById;

  /// Immutable allocation in minor units. It is validated by [FinancialLedger]
  /// before an expense enters a crib.
  final Map<String, int> shares;
  final DateTime date;
  final String category;
  final bool disputed;
  final bool unpaid;
  final int version;

  /// The member allowed to edit or delete this expense.
  String get authorId => createdById ?? payerId;

  Expense copyWith({
    String? description,
    int? totalMinor,
    String? currency,
    String? payerId,
    Map<String, int>? shares,
    DateTime? date,
    String? category,
    bool? disputed,
    bool? unpaid,
    String? createdById,
    int? version,
  }) => Expense(
    id: id,
    cribId: cribId,
    description: description ?? this.description,
    totalMinor: totalMinor ?? this.totalMinor,
    currency: currency ?? this.currency,
    payerId: payerId ?? this.payerId,
    shares: shares ?? this.shares,
    date: date ?? this.date,
    category: category ?? this.category,
    disputed: disputed ?? this.disputed,
    unpaid: unpaid ?? this.unpaid,
    createdById: createdById ?? this.createdById,
    version: version ?? this.version,
  );
}

class Crib {
  Crib({
    required this.id,
    required this.name,
    required this.currency,
    required List<Member> members,
    required List<String> categories,
    this.ownerId,
    this.version = 0,
  }) : members = List.unmodifiable(members),
       categories = List.unmodifiable(categories);
  final String id;
  final String name;
  final String currency;
  final List<Member> members;
  final List<String> categories;
  final String? ownerId;
  final int version;

  bool isOwnedBy(String userId) => ownerId == userId;

  /// Members that can still take part in the crib.
  List<Member> get activeMembers =>
      members.where((member) => member.isActive).toList();

  Member? memberById(String memberId) {
    for (final member in members) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  Crib copyWith({
    String? name,
    String? currency,
    List<Member>? members,
    List<String>? categories,
    String? ownerId,
    int? version,
  }) => Crib(
    id: id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    members: members ?? this.members,
    categories: categories ?? this.categories,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
  );
}

/// A transfer that settles an existing crib balance. Settlements are not
/// expenses: recording one must never inflate a crib's tracked spending.
class Settlement {
  Settlement({
    required this.id,
    required this.cribId,
    required this.currency,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    this.idempotencyKey,
    this.version = 0,
  });

  final String id;
  final String cribId;
  final String currency;
  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final SettlementStatus status;
  final DateTime createdAt;
  final String? idempotencyKey;
  final int version;

  /// True once the settlement affects balances and can no longer be edited.
  bool get isFinal =>
      status == SettlementStatus.confirmed ||
      status == SettlementStatus.selfManaged;

  Settlement copyWith({SettlementStatus? status, int? version}) => Settlement(
    id: id,
    cribId: cribId,
    currency: currency,
    fromMemberId: fromMemberId,
    toMemberId: toMemberId,
    amountMinor: amountMinor,
    status: status ?? this.status,
    createdAt: createdAt,
    idempotencyKey: idempotencyKey,
    version: version ?? this.version,
  );
}

enum SettlementStatus { pending, confirmed, selfManaged, cancelled }

/// A schedule for a repeating transfer.
///
/// The schedule stores the wall-clock due date in its own [timeZone] so a
/// transfer keeps its local time across daylight-saving changes.
class RecurringPayment {
  RecurringPayment({
    required this.id,
    required this.cribId,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.category,
    required this.frequency,
    required this.recipientId,
    required this.createdById,
    required this.startDate,
    this.timeZone = 'UTC',
    int? localHour,
    int? localMinute,
    int? anchorDay,
    this.active = true,
    Object? payerId = _unset,
    this.resumeFrom,
  }) : localHour = localHour ?? startDate.hour,
       localMinute = localMinute ?? startDate.minute,
       anchorDay = anchorDay ?? startDate.day,
       payerId = identical(payerId, _unset)
           ? createdById
           : payerId as String?;

  /// A missing value that means "keep the current one" or "use the default".
  ///
  /// A plain `null` cannot be used for a nullable field, because `null` is
  /// also a value the caller may want to set.
  static const Object _unset = Object();

  final String id;
  final String cribId;
  final String description;
  final int amountMinor;
  final String currency;
  final String category;
  final RecurringFrequency frequency;
  final String recipientId;

  /// The member who set the schedule up.
  final String createdById;

  /// The member who currently pays the generated occurrences.
  ///
  /// A schedule starts out with its creator as the payer. When that member
  /// leaves the crib the schedule is paused, which clears the payer. A paused
  /// schedule generates nothing until an active member is assigned as the
  /// payer again.
  final String? payerId;

  /// The local due date the schedule continues from after a pause.
  ///
  /// A pause does not create a backlog: the schedule resumes at the first
  /// due date after the pause, so the occurrences that were missed while it
  /// was paused are never generated.
  final DateTime? resumeFrom;

  /// The first occurrence, expressed as a local wall-clock date in [timeZone].
  final DateTime startDate;

  /// IANA zone id (for example `Asia/Kolkata`) or a fixed offset such as
  /// `UTC+05:30`.
  final String timeZone;

  /// The scheduled local time of day.
  final int localHour;
  final int localMinute;

  /// The original day of month. A monthly schedule anchored on the 29th, 30th
  /// or 31st falls back to the last day of shorter months.
  final int anchorDay;

  /// False once the schedule was cancelled. Cancelling only stops future
  /// occurrences; generated expenses stay in the ledger.
  final bool active;

  /// True while the schedule waits for an active member to be assigned as
  /// its payer.
  bool get isPaused => payerId == null;

  RecurringPayment copyWith({
    bool? active,
    Object? payerId = _unset,
    Object? resumeFrom = _unset,
  }) => RecurringPayment(
    id: id,
    cribId: cribId,
    description: description,
    amountMinor: amountMinor,
    currency: currency,
    category: category,
    frequency: frequency,
    recipientId: recipientId,
    createdById: createdById,
    startDate: startDate,
    timeZone: timeZone,
    localHour: localHour,
    localMinute: localMinute,
    anchorDay: anchorDay,
    active: active ?? this.active,
    payerId: identical(payerId, _unset) ? this.payerId : payerId as String?,
    resumeFrom: identical(resumeFrom, _unset)
        ? this.resumeFrom
        : resumeFrom as DateTime?,
  );
}

enum RecurringFrequency { monthly, yearly }

/// Proof that a recurring occurrence was already generated. The
/// `schedule id + due date` pair is the idempotency key: it can only produce
/// one expense, no matter how often generation runs.
class RecurringOccurrence {
  const RecurringOccurrence({
    required this.idempotencyKey,
    required this.scheduleId,
    required this.dueDate,
    required this.expenseId,
    required this.createdAt,
  });

  final String idempotencyKey;
  final String scheduleId;
  final DateTime dueDate;
  final String expenseId;
  final DateTime createdAt;
}

class ActivityEvent {
  ActivityEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.cribName,
    this.actorId,
    this.targetId,
    this.cribId,
    this.action,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
  final String title;
  final String subtitle;
  final String time;
  final String cribName;
  final String? actorId;
  final String? targetId;
  final String? cribId;
  final String? action;
  final DateTime occurredAt;
}
