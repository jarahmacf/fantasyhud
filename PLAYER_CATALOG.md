# Canonical Sleeper NFL player catalog

Task 007A introduces one shared current catalog from Sleeper's official, read-only `GET /v1/players/nfl` endpoint. Sleeper requires no API token for this endpoint, describes the response as roughly 5 MB, and recommends limiting full-map retrieval to once per day. Commercial use remains a separate Sleeper licensing dependency.

## Source and freshness

The server fetches exactly `/players/nfl`, with no filters, at most twice for transient transport failures, a 30-second timeout, and a 15 MB decoded-body limit. Fetch completion records `source_fetched_at`, byte size, and record count. Neither the browser nor a query parameter can select another origin, bypass freshness, or submit source data.

A successful Sleeper/NFL/players run is globally fresh for 24 rolling hours. Any connected app user reuses that successful catalog without a source request. One active global run is reused for 15 minutes; an older running attempt is failed with bounded metadata, its staging is removed, and a replacement may start.

## Canonical grains

- `players` is one shared canonical NFL entity and mutable current profile.
- `player_external_ids` is one exact namespace, sport, and external ID mapped historically to one canonical player.
- `provider_catalog_runs` is one global provider, sport, catalog, and attempt.
- `app_private.sleeper_player_catalog_stage` is bounded transactional implementation state, never public domain truth.

The exact Sleeper map key is the primary identity. Team defenses are `team_defense` entities when `DEF` is a normalized position. A sparse record with a valid exact ID remains an `unknown` entity; stored data never invents an “Unknown Player” name. The UI alone may fall back to the exact active Sleeper ID.

## Current profiles are not historical facts

The catalog stores current mutable profile fields. `profile_fetched_at` is when FANTASY HUD observed that profile and is the monotonic update boundary. `news_updated_at` is a provider-reported news timestamp only. Neither field supplies period-specific historical team or position context. Draft, matchup, transaction, statistic, and ranking facts must preserve their own context later.

Sleeper `search_rank` is retained only as source search metadata. It is not a fantasy rank, ADP value, exposure metric, or market signal.

Malformed optional fields become null or are skipped with bounded field-name warnings. Optional display fields reject ASCII control characters in the original source string before ordinary or Unicode outer whitespace is trimmed; control characters are never silently normalized away. Hard failure is reserved for the catalog envelope and identity contract: a non-object map, a count outside 500–50,000, an invalid exact key, a non-object row, a conflicting present `player_id`, a non-NFL sport, an oversized response, or a normalized contract failure.

## Atomic batch lifecycle

The normalized map is sorted by exact Sleeper ID and staged sequentially in idempotent batches of at most 500. A retry with the same ID, batch index, and record hash is a no-op. Changed or duplicated identities fail closed. Public player tables remain unchanged until all staged rows equal the declared source count.

Finalization revalidates the entire staged catalog, requires at least 500 records, and rejects a later catalog below `max(500, floor(previous successful count × 0.75))`. It then publishes in one transaction, marks the run succeeded, stores aggregate counts, and deletes staging. Failure also deletes staging while preserving the previous successful public catalog.

Primary Sleeper mappings retain first-seen history, advance last seen, reactivate an exact returned ID, and mark absent active IDs removed without deleting canonical players. Secondary candidates are limited to documented ESPN, Yahoo, Stats, Sportradar, FantasyData, Rotowire, and Rotoworld fields. Exact strings remain strings; nonnegative JavaScript-safe integers may become decimal text. Ambiguous current-source candidates and mappings owned by another canonical player are skipped and counted. A changed unambiguous ID for the same player replaces the active mapping while retaining historical rows. Secondary IDs never merge canonical players.

## Authorization and operations

Authenticated users may select public catalog rows. Global catalog-run status is browser-readable only through an explicit safe column projection. `triggered_by_user_id` remains server-only audit and run-ownership state and has no authenticated browser grant. Browser roles cannot mutate catalog rows. `service_role` has no direct CRUD on public catalog tables or private staging; it may execute only the four reviewed, fixed-search-path lifecycle RPCs. Start, stage, and fail use 10-second statement timeouts; atomic completion uses at most 60 seconds.

Catalog summary terms are exact. **Canonical entities** means every retained row in `players`, including historical identities whose primary Sleeper mapping was removed. **Active players** means `entity_type = player`, `active = true`, with an active primary Sleeper/NFL mapping. **Team defenses** means `entity_type = team_defense` with an active primary Sleeper/NFL mapping; the optional provider `active` field does not control this count. Unknown entities remain a separate class, and active external-ID mappings count every mapping whose `removed_at` is null.

The authenticated `/players` page distinguishes not imported, running, failed, imported-with-no-preview-entities, and database-query failure. It shows sanitized catalog aggregates and at most 50 active current entities. It exposes no payload, raw warnings, triggering user ID, fantasy ranking, ADP, roster ownership, or player detail route.

Catalog refresh does not update `fantasy_accounts.last_synced_at`. It imports no league ownership, roster membership, draft, matchup, transaction, ranking, market, or portfolio reconciliation facts. There is no scheduler, force-refresh control, queue, or automatic cross-ID merge in Task 007A.

The Task 007A database contract uses an exact pgTAP assertion plan so missing or extra privacy, lifecycle, identity, and count assertions fail the suite.
