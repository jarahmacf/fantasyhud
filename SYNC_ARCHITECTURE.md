# Synchronization architecture

Task 005 establishes synchronization observability. Task 006 implements the first account-scoped league-discovery lifecycle. Task 007A adds a separate global player-catalog lifecycle without adding a queue, cache, scheduler, or portfolio child resource import.

## Global catalog runs

`provider_catalog_runs` has a different grain from account-scoped `sync_runs`:

```text
one provider + sport + catalog resource + attempt
```

Task 007A permits only Sleeper/NFL/players. `triggered_by_user_id` is server-only audit context and run ownership during staging; it is intentionally excluded from browser grants and does not make the shared catalog account-owned. Authenticated browsers can read shared sanitized run status only through the explicit safe-column projection. A connected second user reuses a successful catalog fetched within 24 hours or a running attempt active within 15 minutes. The partial unique index permits one running global attempt.

The created run accepts only normalized private batches of 1–500 records. The first batch establishes exact fetch time, byte count, and expected record count; later batches must match. Progress is the distinct staged-ID count. Identical replay is idempotent, while changed batch identity or content fails closed.

Completion locks the global resource, requires exact full progress, enforces initial and relative count floors, and publishes profiles plus mapping history in one transaction. Public tables never expose partial batches. Success and failure both delete run staging. Source and operational errors never erase the previous successful public catalog.

## Run grain

One `sync_runs` row represents:

```text
one tracked fantasy account
+ one scope
+ one attempt
```

The first allowed scope is `league_discovery`. The row records the provider, sport, optional season, triggering app user when present, progress, sanitized outcome metadata, and timestamps. `triggered_by_user_id` is audit context; authorization is always derived from `fantasy_account_id → user_fantasy_accounts`.

## Active-run uniqueness

The partial unique index:

```text
sync_runs_one_running_league_discovery_per_account_idx
```

allows at most one row with:

```text
scope = league_discovery
status = running
```

for each fantasy account. Terminal history remains unlimited. Later scopes need their own reviewed concurrency contract rather than being silently folded into this index.

## Stale-run recovery

Every uniqueness-protected running operation requires a documented stale-run recovery path. Task 006 league discovery:

1. Lock the fantasy-account/run boundary transactionally.
2. Reuse an existing running league-discovery run when its `updated_at` activity timestamp is no more than five minutes old.
3. Treat an older running league-discovery run as stale.
4. Atomically mark the stale run `failed` with `finished_at`, bounded code `stale_run_timeout`, a bounded safe message, retryability, and the `league_discovery` stage.
5. Start the replacement run only after the stale row is terminal.

League discovery is a single-step operation, so `updated_at` is its activity timestamp. Multi-resource imports must use item leases or explicit heartbeats instead of extending this simple timeout rule.

## Lifecycle

Allowed statuses:

```text
running → succeeded
running → failed
running → partial
```

- `running` requires `finished_at` to be null.
- `succeeded`, `failed`, and `partial` require `finished_at`.
- Finish time cannot precede start time.
- Progress values are nonnegative.
- When a positive total is known, current progress cannot exceed it.
- A total of zero means the total is not yet known; it is not evidence of an empty provider collection.

Completed attempts remain operational history. They are not deleted merely because a later attempt succeeds.

Task 006 implements this lifecycle with service-only start, complete, and fail RPCs. Start serializes on the shared fantasy account, reuses a fresh run without a source request, and recovers a stale run before replacement. Complete performs provider-state, league, association, scoped-removal, result-count, and succeeded-run writes in one transaction. Shared league keys are processed in ascending external-ID order; first creation uses conflict-safe insert-or-load, so concurrent account imports reuse one canonical row without inconsistent lock ordering. Fail changes only a matching running run and preserves prior provider data; a repeated terminal failure returns `changed_run = false`.

## Results and errors

`result_counts` stores small, structured counts such as resources observed, created, updated, removed, or skipped. It is not source data.

Task 006 reports `stale_shared_leagues_skipped` separately from updated leagues and records whether the provider-season state was applied or skipped because it was older. Shared provider state and shared league representations update only when incoming `fetched_at` is at least the stored fetch time. Account-specific discovery associations may still advance when their shared representation is stale.

`error_summary` stores sanitized operational metadata such as a bounded error category, safe message, retryability, and affected stage. It must never contain:

- a raw provider response
- authentication or authorization headers
- cookies
- access or refresh tokens
- database credentials
- service keys
- provider secrets
- unbounded stack traces or payloads

A source error is not an empty collection. Failed, partial, unavailable, and confirmed-empty outcomes stay distinct.

A zero-length fully validated source array completes with zero observed and active associations. A timeout, HTTP error, malformed row, duplicate ID, or wrong-season row fails the run instead.

## No queue yet

`sync_run_items` is deferred until multi-resource work needs resumability, item-level retries, or checkpoint recovery. Task 006 league discovery is expected to be small enough to complete as one reviewed server-side attempt.

`provider_resource_cache` is deferred until measured request reuse and freshness semantics justify it. `scheduled_refreshes` and cron are deferred until a scheduler, rate policy, and operational owner are reviewed.

Task 007A's 24-hour successful-run lookup is a domain freshness rule, not a generic cache. No force bypass, scheduled refresh, or item queue exists.

## Portfolio synchronization timestamp

`fantasy_accounts.last_synced_at` remains reserved for a complete portfolio synchronization. Identity connection does not set it. Task 006 league discovery does not set it. A future reconciliation milestone must define exactly which resource scopes constitute a complete portfolio before updating the timestamp.

Task 007A player catalog refresh also does not set it because the catalog is shared prerequisite data and proves no account portfolio completeness.

## Authorization and writes

Authenticated browser sessions may read only sync runs whose `fantasy_account_id` is linked to `auth.uid()` through `user_fantasy_accounts`. Browser roles receive no insert, update, or delete grants.

Direct `service_role` privileges on provider-data tables are revoked. Task 006 writes occur through narrowly scoped, reviewed `SECURITY DEFINER` RPCs invoked by a validated server-side operation; `service_role` receives only `EXECUTE` on those functions. The Server Action validates the app user before constructing an admin client, confirms the tracked-account authorization path, sanitizes errors, and preserves terminal run history.

League-discovery persistence validates transactionally that `fantasy_accounts.provider = leagues.provider = sync_runs.provider`. Cross-provider associations are invalid. Completion accepts only a fully normalized state object and collection, then atomically updates one exact account/provider/sport/season boundary.

Current-season dashboard reads first resolve shared provider state, then filter active associations and successful discovery runs to the resolved league season. Historical associations and terminal run history remain available but do not become current-season UI state.
