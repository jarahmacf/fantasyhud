# Task 007A preflight

Checked on 2026-08-31 before implementation.

## Baseline

- Branch: `task/007a-canonical-player-catalog`
- Exact baseline: `ce71b5b78702f364d35c1cbdf949e457d53a0713`
- Working tree was clean before the branch was created.
- No pull request was open.
- Baseline CI run 39 completed successfully with both quality and database jobs green.
- Vercel Production was Ready and Current on the exact baseline commit.
- The Task 006.1 post-merge canary remains recorded on merged PR 8.

## Hosted migration state

The hosted development database ended at:

```text
20260831081239_current_season_league_discovery.sql
```

The preceding deployed versions were `20260831070614`, `20260831060048`,
`20260831043609`, and `20260831030756`.

## Player-related absence checks

The following tables did not exist:

- `public.players`
- `public.player_external_ids`
- `public.provider_catalog_runs`
- `app_private.sleeper_player_catalog_stage`
- roster, draft, matchup, player-ranking, and market tables

No player, roster, draft, pick, matchup, transaction, ranking, or market data
was present because those domain tables had not been created.

## Existing hosted counts

- profiles: 1
- shared fantasy accounts: 1
- app-user account links: 1
- provider season states: 1
- canonical leagues: 30
- active account-to-league associations: 30
- running league-discovery runs: 0
- retained failed league-discovery runs: 1
- succeeded league-discovery runs: 2
- all Sleeper fantasy-account `last_synced_at` values: null

These counts match the sanitized Task 006.1 production canary.

## Existing provider-data write boundary

`service_role` had no direct insert, update, or delete privilege on
`provider_season_states`, `leagues`, `fantasy_account_leagues`, or `sync_runs`.
Provider-data writes crossed only reviewed fixed-search-path `SECURITY DEFINER`
RPCs after app-user validation. Task 007A must extend, not weaken, that boundary.

## Task 007A scope

Task 007A adds only the shared canonical Sleeper NFL player catalog:

- canonical current-profile rows in `players`
- exact external identity mappings in `player_external_ids`
- global catalog attempt history in `provider_catalog_runs`
- private bounded per-run staging
- service-only start, stage, complete, and fail functions
- one global 24-hour freshness boundary
- server-only full-map fetch and conservative normalization
- an authenticated `/players` status and preview screen
- deterministic unit, database, browser, visual, concurrency, and 5,000-record
  load verification

Task 007B roster, league-user, ownership, and current-holdings imports remain out
of scope.
