import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';

/// Read-only lookups over the repository cache.
///
/// These helpers only read. Every membership change goes through the crib
/// repository, never through a lookup like this.
class MemberDirectory {
  const MemberDirectory._();

  static List<Crib> get _cribs =>
      PayCalRepositories.instance.cribs.cachedCribs;

  /// The member with [memberId] in any crib the app knows about.
  static Member? memberById(String memberId) {
    for (final crib in _cribs) {
      final member = crib.memberById(memberId);
      if (member != null) return member;
    }
    return null;
  }

  /// The display name of a member, or [fallback] when the member is unknown.
  static String nameFor(String memberId, {String fallback = 'Someone'}) =>
      memberById(memberId)?.name ?? fallback;

  /// The crib with [cribId], or null when it is not cached.
  static Crib? cribById(String cribId) {
    for (final crib in _cribs) {
      if (crib.id == cribId) return crib;
    }
    return null;
  }

  /// The cribs the signed-in member is an active member of.
  static List<Crib> activeCribsOf(String memberId) => [
    for (final crib in _cribs)
      if (crib.memberById(memberId)?.isActive ?? false) crib,
  ];
}
