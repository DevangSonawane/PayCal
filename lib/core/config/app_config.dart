class AppConfig {
  static const String appName = 'PayCal';
  static const int minimumAge = 18;
  static const String defaultCurrency = 'INR';

  /// Public Supabase connection values.
  ///
  /// The project URL and the *publishable* key are safe to ship in a client
  /// app: the publishable key only grants the `anon` role and every table is
  /// protected by row level security. They are baked in so that a plain
  /// `flutter run` talks to the real backend instead of silently falling back
  /// to the offline prototype.
  ///
  /// A build can still override them, for example:
  /// `flutter run --dart-define-from-file=.env.json`.
  ///
  /// Never put a service-role key in this app or in source control.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lymcqjdclcqrdmdamxna.supabase.co',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_DAGtAFWaC1Id7k01uhH5Ag_bBh9UXoJ',
  );

  static bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Firebase is opt-in at build time so development builds without the
  /// platform Firebase files keep working.
  static const bool firebasePushEnabled = bool.fromEnvironment(
    'FIREBASE_PUSH_ENABLED',
  );

  /// How long a shared invitation stays valid.
  ///
  /// Seven days is the product default for v1. The expiry is stored on the
  /// invitation itself, so changing this only affects newly created links.
  static const Duration invitationLifetime = Duration(days: 7);

  /// The custom scheme that carries invitation tokens.
  static const String inviteScheme = 'paycal';

  /// Redirect registered in Supabase Auth and handled by Android/iOS.
  static const String googleAuthRedirectUrl = 'paycal://auth/callback';

  /// Builds the link that is shared with an invitee.
  static String invitationLink(String token) => '$inviteScheme://invite/$token';
}
