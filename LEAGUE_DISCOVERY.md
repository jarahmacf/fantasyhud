# Current-season Sleeper league discovery

Task 006 is the first provider-data import. It discovers the complete current-season NFL league collection for one connected canonical Sleeper account. It does not import rosters, players, drafts, matchups, transactions, rankings, markets, or analytics.

## Official source boundary

The server uses Sleeper's documented read-only endpoints:

```text
GET https://api.sleeper.app/v1/state/nfl
GET https://api.sleeper.app/v1/user/{canonical_user_id}/leagues/nfl/{league_season}
```

No API token is required. The account endpoint always receives the stored Sleeper `user_id`, never the mutable username. Browser code never calls Sleeper, and provider IDs remain strings.

Sleeper describes its API as free for noncommercial use. Commercial use therefore remains a licensing dependency that must be resolved with Sleeper before FANTASY HUD moves beyond its internal-alpha use.

## Active league season

The normalized state uses `league_season` when Sleeper supplies a valid four-digit value, otherwise the valid `season` field. If neither is valid, discovery fails. The calendar year is never used as a fallback.

The state response is normalized into exact, bounded fields before persistence. `provider_metadata` retains only source fields not represented by modeled columns.

Dashboard reads resolve `provider_season_states.league_season` first. With no provider state, the current-season rows are empty and current-season discovery is not started. With state, rows are limited to active account associations whose shared league is Sleeper NFL data for that exact season. A succeeded run counts as current-season success only when its account, provider, sport, scope, season, and status all match. Historical associations and attempts remain stored, but never appear as current-season rows or change current-season import and empty-state behavior. The latest-attempt summary is explicitly all-season and displays its run season when known.

## Complete-collection validation

The entire league array is parsed before any persistence call. Every row must be an object with a unique exact league ID, NFL sport, the resolved league season, safe source status and season type, bounded integer counts, object settings, object scoring settings, and an ordered string roster-position array. One malformed row, duplicate ID, wrong season, oversized payload, timeout, or source failure rejects the complete collection. A source failure is never interpreted as zero leagues.

An empty array that passed these checks is a successful observed collection. It reconciles that account to zero active leagues for the exact Sleeper/NFL/season scope.

## Display-name normalization

Provider display labels may normalize insignificant outer whitespace. Sleeper league names are trimmed at the normalization boundary, while internal whitespace and case are preserved. Blank normalized names, overlong normalized names, non-string names, and source names containing ASCII control characters remain invalid.

Canonical provider identifiers and enum-like source values must remain exact. League IDs, sport, status, season type, avatar IDs, previous league IDs, and roster-position tokens continue to reject leading or trailing whitespace.

## Exact source state and classifications

`settings`, `scoring_settings`, and `roster_positions` are preserved exactly. Derived columns are filter and presentation aids only:

- `settings.type` values `0`, `1`, and `2` map to redraft, keeper, and dynasty; other values are unknown.
- Best ball is true only when `settings.best_ball` is exactly `1`.
- Superflex is true only for an exact `SUPER_FLEX` or `QB_FLEX` roster slot.
- IDP is true for an exact defensive-player slot; team `DEF` alone does not imply IDP.
- Base reception scoring of `1`, `0.5`, or `0` maps to PPR, half PPR, or standard only when no material position reception premium is present. Other valid combinations are custom; missing or unusable reception scoring is unknown.

Best ball and roster management remain independent dimensions.

## Observation timestamps

`leagues.fetched_at` is required and means the time the normalized league representation was fetched. `leagues.provider_updated_at` is nullable and is set only from a reliable provider-supplied league update timestamp. Sleeper currently supplies no such field, so request time is never copied into `provider_updated_at`.

## Shared identity and association history

A league is shared by `(provider, external_league_id)`. `fantasy_account_leagues` records that one complete user-leagues response reported the league for a tracked fantasy account. That discovery association is not roster ownership.

Completion preserves league creation time and association `first_seen_at`, advances `last_seen_at`, clears `removed_at` for a reappearing league, and marks an absent association removed only within the exact account/Sleeper/NFL/resolved-season collection. It never deletes a shared league or modifies another account's association.

Shared-league creation is safe when different accounts first report the same provider league concurrently: completion attempts `INSERT ... ON CONFLICT DO NOTHING`, then locks and reuses the canonical row on conflict. League objects are persisted in ascending external league ID order so overlapping imports acquire shared-resource locks deterministically.

Shared current representations are monotonic by `fetched_at`. Provider-season fields update only when the incoming state is at least as fresh as the stored state. Existing league fields update only when the incoming league observation is at least as fresh as the stored row. An older league observation is counted in `stale_shared_leagues_skipped`, but may still create the importing account's association. A null incoming `provider_updated_at` never erases a reliable stored timestamp. Result metadata separately records whether provider state was applied or skipped as stale.

## Atomic lifecycle and authorization

The authenticated Server Action validates signed app-user claims and loads the single primary account through the normal RLS client before constructing the server-only admin client. Provider writes then cross only these fixed-search-path `SECURITY DEFINER` functions:

```text
start_sleeper_league_discovery(uuid, uuid)
complete_sleeper_league_discovery(uuid, uuid, uuid, jsonb, jsonb)
fail_sleeper_league_discovery(uuid, uuid, uuid, text, text, boolean)
```

`PUBLIC`, `anon`, and `authenticated` cannot execute them. `service_role` and `postgres` receive execute only; `service_role` has no direct provider-table CRUD.

Completion validates the state and full league collection again inside SQL and atomically persists state, shared leagues, discovery associations, removals, and a succeeded sync run. A failure leaves prior successful provider data unchanged and stores only bounded safe metadata.

One fresh running discovery per fantasy account is reused for five minutes without a second source request. An older run is atomically failed with the bounded `stale_run_timeout` result before its replacement starts. Calling failure for an already terminal run returns an unchanged terminal result.

`fantasy_accounts.last_synced_at` is not updated. League discovery is not a complete portfolio synchronization.

## Test boundary

Unit and authenticated browser tests use deterministic local fixtures and a loopback Sleeper server. Production rejects the override. CI never calls real Sleeper endpoints.

The live source-shape and classification check is deferred to the controlled post-merge canary documented in `docs/verification/task-006-sleeper-league-source.md`.

## Roster-import handoff

Task 007B.2 treats the provider-resolved `league_season` and the exact active account-to-league association set as prerequisites. Its start RPC freezes the sorted current-season external league IDs internally; neither the browser nor the source caller supplies them. Changes made by a later league-discovery run do not alter an already running roster import.

Roster import never infers ownership from league discovery. It fetches each frozen league's official users and rosters collections and matches the connected canonical account only against exact roster owner and co-owner source fields. A succeeded or partial roster run for the same resolved current season changes the Leagues footer to `Rosters imported. Drafts not imported.` Historical or failed roster attempts do not.
