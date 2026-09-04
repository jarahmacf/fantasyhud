# FANTASY HUD

FANTASY HUD is a portfolio-management and command-center interface for serious fantasy-football players. This repository contains the canonical application shell, backend foundation, authentication, canonical Sleeper account identity, shared fantasy-data parent schema, current-season Sleeper league discovery, canonical Sleeper NFL player catalog, and current-season relational roster import.

## Repository status

Tasks through 007B.2 are deployed and production-verified, including complete current-season Sleeper league-user and roster import, exact owner/co-owner associations, canonical current holdings, and the first `/rosters` product surface. Task 008A.1 is the current undeployed draft-branch work. Its correction hardens the same unmerged context migration with material-rule-preserving semantic scoring compatibility, exact league-settings identity, full count-sensitive lineup compatibility, independent QB and IDP dimensions, fully validated immutable rows, and one accepted format context per league observation time. Task 008A.2 and Task 008B have not begun.

## Future analytics boundary

ADP, positional ADP rank, fantasy scoring, and season ranking are context-dependent results rather than player properties. Raw football statistics remain separate from exact-scoring-context results; total-points and points-per-game rankings remain distinct and through-week results are never labeled final. At-time pick comparisons are prior-only and leave-one-out, while cross-position analysis uses a versioned comparable capital or expected-outcome method instead of summing raw positional-rank deltas. Historical analysis retains draft-time NFL team and position.

Exact provider scoring and league settings remain immutable provider-specific identity. Provider-neutral FANTASY HUD compatibility retains material scoring differences, normalizes only reviewed no-ops, compares complete slot-count profiles rather than roster size alone, and uses conservative fallback so unknown values narrow matching. A provider-neutral key does not claim another provider has already been mapped, and no context fallback is silent.

Sleeper's documented public API is not assumed to provide an authorized player-statistics, season-ranking, projection, or platform-wide ADP feed. A separate source-feasibility and licensing task must pass before raw-stat import or a scoring engine begins; Sleeper `search_rank`, consumer ranking surfaces, and undocumented endpoints are not substitutes for that gate.

Task 008A.1 adds no draft or pick import, ADP calculation, raw-stat source, scoring engine, ranking or performance table, market feed, route, or product UI.

## Local setup

Requirements:

- Node.js 24 (see `.nvmrc`)
- npm
- Docker for the local Supabase stack

Install and start the application:

```bash
nvm use
npm ci
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Commands

| Command                              | Purpose                                                |
| ------------------------------------ | ------------------------------------------------------ |
| `npm run dev`                        | Start the local development server                     |
| `npm run build`                      | Create a production build                              |
| `npm run start`                      | Serve the production build                             |
| `npm run typecheck`                  | Run strict TypeScript checks                           |
| `npm run lint`                       | Run ESLint with zero warnings allowed                  |
| `npm run format:check`               | Check formatting with Prettier                         |
| `npm run format:write`               | Apply Prettier formatting                              |
| `npm run test`                       | Run Vitest unit tests once                             |
| `npm run test:watch`                 | Run Vitest in watch mode                               |
| `npm run e2e`                        | Run the Playwright Chromium test                       |
| `npm run e2e:auth`                   | Run authenticated Playwright against local Supabase    |
| `npm run check`                      | Run typecheck, lint, formatting, unit tests, and build |
| `npm run db:start`                   | Start the local Supabase stack                         |
| `npm run db:stop`                    | Stop the local Supabase stack                          |
| `npm run db:reset`                   | Rebuild the local database from migrations             |
| `npm run db:test`                    | Run local pgTAP database tests                         |
| `npm run db:types`                   | Generate TypeScript types from local Supabase          |
| `npm run db:types:check`             | Verify committed database types are current            |
| `npm run db:check`                   | Reset, test, and verify local database types           |
| `npm run db:test:roster-concurrency` | Race overlapping account imports against shared rows   |
| `npm run db:test:roster-load`        | Exercise the deterministic 30-league roster load       |

For a first local browser-test run, install Chromium with `npx playwright install chromium`. The browser-test command builds and serves the production application automatically.

See `BACKEND.md` for the database workflow, `SLEEPER_CONNECTION.md` for the identity boundary, `LEAGUE_DISCOVERY.md` for league discovery, `PLAYER_CATALOG.md` for the canonical player source, `ROSTER_DOMAIN.md` for roster grains, `ROSTER_IMPORT.md` for the complete-collection import contract, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, `ADP_CONTEXT_ARCHITECTURE.md` for future context-aware draft metrics, `PERFORMANCE_VS_DRAFT_CAPITAL_ARCHITECTURE.md` for future outcome analytics, `SYNC_ARCHITECTURE.md` for run lifecycle, and `HOSTING.md` for the Git-connected deployment model.

## Visual reference

Selected dashboard-shell and table patterns were adapted from the MIT-licensed ShadcnStore dashboard template supplied with Task 001. See `REFERENCE_STYLE.md`, `THIRD_PARTY_NOTICES.md`, and `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`.
