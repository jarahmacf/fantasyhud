# Backend foundation

Supabase is the backend platform for FANTASY HUD. The hosted development project is owned directly in the project's Supabase account; it was not provisioned through the Vercel Marketplace. There is no production Supabase project.

## Source of truth

Database migrations in `supabase/migrations/` are the schema source of truth. Every schema change must be represented by a reviewed migration. Dashboard-only schema changes are prohibited.

The Supabase GitHub integration connects `jarahmacf/fantasyhud` with working directory `.` and deployment branch `main`. Reviewed migrations deploy to the hosted development project after they reach `main`. GitHub Actions verifies migrations locally and never deploys them.

The current free plan does not support database preview branches. Branch-level database work therefore uses local Supabase or the container-backed database CI job. Tasks through 007A.1 are deployed and their hosted gates passed. Task 007B.1 adds the empty relational roster domain, RLS, integrity, and roster-sync observability without a provider request, import lifecycle, or product UI.

## Local workflow

Requirements:

- Node.js 24
- npm
- Docker with a running daemon

Run the local stack and checks:

```bash
npm ci
npm run db:start
npm run db:reset
npm run db:test
npm run db:types
npm run db:types:check
npm run db:check
npm run db:stop
```

`db:reset` rebuilds the local database from migrations. `db:test` runs pgTAP. `db:types` generates the local `public` schema into `src/lib/supabase/database.types.ts`, and `db:types:check` fails when the committed file is stale.

## Security boundary

The `app_private` schema contains internal trigger functions with fixed search paths. `anon` and `authenticated` cannot use or execute them. Browser code uses only the project URL, publishable key, authenticated session, and RLS.

Task 004 adds one narrowly scoped server-only Supabase client using `SUPABASE_SECRET_KEY`. It is constructed only inside the authenticated Sleeper connection Server Action after signed claims are validated. It calls only the atomic `public.connect_sleeper_account` RPC. The RPC is `SECURITY DEFINER`, has a fixed search path, and is executable only by `service_role` and `postgres`.

Task 003 adds profiles, shared fantasy accounts, and user-to-account associations. Task 004 reuses that model for one validated identity connection. Task 005 extends the indexed RLS path through account-to-league discovery and shared leagues, and adds shared provider season state plus sync-run observability. Authenticated sessions receive only exact read grants.

Task 005.1 revokes direct `service_role` access to the four provider-data tables. Task 006 implements that RPC-only boundary with fixed-search-path start, complete, and fail functions. The validated Server Action loads the primary tracked account through RLS before constructing the service-role client. `service_role` receives execute only; the completion function revalidates provider, account, run, normalized state, and the full league collection before one atomic write.

Task 007A applies the same RPC-only model to the global player catalog. `players`, `player_external_ids`, `provider_catalog_runs`, and private staging grant no direct `service_role` CRUD. Four fixed-path lifecycle functions serialize the shared Sleeper/NFL/players boundary, enforce 24-hour freshness, accept idempotent batches of at most 500 normalized records, apply anti-wipe guards, publish atomically, and remove terminal staging. Completion has a 60-second function timeout; start, stage, and fail use 10 seconds. Task 007A.1 raises only the decoded source-byte envelope from 15,000,000 to 25,000,000 in both the table constraint and stage RPC. The existing 50,000-record limit, signatures, grants, timeouts, validation, staging, and publication behavior remain unchanged.

Task 007B.1 creates `league_users`, `rosters`, `fantasy_account_rosters`, and `roster_players` as empty RPC-only provider-data tables. Authenticated users may read shared league context through indexed league reachability and tracked-account ownership only through their own fantasy-account links. `service_role` has no direct CRUD. The task adds no write RPC; Task 007B.2 must add reviewed complete-collection lifecycle functions before provider data can enter these tables.

The implemented fantasy-data parent tables are:

- `provider_season_states`: latest shared provider/sport state
- `leagues`: one canonical shared provider league
- `fantasy_account_leagues`: discovery association, not roster ownership
- `sync_runs`: one tracked account, scope, and attempt
- `players`: one shared canonical NFL entity and mutable current profile
- `player_external_ids`: one exact historical external identity mapping
- `provider_catalog_runs`: one global provider/sport/catalog attempt
- `league_users`: one provider user identity as represented within one league
- `rosters`: one league-local current provider roster
- `fantasy_account_rosters`: one explicit tracked-account ownership association
- `roster_players`: one canonical player's current roster membership with its exact source mapping

See `LEAGUE_DISCOVERY.md`, `PLAYER_CATALOG.md`, and `ROSTER_DOMAIN.md` for source boundaries, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, and `SYNC_ARCHITECTURE.md` for lifecycle, concurrency, and sanitized-error requirements. Task 007B.1 adds no provider call, queue, cache, scheduler, historical fact, or production Supabase project.

Authentication uses `@supabase/ssr`, cookie sessions, Next.js `proxy.ts` refresh, and signed claims for protection. `getSession()` is never an authorization source. See `AUTH.md`, `ACCOUNT_IDENTITY.md`, and `SLEEPER_CONNECTION.md`.
