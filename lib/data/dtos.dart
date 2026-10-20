import 'package:paycal/data/models.dart';

/// Transport-only mappings. A future API client can use these JSON shapes
/// without leaking backend concerns into UI or the financial ledger.
class ExpenseDto {
  const ExpenseDto(this.value);
  final Expense value;

  Map<String, Object?> toJson() => {
    'id': value.id,
    'cribId': value.cribId,
    'description': value.description,
    'totalMinor': value.totalMinor,
    'currency': value.currency,
    'payerId': value.payerId,
    'createdById': value.createdById,
    'shares': value.shares,
    'date': value.date.toUtc().toIso8601String(),
    'category': value.category,
    'disputed': value.disputed,
    'unpaid': value.unpaid,
    'version': value.version,
  };

  static Expense fromJson(Map<String, Object?> json) => Expense(
    id: json['id']! as String,
    cribId: json['cribId']! as String,
    description: json['description']! as String,
    totalMinor: json['totalMinor']! as int,
    currency: json['currency']! as String,
    payerId: json['payerId']! as String,
    createdById: json['createdById'] as String?,
    shares: (json['shares']! as Map<Object?, Object?>).map(
      (key, value) => MapEntry(key! as String, value! as int),
    ),
    date: DateTime.parse(json['date']! as String).toLocal(),
    category: json['category']! as String,
    disputed: json['disputed'] as bool? ?? false,
    unpaid: json['unpaid'] as bool? ?? false,
    version: json['version'] as int? ?? 0,
  );
}

class SettlementDto {
  const SettlementDto(this.value);
  final Settlement value;

  Map<String, Object?> toJson() => {
    'id': value.id,
    'cribId': value.cribId,
    'currency': value.currency,
    'fromMemberId': value.fromMemberId,
    'toMemberId': value.toMemberId,
    'amountMinor': value.amountMinor,
    'status': value.status.name,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'idempotencyKey': value.idempotencyKey,
    'version': value.version,
  };

  static Settlement fromJson(Map<String, Object?> json) => Settlement(
    id: json['id']! as String,
    cribId: json['cribId']! as String,
    currency: json['currency']! as String,
    fromMemberId: json['fromMemberId']! as String,
    toMemberId: json['toMemberId']! as String,
    amountMinor: json['amountMinor']! as int,
    status: SettlementStatus.values.byName(json['status']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
    idempotencyKey: json['idempotencyKey'] as String?,
    version: json['version'] as int? ?? 0,
  );
}

/// An invitation travels as its opaque token. The crib id is context, never
/// a credential.
class InvitationDto {
  const InvitationDto(this.value);
  final Invitation value;

  Map<String, Object?> toJson() => {
    'token': value.token,
    'cribId': value.cribId,
    'createdById': value.createdById,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'expiresAt': value.expiresAt.toUtc().toIso8601String(),
    'revoked': value.revoked,
    'acceptedById': value.acceptedById,
  };

  static Invitation fromJson(Map<String, Object?> json) => Invitation(
    id: json['token']! as String,
    cribId: json['cribId']! as String,
    createdById: json['createdById']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
    expiresAt: DateTime.parse(json['expiresAt']! as String).toLocal(),
    revoked: json['revoked'] as bool? ?? false,
    acceptedById: json['acceptedById'] as String?,
  );
}
