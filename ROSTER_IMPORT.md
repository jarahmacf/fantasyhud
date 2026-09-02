# Current-season Sleeper roster import

Task 007B.2 imports one connected canonical Sleeper account's complete current-season league-user, roster, ownership, and current-holdings collection. It builds on current-season league discovery, the canonical player catalog, and the Task 007B.1 roster domain. It does not import historical events or complete the user's portfolio synchronization.

## Official source boundary

The server uses Sleeper's [official documented read-only endpoints](https://docs.sleeper.com/):

```text
GET https://api.sleeper.app/v1/league/{league_id}/users
GET https://api.sleeper.app/v1/league/{league_id}/rosters
```

No API token is required. Browser code never calls Sleeper. Exact stored canonical league IDs are encoded as individual URL path segments. Each request uses `Accept: application/json`, `cache: no-store`, a ten-second timeout, no more than two attempts, and a five-megabyte decoded-response ceiling enforced while streaming. Only network failures, timeouts, HTTP 429, and HTTP 5xx responses are retried.

Sleeper describes its API as free for noncommercial use and asks clients to stay below 1,000 calls per minute. Commercial operation remains a separate Sleeper licensing dependency.

## Frozen run scope

One roster run freezes:

```text
one canonical fantasy account
+ provider = sleeper
+ sport = nfl
+ the provider-resolved current league season
+ the exact sorted active account-to-league discovery set
```

The start function derives that set from current database relationships; the browser never supplies provider, account ID, season, league IDs, progress, or timestamps. Scope rows contain the exact sorted IDs and a fixed digest. A league discovered or removed after start belongs to a later run and cannot silently change an active run.

A running attempt with a valid scope is reused for 15 minutes without making a second source request. A fresh run with missing or inconsistent private scope is failed safely and replaced. An older attempt is failed as `stale_roster_sync`, its private state is deleted, and a replacement may start.

## Bounded complete-source collection

At most four leagues are fetched concurrently. The users and rosters requests for one league may run concurrently, so a normal pass has no more than eight active source requests. No third-party concurrency package is used, and new league work stops launching after the first terminal source failure.

Every expected league must produce both valid arrays. All league bundles are normalized and cross-validated in memory before private staging begins. A timeout, HTTP error, malformed item, duplicate identity, wrong league, wrong season, or unexplained annotation invalidates the full attempt; it is never translated into an empty collection.

Every league-user source object must contain an exact bounded `league_id` equal to the requested league. Missing, null, padded, control-bearing, or mismatched values fail closed. League-user avatar IDs are optional exact provider identifiers: absent or null becomes null, while a valid bounded string is preserved exactly. Unlike username, display name, and team name, an avatar ID is not a display label and is never outer-trimmed.

## Private staging and atomic publication

`app_private.sleeper_roster_sync_scopes` stores one frozen scope per run. `app_private.sleeper_roster_sync_stage` stores at most one bounded normalized bundle per run and league. Neither table is Data API domain state, and browser roles and `service_role` receive no direct access.

Bundles stage sequentially in exact external league-ID order. SQL recomputes the bundle hash. The first bundle stages once; an exact replay is idempotent; a changed replay for the same run and league fails closed. Public roster-domain tables do not change during start or stage.

Completion locks and revalidates the account, run, frozen scope, exact staged set, and every bundle. It publishes the entire collection in one transaction, marks the run terminal, and deletes all private scope and stage rows. Explicit failure and stale-run recovery also clean private state while preserving every previously successful public row.

## Exact arrays and membership authority

The roster row preserves the exact ordered source fields independently from normalized membership:

```text
co_owners
players
starters
reserve
taxi
keepers
```

For every source array:

```text
null or absent → stored null
[]             → stored explicit empty array
[values]       → stored exact ordered source values
```

Only `players` defines current roster membership. Starter, reserve, taxi, and keeper arrays annotate those current memberships; they do not create an additional membership.

When `players` is null, the exact source field advances to null but prior confirmed normalized membership is not reconciled or removed. An explicit empty `players` array confirms zero current members and removes active memberships under the freshness guard.

For starter, reserve, taxi, and keeper annotations, null preserves the prior confirmed normalized flag and order state. An explicit empty array clears it. A nonempty array applies exact current flags and ordering. Current keeper state is mutable roster context and never substitutes for immutable completed-draft keeper history.

Every normalized membership carries a validated bounded source-state contract:

```text
annotation_source_state:
  starters = known | unknown
  reserve  = known | unknown
  taxi     = known | unknown
  keepers  = known | unknown

normalization_warning_fields:
  bounded safe warning tokens only
```

Each state must agree with the corresponding exact source array: non-null is `known`, null is `unknown`. SQL rejects malformed, unbounded, or contradictory metadata rather than treating it as source truth.

## Placeholder and starter-slot behavior

The controlled source audit found repeated exact `"0"` starter values and no other starter value outside `players`. The importer preserves every `"0"` in the exact starter source array, counts it, omits it from normalized membership, and never creates a canonical player or mapping for it. Every other unexplained starter or annotation value fails closed.

Starter slots derive from the league's ordered `roster_positions` only when the non-storage starting sequence aligns exactly with the source starter array. `BN`, `IR`, and `TAXI` are storage positions, not starting slots. When alignment is uncertain, `starter_slot` remains null and bounded metadata records only the warning category.

## Canonical player references

Every active `roster_players` row references both one canonical `players` row and the exact Sleeper/NFL primary `player_external_ids` mapping for that player.

Resolution includes historical removed mappings. A current roster reference reactivates the exact mapping without changing canonical identity. A valid non-placeholder ID with no mapping creates one sparse `unknown` canonical entity and one exact primary mapping conflict-safely. It invents no name, team, position, injury, or active value; bounded metadata identifies it as a roster reference. A later catalog refresh updates the same identity when present, and catalog absence cannot retire the mapping while an active current membership references it. Secondary IDs, names, teams, and positions never merge holdings.

## Explicit ownership

Ownership compares the connected canonical fantasy account's exact external user ID with each roster:

```text
owner_id match       → owner
co_owners match      → co_owner
both on same roster  → owner
```

More than one matched roster in one league invalidates and rolls back the full completion. Ownership resolves from the current canonical active shared rosters after shared-bundle application or skipping, not from an older raw staged representation. The matching account/league row stores paired `roster_ownership_status` and `roster_ownership_observed_at` at the league's current roster-bundle watermark.

Exactly one match records `owned` and creates or refreshes only that account's association. A complete zero-match observation records `not_owned` even when no ownership row previously existed, and removes only that account's active ownership association. A zero match with any relevant null or absent co-owner source state records `unresolved` and preserves prior ownership history instead of inventing a removal. An ownership result applies only when its canonical shared watermark is at least as fresh as the association's prior observation.

Shared valid data with any unresolved league completes as `partial`, not failed. All `owned` or `not_owned` associations complete as `succeeded`. Malformed source fails and publishes nothing. Another fantasy account's association is never changed by this account's run. A preserved ownership row under `unresolved` remains queryable as history but is not current confirmed ownership.

## Monotonic shared state and conflict safety

League users, rosters, and memberships are shared mutable current state. `leagues.roster_bundle_fetched_at` is the observation time of the latest fully validated users-and-rosters bundle published for that shared league. It is distinct from league-discovery `leagues.fetched_at`. After locking the canonical league, the importer defines:

```text
stored watermark is null
or incoming bundle_fetched_at >= stored watermark
```

An equal-or-newer bundle applies all shared league-user, roster, membership, annotation, and shared-removal logic and advances the watermark atomically. An older bundle performs no shared create, update, reactivation, removal, or exact-array mutation and is counted as stale. This protects newer absence, which cannot be represented by per-row timestamps alone. Existing row-level freshness checks remain defense in depth, and equal-time replay remains idempotently applicable.

After either applying or skipping shared state, ownership resolves from the current canonical representation at the stored watermark. Thus a newer `not_owned` or `unresolved` observation cannot be overwritten by an older positive staged bundle; a later newer confirmed match restores `owned`.

Concurrent first creation uses insert-or-load behavior and reuses one canonical row. Work follows one deterministic order:

```text
external league ID
→ external league-user ID
→ external roster ID
→ exact player ID
```

Shared rows are marked removed, never deleted. User removal is scoped to its exact league; roster removal to its exact league; membership removal to its exact roster; ownership removal to its exact fantasy account and league. All shared removal is collection-watermark guarded.

## Authorization and product reads

Provider mutation crosses only four reviewed fixed-search-path `SECURITY DEFINER` functions:

```text
start_sleeper_roster_sync(uuid, uuid)
stage_sleeper_roster_league_bundle(uuid, uuid, uuid, text, jsonb)
complete_sleeper_roster_sync(uuid, uuid, uuid)
fail_sleeper_roster_sync(uuid, uuid, uuid, text, text, boolean)
```

`PUBLIC`, `anon`, and `authenticated` cannot execute them. `service_role` and `postgres` receive execute only. Start, stage, and fail have ten-second statement timeouts; completion has a 60-second timeout. Direct `service_role` CRUD remains absent from public roster-domain tables.

Authenticated shared current-state reads require an active league-discovery path through a tracked account. Current and historical account-to-roster ownership reads remain scoped through the tracked fantasy account. The `/rosters` page uses these normal RLS reads, exact count queries, and a bounded 100-row current-holdings preview.

## Product semantics

Owned rosters means active `fantasy_account_rosters` joined through the same connected account and league to an active `fantasy_account_leagues` association whose current `roster_ownership_status` is `owned`. Current holdings means active `roster_players` on those confirmed-owned rosters. A preserved ownership row under `unresolved` or `not_owned` is excluded from owned-roster counts, holdings totals, both tables, and best-ball analytics. Best-ball exposure includes every active membership on confirmed-owned rosters regardless of starter, reserve, taxi, or keeper labels, though Task 007B.2 shows holdings rather than exposure percentages.

Roster source counts preserve source certainty. Null `players`, starters, reserve, taxi, or keepers arrays render as `Not reported`; explicit empty arrays render as `0`; nonempty arrays render their exact source-derived counts, excluding only the verified `"0"` starter placeholder from the visible starter-player count. The current-holdings preview renders each membership annotation independently as `Yes`, `No`, or `Not reported` from validated `annotation_source_state`. Its aggregate copy says `Last confirmed active memberships`, because source-null players does not confirm zero current holdings.

Partial state reports unresolved leagues without inventing ownership. A valid zero-owned-roster import is distinct from an error. The Leagues page says `Rosters imported. Drafts not imported.` only after a succeeded or partial current-season roster run.

## Deliberate exclusions

Roster import does not update `fantasy_accounts.last_synced_at`. That field remains reserved for a future complete portfolio reconciliation.

This task imports no draft, pick, transaction, matchup, weekly point, standing snapshot, playoff bracket, player statistic, ranking, market ADP, exposure percentage, stack, co-holding, scheduler, cron, queue, or automatic refresh fact. Task 008 has not begun.
