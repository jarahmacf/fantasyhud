# FANTASY HUD

FANTASY HUD is a portfolio-management and command-center interface for serious fantasy-football players. This repository contains the canonical application shell, backend foundation, authentication, canonical Sleeper account identity, and the first shared fantasy-data parent schema.

## Repository status

Task 005 adds the reviewed long-term fantasy-data contract plus shared provider-season state, canonical leagues, account-to-league discovery associations, sync-run observability, and indexed read-only browser authorization. It makes no provider request and imports no league, roster, player, draft, matchup, transaction, ranking, market, or analytics data.

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

See `BACKEND.md` for the database workflow, `SLEEPER_CONNECTION.md` for the provider boundary, `FANTASY_DATA_ARCHITECTURE.md` for grains and history rules, `SYNC_ARCHITECTURE.md` for run lifecycle, and `HOSTING.md` for the Git-connected deployment model.

## Visual reference

Selected dashboard-shell and table patterns were adapted from the MIT-licensed ShadcnStore dashboard template supplied with Task 001. See `REFERENCE_STYLE.md`, `THIRD_PARTY_NOTICES.md`, and `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`.
