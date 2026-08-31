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

Future writes must occur in validated server-side operations. Those operations must validate the app user before constructing an admin client, confirm the tracked-account authorization path, sanitize errors, and preserve terminal run history. Task 005 adds no import RPC or Server Action.
