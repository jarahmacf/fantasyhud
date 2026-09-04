# Backend foundation

Supabase is the backend platform for FANTASY HUD. The hosted development project is owned directly in the project's Supabase account; it was not provisioned through the Vercel Marketplace. There is no production Supabase project.

## Source of truth

Database migrations in `supabase/migrations/` are the schema source of truth. Every schema change must be represented by a reviewed migration. Dashboard-only schema changes are prohibited.

The Supabase GitHub integration connects `jarahmacf/fantasyhud` with working directory `.` and deployment branch `main`. Reviewed migrations deploy to the hosted development project after they reach `main`. GitHub Actions verifies migrations locally and never deploys them.

The current free plan does not support database preview branches. Branch-level database work therefore uses local Supabase or the container-backed database CI job. Tasks through 007B.2 are deployed and their hosted gates passed. Task 008A.1 is the current undeployed draft-branch architecture work and remains incomplete until its migration, database contracts, application checks, review, merge, and hosted verification pass.

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

Task 007B.1 creates `league_users`, `rosters`, `fantasy_account_rosters`, and `roster_players` as RPC-only provider-data tables. Authenticated users may read shared league context through indexed league reachability and tracked-account ownership only through their own fantasy-account links. `service_role` has no direct CRUD.

Task 007B.2 adds private frozen-scope and one-bundle-per-league staging plus four fixed-search-path roster lifecycle RPCs. Start derives the exact current-season league set from current database relationships, reuses a valid running attempt for 15 minutes, and recovers stale or inconsistent private state. Stage accepts one bounded normalized bundle in the frozen scope and is idempotent only for an identical server-computed hash. Completion requires the exact full staged set and publishes shared league users, rosters, explicit account ownership, and canonical player memberships atomically. Fail, success, partial completion, and stale recovery delete private roster stage and scope rows. Start, stage, and fail have ten-second function timeouts; completion has a 60-second timeout. Browser roles cannot execute these functions, and `service_role` retains execute-only access with no direct public or private table CRUD.

The roster Server Action validates signed claims, resolves the primary tracked Sleeper account through RLS, requires provider season state, active current-season leagues, and a published player catalog, then fetches the complete official users-and-rosters collection through the server-only Sleeper boundary. It validates the complete collection before sequential staging and revalidates both `/` and `/rosters` after terminal state. No source payload, provider ID list, service secret, or database error is returned to the browser.

Task 008A.1's corrected draft migration introduces an immutable context model and remains undeployed. A scoring context preserves exact authoritative `scoring_settings` under a provider-specific versioned fingerprint. Its separate provider-neutral FANTASY HUD semantic projection retains every known material scoring rule. Version one removes only explicitly allowlisted, reviewed additive-bonus rules whose value is numeric zero and numeric `rec_{fb,qb,rb,te,wr}` values equal to numeric base `rec`; unknown or malformed values remain in bounded exact fallback. The `fantasyhud:nfl:scoring_compatibility` namespace identifies reviewed semantics, not evidence that a second provider has already been mapped.

A league format context combines scoring identity with exact ordered roster positions, an exact league-settings fingerprint, team count, roster size, best-ball state, roster-management type, independent quarterback format, and IDP state. Exact lineup order and compatible composition are different: the exact lineup fingerprint preserves order, while a dedicated count-sensitive `lineup_profile` and provider-neutral fingerprint preserve every slot token and count, including safe unknown tokens. Format compatibility also includes the reviewed draft-relevant settings projection and a provider-neutral exact fallback fingerprint over all other key-values, so uncertainty narrows rather than broadens matching.

The same version-one format classifier drives creation and insert validation. Before an immutable row is accepted, the database recomputes its scoring linkage, league-settings fingerprint, ordered-lineup fingerprint, lineup-profile fingerprint, exact format fingerprint, quarterback format, compatibility key, context quality, and derived dimensions. `leagues.current_format_context_id` points through the format context to scoring identity; it does not duplicate a mutable scoring pointer. Accepted observations are append-only and unique by league plus source observation time: identical context-and-version replay is idempotent, a contradictory same-time context fails closed and rolls back the enclosing discovery mutation, later accepted state appends history, and stale state appends nothing.

The scoring and league-format context tables remain provider data: browser mutation is prohibited, direct `service_role` CRUD is prohibited, and writes occur only through reviewed fixed-search-path league-discovery functions. Authenticated reads use scoped RLS and safe projections; exact source JSON is authoritative and is not an unscoped globally browser-readable payload. The correction amends the existing unmerged Task 008A.1 migration rather than adding a second migration, and it remains non-Production state until review, merge, and hosted verification pass.

Task 008A.1 also defines future analytics boundaries without implementing them. ADP and positional ADP rank remain results keyed by sample universe, exact or disclosed fallback context, season, time, draft cohort, eligibility, methodology, and sample size. Raw football statistics, exact-context fantasy scoring, and typed through-period rankings are separate grains; one scoring result is reused for leagues sharing a scoring context. Pick comparisons are prior-only and leave-one-out. Cross-position aggregates use versioned normalized capital, percentiles, or expected-points methods rather than summing positional-rank deltas, and historical analysis preserves draft-time NFL team and position.

Player statistics remain source-gated. Sleeper's documented public API is not assumed to provide authorized player statistics, season rankings, projections, or ADP; `search_rank` remains search metadata, and consumer surfaces or undocumented endpoints are not supported API contracts. Task 013A must verify authorization and commercial use, canonical ID coverage, revisions, weekly and historical depth, team-defense and IDP support, required stat categories, and update cadence before any import or scoring engine is implemented. Task 008A.1 adds no draft, pick, ADP, raw-stat, scoring, ranking, market, performance, or product-UI implementation. Task 008A.2 has not begun.

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

See `LEAGUE_DISCOVERY.md`, `PLAYER_CATALOG.md`, `ROSTER_DOMAIN.md`, and `ROSTER_IMPORT.md` for source boundaries, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, `ADP_CONTEXT_ARCHITECTURE.md` for the future context-aware ADP contract, `PERFORMANCE_VS_DRAFT_CAPITAL_ARCHITECTURE.md` for future outcome and capital-efficiency boundaries, and `SYNC_ARCHITECTURE.md` for lifecycle, concurrency, and sanitized-error requirements. Task 007B.2 adds no queue, cache, scheduler, historical fact, complete portfolio timestamp, or production Supabase project.

Authentication uses `@supabase/ssr`, cookie sessions, Next.js `proxy.ts` refresh, and signed claims for protection. `getSession()` is never an authorization source. See `AUTH.md`, `ACCOUNT_IDENTITY.md`, and `SLEEPER_CONNECTION.md`.
