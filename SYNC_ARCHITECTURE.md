# Synchronization architecture

Task 005 establishes synchronization observability without implementing an import, queue, cache, scheduler, or provider request.

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

Every uniqueness-protected running operation requires a documented stale-run recovery path. Task 006 league discovery must:

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

## Results and errors

`result_counts` stores small, structured counts such as resources observed, created, updated, removed, or skipped. It is not source data.

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

## No queue yet

`sync_run_items` is deferred until multi-resource work needs resumability, item-level retries, or checkpoint recovery. Task 006 league discovery is expected to be small enough to complete as one reviewed server-side attempt.

`provider_resource_cache` is deferred until measured request reuse and freshness semantics justify it. `scheduled_refreshes` and cron are deferred until a scheduler, rate policy, and operational owner are reviewed.

## Portfolio synchronization timestamp

`fantasy_accounts.last_synced_at` remains reserved for a complete portfolio synchronization. Identity connection does not set it. League discovery alone will not set it. A future reconciliation milestone must define exactly which resource scopes constitute a complete portfolio before updating the timestamp.

## Authorization and writes

Authenticated browser sessions may read only sync runs whose `fantasy_account_id` is linked to `auth.uid()` through `user_fantasy_accounts`. Browser roles receive no insert, update, or delete grants.

Direct `service_role` privileges on provider-data tables are revoked. Future writes must occur through a narrowly scoped, reviewed `SECURITY DEFINER` RPC invoked by a validated server-side operation; `service_role` receives only `EXECUTE` on that function. The Server Action must validate the app user before constructing an admin client, confirm the tracked-account authorization path, sanitize errors, and preserve terminal run history.

League-discovery persistence must also validate transactionally that `fantasy_accounts.provider = leagues.provider = sync_runs.provider`. Cross-provider associations are invalid. Task 005.1 adds no import RPC or Server Action; Task 006 must introduce and test its own service-only function before performing any provider-data write.
