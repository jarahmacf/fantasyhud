# Task 005 preflight

Checked on 2026-08-30 before creating the Task 005 schema migration.

## Source baseline

- Repository: `jarahmacf/fantasyhud`
- Branch: `task/005-core-fantasy-data-architecture`
- Baseline: `c8ba16f0ac77b0476217dd32d569a481143cba9c`
- Baseline change: Task 004 canonical Sleeper account connection, merged through PR #4
- Working tree: clean before the task branch and migration were created

## Hosted prerequisite evidence

- GitHub Actions CI run `33360141344` completed successfully for the Task 004 head. Both `quality` and `database` jobs passed, including the authenticated browser suite and generated-type freshness check.
- Supabase project `fantasyhud-development` lists migration `20260831043609 connect_sleeper_account` in its main migration history.
- Vercel Production is Ready on merged commit `c8ba16f`.
- The Production canary signed in as the single internal-alpha app user and connected the public Sleeper username `jarahmacf`.
- Production displayed the canonical provider username `@jarahmacf`.
- A read-only hosted database query returned exactly one `fantasy_accounts` row, one `user_fantasy_accounts` row, and one primary link.
- Repeating sign-in and onboarding returned to the existing connection; the same query remained `1 / 1 / 1`.
- The hosted database had no public or `app_private` league, roster, player, draft, pick, matchup, transaction, ranking, market, or sync tables before Task 005.

These checks satisfy the Task 004 hosted gate. Task 005 may proceed, but its migration must remain local and branch-only until review and merge.

## Existing schema

| Table                          | Grain                                                           | Ownership and write boundary                                                         |
| ------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `public.profiles`              | One row per `auth.users` row                                    | The matching app user can read and update only presentation columns.                 |
| `public.fantasy_accounts`      | One shared provider identity per `(provider, external_user_id)` | Authenticated users can read only through a tracked link; browser writes are denied. |
| `public.user_fantasy_accounts` | One app-user association to one shared fantasy account          | Each user can read their own rows; browser writes are denied.                        |

The identity path that later fantasy data must preserve is:

```text
auth.users
→ user_fantasy_accounts
→ fantasy_accounts
→ future fantasy_account_leagues
→ future leagues
```

Shared resources never receive an app-user ownership column.

## Existing functions and service-only boundaries

- `app_private.set_updated_at()` is a fixed-search-path trigger function used by all three public identity tables. `PUBLIC`, `anon`, and `authenticated` cannot execute it.
- `app_private.create_profile_for_new_user()` is a fixed-search-path `SECURITY DEFINER` trigger function. It creates one bounded profile and is not browser-executable.
- `public.connect_sleeper_account(uuid, text, text, text, text, jsonb)` is the only public service-only RPC. It has a fixed `pg_catalog` search path, is executable only by `service_role` and `postgres`, and atomically reuses shared identity and link rows.
- No provider-import, league-import, synchronization, queue, cache, or analytics function exists.

Task 005 reuses only `app_private.set_updated_at()`. It does not add a service-only import function.

## Existing RLS paths

| Resource                | Authenticated read path                                                                      | Supporting index                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `profiles`              | `auth.uid() = profiles.id`                                                                   | Primary key on `profiles.id`                                           |
| `user_fantasy_accounts` | `auth.uid() = user_id`                                                                       | Unique `(user_id, fantasy_account_id)` constraint index                |
| `fantasy_accounts`      | `fantasy_accounts.id → user_fantasy_accounts.fantasy_account_id` plus `auth.uid() = user_id` | `user_fantasy_accounts_account_user_idx (fantasy_account_id, user_id)` |

Every current public table has RLS enabled. `anon` has no table privileges. `authenticated` has only the documented reads and the two profile presentation-column updates. `service_role` retains the identity-table privileges required by the connection RPC.

## Existing indexes and invariants

- `fantasy_accounts_provider_external_user_id_key` stores one canonical shared provider identity.
- `user_fantasy_accounts_user_account_key` prevents duplicate app-user links.
- `user_fantasy_accounts_account_user_idx` supports fantasy-account-to-user authorization.
- `user_fantasy_accounts_one_primary_per_user_idx` is a partial unique index allowing at most one primary link per app user.
- Provider IDs are text; usernames are mutable and noncanonical.
- `fantasy_accounts.last_synced_at` is null after identity connection and is reserved for a complete future portfolio synchronization.

## Compatibility requirements for Task 005

- Keep the existing account connection and all three identity-table policies unchanged.
- Continue using text for provider IDs.
- Reach shared league data only through `user_fantasy_accounts → fantasy_account_leagues`.
- Treat account-to-league discovery as an observation, not roster ownership.
- Preserve exact provider configuration in bounded JSONB while keeping independent derived league dimensions.
- Deny all browser mutations on new tables.
- Add indexes for every new RLS existence or join path.
- Add no provider request, import action, future child table, queue, cache, analytics table, or materialized view.
