# Task 007B.2 preflight

Verified on 2026-09-01 before roster-import editing.

## Baseline and delivery state

- Exact baseline: `6b8fa17e2b67c53ed61ce80972377acbc6937a34`
- Branch: `task/007b2-current-season-roster-import`
- Working tree: clean at branch creation
- Matching remote branch or pull request: none
- Baseline GitHub CI: run 33554919841, quality and database conclusion `success`
- Vercel Production: `Ready` and `Current` on the exact baseline
- Supabase project: `fantasyhud-development`, `main` Production branch

The local `main` ref was older than the verified remote baseline. The task branch was created from the exact baseline and comparisons use `origin/main`, not the stale local ref.

## Deployed prerequisite

Migration `20260901174019_roster_domain_architecture.sql` is deployed. The four roster-domain tables, their RLS policies, composite identity constraints, exact nullable source arrays, current keeper field, active membership-order indexes, and the `roster_sync` run scope are present.

The published player catalog prerequisite is present even though its rolling 24-hour application freshness window may elapse independently of this task.

## Sanitized hosted starting state

```text
current Sleeper league season            2026
canonical current-season leagues           30
active account-to-league associations      30

canonical player entities              12,225
active primary Sleeper player mappings 12,225
successful global player catalog runs       1
running global player catalog runs           0
private player staging rows                   0

league_users                                  0
rosters                                       0
fantasy_account_rosters                       0
roster_players                                0
roster_sync runs                              0
```

`fantasy_accounts.last_synced_at` remains null. No draft, draft-pick, matchup, transaction, standing-snapshot, ranking, or market data exists.

## Existing boundaries reused by this task

- Signed claims protect server routes and actions.
- The normal RLS client resolves the app user's primary connected account before a server-only service client is constructed.
- League discovery provides the provider-resolved season and exact active account-to-league scope; it does not prove roster ownership.
- The player catalog provides canonical player identities and exact Sleeper/NFL primary mappings.
- Shared provider rows remain browser-read-only and receive no direct `service_role` CRUD.
- `sync_runs.triggered_by_user_id` remains server-only lifecycle and audit state.
- `fantasy_accounts.last_synced_at` is reserved for a future complete portfolio reconciliation.

## Absence and scope checks

Before this task, no Task 007B.2 migration, private roster-sync stage or scope, lifecycle RPC, users or rosters source module, roster-import Server Action, `/rosters` route, Rosters navigation item, roster-import fixture, roster concurrency/load script, or roster product UI existed.

The controlled live source audit passed before implementation. Its sanitized evidence is recorded in `docs/verification/task-007b2-roster-source.md`. No legacy repository was inspected or copied. Task 008 has not begun.
