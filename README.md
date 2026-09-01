# FANTASY HUD

FANTASY HUD is a portfolio-management and command-center interface for serious fantasy-football players. This repository contains the canonical application shell, backend foundation, authentication, canonical Sleeper account identity, shared fantasy-data parent schema, current-season Sleeper league discovery, canonical Sleeper NFL player catalog, and relational current-roster architecture.

## Repository status

Tasks through 007A.1 are deployed and production-verified. Task 007B.1 establishes empty `league_users`, `rosters`, `fantasy_account_rosters`, and `roster_players` tables with exact source-array preservation, composite identity integrity, indexed RLS, and safe `roster_sync` observability. It makes no Sleeper request, imports no roster data, and adds no roster UI. Task 007B.2 remains unstarted.

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

| Command                  | Purpose                                                |
| ------------------------ | ------------------------------------------------------ |
| `npm run dev`            | Start the local development server                     |
| `npm run build`          | Create a production build                              |
| `npm run start`          | Serve the production build                             |
| `npm run typecheck`      | Run strict TypeScript checks                           |
| `npm run lint`           | Run ESLint with zero warnings allowed                  |
| `npm run format:check`   | Check formatting with Prettier                         |
| `npm run format:write`   | Apply Prettier formatting                              |
| `npm run test`           | Run Vitest unit tests once                             |
| `npm run test:watch`     | Run Vitest in watch mode                               |
| `npm run e2e`            | Run the Playwright Chromium test                       |
| `npm run e2e:auth`       | Run authenticated Playwright against local Supabase    |
| `npm run check`          | Run typecheck, lint, formatting, unit tests, and build |
| `npm run db:start`       | Start the local Supabase stack                         |
| `npm run db:stop`        | Stop the local Supabase stack                          |
| `npm run db:reset`       | Rebuild the local database from migrations             |
| `npm run db:test`        | Run local pgTAP database tests                         |
| `npm run db:types`       | Generate TypeScript types from local Supabase          |
| `npm run db:types:check` | Verify committed database types are current            |
| `npm run db:check`       | Reset, test, and verify local database types           |

For a first local browser-test run, install Chromium with `npx playwright install chromium`. The browser-test command builds and serves the production application automatically.

See `BACKEND.md` for the database workflow, `SLEEPER_CONNECTION.md` for the identity boundary, `LEAGUE_DISCOVERY.md` for league discovery, `PLAYER_CATALOG.md` for the canonical player source, `ROSTER_DOMAIN.md` for roster grains and future import requirements, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, `SYNC_ARCHITECTURE.md` for run lifecycle, and `HOSTING.md` for the Git-connected deployment model.

## Visual reference

Selected dashboard-shell and table patterns were adapted from the MIT-licensed ShadcnStore dashboard template supplied with Task 001. See `REFERENCE_STYLE.md`, `THIRD_PARTY_NOTICES.md`, and `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`.
