# Supabase setup

The database migration and Flutter client dependency are now part of this
repository. Connect the CLI to the PayCal project, then deploy the migration:

```sh
supabase link --project-ref lymcqjdclcqrdmdamxna
supabase db push
```

Create a local `.env.json` from `.env.example.json`, fill it with the values
from the Supabase Connect panel, and run the app with:

```sh
flutter run --dart-define-from-file=.env.json
```

`SUPABASE_PUBLISHABLE_KEY` is safe to ship because database access is limited
by RLS. Never add a service-role or secret key to this file, source control, or
the Flutter app.

The first migration creates profiles from `auth.users`, cribs, memberships,
row-level security, and owner-protected RPCs. It deliberately does not enable
the unfinished mock repositories: the next backend slice replaces those
repositories with authenticated Supabase implementations for cribs and auth.
