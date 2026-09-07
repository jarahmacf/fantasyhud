# FANTASY HUD

FANTASY HUD is a portfolio-management and command-center interface for serious fantasy-football players. This repository contains the canonical application shell, backend foundation, authentication, canonical Sleeper account identity, shared fantasy-data schema, current-season Sleeper league and roster import, the canonical Sleeper NFL player catalog, immutable scoring and league-format contexts, and the architecture for shared complete draft boards.

## Repository status

Tasks through 008A.1 are deployed and production-verified. The current Task 008A.2 branch is architecture-only: it defines league and account draft-collection watermarks, one canonical shared provider draft, first-class draft slots, explicit tri-state account participation, complete board picks, historical player context, conservative draft-environment identity, finalized-board protection, indexed RLS, and safe browser projections. It imports no draft data and adds no provider call, lifecycle RPC, route, navigation item, metric, or product UI. Task 008B has not begun.

## Future analytics boundary

ADP, positional ADP rank, fantasy scoring, and season ranking are context-dependent results rather than player properties. Raw football statistics remain separate from exact-scoring-context results; total-points and points-per-game rankings remain distinct and through-week results are never labeled final. At-time pick comparisons are prior-only and leave-one-out, while cross-position analysis uses a versioned comparable capital or expected-outcome method instead of summing raw positional-rank deltas. Historical analysis retains draft-time NFL team and position.

Exact provider scoring and league settings remain immutable provider-specific identity. Provider-neutral FANTASY HUD compatibility retains material scoring differences, normalizes only reviewed no-ops, compares complete slot-count profiles rather than roster size alone, and uses conservative fallback so unknown values narrow matching. A provider-neutral key does not claim another provider has already been mapped, and no context fallback is silent.

Sleeper's documented public API is not assumed to provide an authorized player-statistics, season-ranking, projection, or platform-wide ADP feed. A separate source-feasibility and licensing task must pass before raw-stat import or a scoring engine begins; Sleeper `search_rank`, consumer ranking surfaces, and undocumented endpoints are not substitutes for that gate.

Task 008A.2 keeps exact source maps separate from normalized slots, preserves nullable keeper truth and independent auction capital, and links exact historical context only to a real accepted same-league format observation. A later observation is partial, never exact. Finalized boards and confirmed participation fail closed on conflicting rewrites. The existing product continues to report `Rosters imported. Drafts not imported.`

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

See `BACKEND.md` for the database workflow, `SLEEPER_CONNECTION.md` for the identity boundary, `LEAGUE_DISCOVERY.md` for league discovery, `PLAYER_CATALOG.md` for the canonical player source, `ROSTER_DOMAIN.md` for roster grains, `ROSTER_IMPORT.md` for roster synchronization, `DRAFT_DOMAIN.md` for draft and Task 008B contracts, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, `ADP_CONTEXT_ARCHITECTURE.md` for future context-aware draft metrics, `PERFORMANCE_VS_DRAFT_CAPITAL_ARCHITECTURE.md` for future outcome analytics, `SYNC_ARCHITECTURE.md` for run lifecycle, and `HOSTING.md` for the Git-connected deployment model.

## Visual reference

Selected dashboard-shell and table patterns were adapted from the MIT-licensed ShadcnStore dashboard template supplied with Task 001. See `REFERENCE_STYLE.md`, `THIRD_PARTY_NOTICES.md`, and `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`.
