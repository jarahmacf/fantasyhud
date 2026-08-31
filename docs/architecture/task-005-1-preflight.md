# Task 005.1 preflight

Recorded on 2026-08-31 before editing from a clean working tree.

## Baseline and delivery state

- Baseline: `4d6de10c8b87252da5c9b215e5e8ca8cd1e1b0f4`
- Task 005 migration: `20260831060048_core_fantasy_data_architecture.sql`
- Supabase project: `fantasyhud-development` (`ihcswiiakqqhokrhcmko`)
- Supabase migration history showed Task 005 applied at `2026-08-31 06:00:48 UTC`.
- Vercel Production was Ready on baseline `4d6de10` at `fantasyhud-bh1enrm3y-jdm17.vercel.app`.
- GitHub Actions run `33363671505` completed successfully; both `quality` and `database` passed.

The Task 005 source migration is deployed history. It must remain byte-for-byte unchanged, so both corrections require one new additive migration.

## Hosted schema audit

The deployed removal constraint was:

```sql
check (removed_at is null or removed_at >= first_seen_at)
```

That permits an association to be marked removed after its first observation but before its last observation. The corrected invariant is:

```sql
removed_at is null or removed_at >= last_seen_at
```

The deployed grants gave `service_role` direct `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on all four Task 005 provider-data tables:

- `provider_season_states`
- `leagues`
- `fantasy_account_leagues`
- `sync_runs`

Task 005.1 revokes those direct privileges. Future provider-data writes must cross a reviewed, narrowly scoped `SECURITY DEFINER` RPC after server-side identity and reachability validation.

## Hosted row counts

| Table                     | Rows |
| ------------------------- | ---: |
| `provider_season_states`  |    0 |
| `leagues`                 |    0 |
| `fantasy_account_leagues` |    0 |
| `sync_runs`               |    0 |

No provider import has occurred. `roster_players` and `league_standing_snapshots` do not exist and remain documentation-only future grains.

## Corrective boundary

The additive migration drops and recreates only the incorrect check constraint, then revokes direct provider-table CRUD from `service_role`. It does not rewrite timestamps, create an import RPC, change browser grants or policies, create a public table, or begin Task 006.
