class AppConfig {
  static const String appName = 'PayCal';
  static const int minimumAge = 18;
  static const String defaultCurrency = 'INR';

  /// How long a shared invitation stays valid.
  ///
  /// Seven days is the product default for v1. The expiry is stored on the
  /// invitation itself, so changing this only affects newly created links.
  static const Duration invitationLifetime = Duration(days: 7);

  /// The custom scheme that carries invitation tokens.
  static const String inviteScheme = 'paycal';

  /// Builds the link that is shared with an invitee.
  static String invitationLink(String token) => '$inviteScheme://invite/$token';
}
