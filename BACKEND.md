# Backend foundation

Supabase is the backend platform for FANTASY HUD. The hosted development project is owned directly in the project's Supabase account; it was not provisioned through the Vercel Marketplace. There is no production Supabase project.

## Source of truth

Database migrations in `supabase/migrations/` are the schema source of truth. Every schema change must be represented by a reviewed migration. Dashboard-only schema changes are prohibited.

The Supabase GitHub integration connects `jarahmacf/fantasyhud` with working directory `.` and deployment branch `main`. Reviewed migrations deploy to the hosted development project after they reach `main`. GitHub Actions verifies migrations locally and never deploys them.

The current free plan does not support database preview branches. Branch-level database work therefore uses local Supabase. Task 004 is deployed and its hosted connection canary passed. Task 005 adds only reviewed parent-schema migrations; it makes no provider request or import.

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

Task 003 adds profiles, shared fantasy accounts, and user-to-account associations. Task 004 reuses that model for one validated identity connection. Task 005 extends the indexed RLS path through account-to-league discovery and shared leagues, and adds shared provider season state plus sync-run observability. Authenticated sessions receive only exact read grants; all provider-data mutation remains server-only.

The implemented fantasy-data parent tables are:

- `provider_season_states`: latest shared provider/sport state
- `leagues`: one canonical shared provider league
- `fantasy_account_leagues`: discovery association, not roster ownership
- `sync_runs`: one tracked account, scope, and attempt

See `FANTASY_DATA_ARCHITECTURE.md` for future grains and history rules and `SYNC_ARCHITECTURE.md` for lifecycle, concurrency, and sanitized-error requirements. Task 005 adds no import function, queue, cache, scheduler, child fact table, or production Supabase project.

Authentication uses `@supabase/ssr`, cookie sessions, Next.js `proxy.ts` refresh, and signed claims for protection. `getSession()` is never an authorization source. See `AUTH.md`, `ACCOUNT_IDENTITY.md`, and `SLEEPER_CONNECTION.md`.
