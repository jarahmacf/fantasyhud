# Backend foundation

Supabase is the backend platform for FANTASY HUD. The hosted development project is owned directly in the project's Supabase account; it was not provisioned through the Vercel Marketplace. There is no production Supabase project.

## Source of truth

Database migrations in `supabase/migrations/` are the schema source of truth. Every schema change must be represented by a reviewed migration. Dashboard-only schema changes are prohibited.

The Supabase GitHub integration connects `jarahmacf/fantasyhud` with working directory `.` and deployment branch `main`. Reviewed migrations deploy to the hosted development project after they reach `main`. GitHub Actions verifies migrations locally and never deploys them.

The current free plan does not support database preview branches. Branch-level database work therefore uses local Supabase. Task 003 hosted migration deployment remains pending until its pull request is audited and merged.

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

The `app_private` schema contains internal trigger functions with fixed search paths. `anon` and `authenticated` cannot use or execute them. Browser code uses only the project URL and publishable key; no service-role client exists or belongs in application code.

Task 003 adds only profiles, shared fantasy accounts, and user-to-account associations. RLS exposes each user's profile and tracked identities for reads while prohibiting browser creation or mutation of fantasy accounts and links. There is no fantasy data import or production Supabase project.

Authentication uses `@supabase/ssr`, cookie sessions, Next.js `proxy.ts` refresh, and signed claims for protection. `getSession()` is never an authorization source. See `AUTH.md` and `ACCOUNT_IDENTITY.md`.
