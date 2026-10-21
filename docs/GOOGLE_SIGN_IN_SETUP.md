# Google Sign-In setup

The app is ready to launch Google OAuth with the redirect URL
`paycal://auth/callback`.

## What is already done

- The Supabase project `lymcqjdclcqrdmdamxna` has the Google provider enabled
  with the OAuth client id
  `963650637878-12lulnojldje498mg6fe91svl9n37ncu.apps.googleusercontent.com`.
  The client secret lives only in the Supabase project settings.
- `paycal://auth/callback` is on the Supabase **Redirect URLs** allow list.
- The Android manifest (`android/app/src/main/AndroidManifest.xml`) and the iOS
  `Info.plist` both register the `paycal` URL scheme, so the browser hands the
  session back to the app.
- The project URL and the publishable key are compiled into
  `lib/core/config/app_config.dart`, so a plain `flutter run` already talks to
  the live backend. `--dart-define-from-file=.env.json` still overrides them.
- `supabase_flutter` picks the OAuth callback out of the deep link on its own
  (`SupabaseAuth.initialize()` listens on the `AppLinks` singleton), so the app
  does not have to call `getSessionFromUrl` itself.

The Google flow was verified end to end: `GET /auth/v1/authorize?provider=google`
returns a `302` to `accounts.google.com` with the configured client id and the
`paycal://auth/callback` redirect.

## Adding a Google OAuth client of your own

1. In Google Cloud Console, create a **Web application** OAuth client.
2. Add `https://lymcqjdclcqrdmdamxna.supabase.co/auth/v1/callback` as its
   authorized redirect URI.
3. In Supabase Dashboard, go to **Authentication → Providers → Google**;
   enable it and enter that client ID and client secret.
4. In **Authentication → URL Configuration**, add
   `paycal://auth/callback` to Redirect URLs.

The client secret belongs only in Google Cloud and Supabase Dashboard; never
put it in `.env.json` or the Flutter app.

## Email confirmation

The project currently runs with `mailer_autoconfirm = true`, so a sign-up
returns a session right away and the app goes straight to the notification
setup. This is a stop gap: the built-in Supabase mailer allows only two
mails per hour, and raising that limit needs a custom SMTP server.

Once a custom SMTP server is configured, set `mailer_autoconfirm = false`
again and the app waits for the confirmation link (see
`lib/features/auth/verify_email_screen.dart`).

## Account deletion

`supabase/functions/delete-account` anonymises the profile, closes the
memberships and bans the account. GoTrue removed the admin sign-out endpoint
that the function used to call, so the ban is what ends the sessions: every
refresh of a banned account is refused with `user_banned`.
