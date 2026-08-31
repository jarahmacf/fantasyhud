# Account identity

FANTASY HUD keeps application users and fantasy-platform identities separate.

```text
App User A ─┐
            ├── Shared Fantasy Account X
App User B ─┘
```

An app user authenticates through `auth.users` and owns one `public.profiles` row. A fantasy account is a shared external identity in `public.fantasy_accounts`. `public.user_fantasy_accounts` associates the two without duplicating provider data.

## Canonical identity

The stable external key is:

```text
provider + external_user_id
```

Provider names are lowercase conservative identifiers. External user IDs are nonblank strings. A username is stored both as received and normalized for lookup, but it is mutable, reusable, and never unique or canonical.

Provider metadata must be a JSON object. No placeholder, `unverified:`, demo, or inferred fantasy account is created.

## Associations

Each app user can link a given fantasy account once. Two app users may link the same shared fantasy account. A partial unique index allows at most one `is_primary = true` association per app user.

Association labels are optional presentation data. Browser sessions cannot create, update, or delete associations, including preference fields. The Task 004 authenticated Server Action resolves a submitted Sleeper username server-side, derives the canonical Sleeper user ID from the provider response, and invokes one service-only atomic RPC to create or reuse the account and link.

The connection records a user's choice to track a public identity. Sleeper does not authenticate account ownership through this API, so the product does not describe the connection as verified or authenticated. Resolving identity does not set `last_synced_at` and does not imply portfolio synchronization.

## Browser and RLS boundary

- A user may select only their own profile and update only its display name or avatar URL.
- A user may select only their own association rows.
- A user may select a fantasy account only through an indexed association belonging to the current `auth.uid()`.
- `anon` receives no table privileges.
- `authenticated` receives only the required select privileges and profile presentation-column updates.
- Browser roles cannot insert, update, or delete fantasy accounts or associations.
- One server-only admin client uses a hosted Supabase secret key only after signed app-user claims are validated. Its application use is limited to the Sleeper connection RPC.

RLS is authorization; UUID obscurity and public provider data are not.

## Profile lifecycle

An `AFTER INSERT` trigger on `auth.users` creates the profile. It copies only trimmed, bounded `display_name` and `avatar_url` metadata, stores unsafe or blank values as null, and uses `ON CONFLICT DO NOTHING` so it never overwrites later edits. The migration idempotently backfills missing profiles. Auth-user deletion cascades to the profile.

All three tables share a private `updated_at` trigger. Internal trigger functions live in `app_private`, use fixed `pg_catalog` search paths, and are not executable by `PUBLIC`, `anon`, or `authenticated`.
