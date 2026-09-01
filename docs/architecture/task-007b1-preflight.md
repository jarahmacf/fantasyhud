# Task 007B.1 preflight

Verified on 2026-09-01 before schema editing.

## Baseline and delivery state

- Exact baseline: `babf81d4fd5284ee3656a8cc1d71bf59150bdb09`
- Branch: `task/007b1-roster-domain-architecture`
- Open pull requests: none
- Baseline GitHub CI: run 33476952339, quality and database conclusion `success`
- Vercel Production: deployment `BwiYy1S4qbgy6f4jtjVECjRpegfV`, `Ready`, exact source `babf81d4fd5284ee3656a8cc1d71bf59150bdb09`
- Supabase project: `fantasyhud-development`, `main` Production branch

## Deployed migrations

```text
20260831003830
20260831030756
20260831043609
20260831060048
20260831070614
20260831081239
20260831235900
20260901055701
```

The Task 007A.1 response-headroom migration is deployed.

## Hosted data state

```text
leagues                              30
active fantasy-account associations 30
canonical players                12,225
active primary Sleeper mappings  12,225
successful player-catalog runs        1
running player-catalog runs            0
private player staging rows            0
```

`league_users`, `rosters`, `fantasy_account_rosters`, and `roster_players` are absent.

## Existing relationship paths

League authorization is:

```text
auth user
→ user_fantasy_accounts (fantasy_account_id, user_id index)
→ fantasy_account_leagues (league_id, fantasy_account_id index)
→ leagues
```

Canonical player identity is:

```text
players
→ player_external_ids(namespace, sport, exact external_id)
```

League discovery does not identify roster ownership. Task 007B.1 adds the explicit `fantasy_account_rosters` path without importing source data.

## Existing `sync_runs` boundary

- Grain: one tracked fantasy account, scope, and attempt.
- Supported scope before this task: `league_discovery` only.
- RLS: enabled; a user can read runs only through `user_fantasy_accounts`.
- Authenticated grant before this task: table-wide `SELECT`, including `triggered_by_user_id`.
- `service_role`: no direct `SELECT`, `INSERT`, `UPDATE`, or `DELETE`.
- Running league discovery: partial unique index `sync_runs_one_running_league_discovery_per_account_idx`.
- Application read sites: `src/lib/leagues/dashboard.server.ts`; both use explicit safe projections (`season, status` and `id`) and do not depend on the trigger UUID.

Task 007B.1 adds `roster_sync`, a scope-specific running uniqueness index, and safe column-level authenticated reads that exclude `triggered_by_user_id`.

## Absence and scope checks

No Sleeper league-user or roster source module, roster RPC, import Server Action, roster route, navigation item, or product UI exists. This task adds relational architecture, constraints, indexes, RLS, generated types, tests, and documentation only. Task 007B.2 remains unstarted.
