# Sleeper account connection

Task 004 connects one authenticated FANTASY HUD user to one public Sleeper identity. It resolves identity only; it does not import or synchronize fantasy data.

## Source API

The server uses Sleeper's documented read-only endpoint:

```text
GET https://api.sleeper.app/v1/user/{username}
```

Sleeper requires no API token. The API is read-only, and Sleeper describes it as free for noncommercial use. Commercial use requires a future licensing discussion with Sleeper before the product expands beyond the internal alpha.

Browser code never calls Sleeper. The submitted username is normalized, URL-encoded as one path segment, and resolved by `src/lib/sleeper/client.server.ts`. Requests use `Accept: application/json`, `cache: no-store`, a five-second timeout, and at most two attempts. Only timeouts, network failures, HTTP 429, and HTTP 5xx responses are retried. `Retry-After` is honored with a one-second upper bound.

Tests use a deterministic local HTTP server through `SLEEPER_API_BASE_URL`. A test-only server flag opts the production-build test process into that loopback address; arbitrary origins and Vercel Production still fail closed. CI never calls the real Sleeper API.

## Canonical identity

Sleeper usernames can change. The canonical identity is:

```text
provider = sleeper
external_user_id = Sleeper user_id
```

Every provider ID remains a string. Username is mutable presentation and lookup data, never a unique identity key. Multiple app users may track the same shared `fantasy_accounts` row through separate `user_fantasy_accounts` links.

Connection means that an app user chose to track a public Sleeper identity. It is not Sleeper authentication, ownership proof, or synchronization.

## Atomic persistence

`public.connect_sleeper_account(uuid, text, text, text, text, jsonb)` is a `SECURITY DEFINER` function with a fixed `pg_catalog` search path. It validates and locks the Auth user, upserts the shared canonical account, refreshes mutable provider presentation fields, creates or reuses the user link, and makes only the first link primary in one transaction.

Execution is revoked from `PUBLIC`, `anon`, and `authenticated`, and granted only to `service_role` and `postgres`. Browser sessions retain their Task 003 RLS-scoped reads and cannot create or mutate accounts or links.

The authenticated Server Action validates signed claims before creating the narrowly scoped admin client. Hosted deployments use a named `sb_secret_...` key in the server-only `SUPABASE_SECRET_KEY` variable. Local tests pass the local service-role equivalent through the same variable. The value is never public, logged, committed, sent to CI as a hosted secret, or returned to the browser.

## Scope

Task 004 stores only identity and link state. `last_synced_at` remains null, and the UI states that portfolio import has not started. League, roster, player, draft, pick, matchup, transaction, and market data remain deferred.
