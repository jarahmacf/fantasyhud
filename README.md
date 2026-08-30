# FANTASY HUD

FANTASY HUD is a portfolio-management and command-center interface for serious fantasy-football players. This repository currently contains the styled application shell and engineering foundation only.

## Repository status

Task 001 establishes a dark Next.js dashboard shell, a reusable typed table, strict TypeScript, unit and browser testing, formatting, linting, and continuous integration. No backend is connected. Authentication, databases, provider integrations, analytics, and fantasy-football data are intentionally deferred.

## Local setup

Requirements:

- Node.js 24 (see `.nvmrc`)
- npm

Install and start the application:

```bash
nvm use
npm ci
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Commands

| Command                | Purpose                                                |
| ---------------------- | ------------------------------------------------------ |
| `npm run dev`          | Start the local development server                     |
| `npm run build`        | Create a production build                              |
| `npm run start`        | Serve the production build                             |
| `npm run typecheck`    | Run strict TypeScript checks                           |
| `npm run lint`         | Run ESLint with zero warnings allowed                  |
| `npm run format:check` | Check formatting with Prettier                         |
| `npm run format:write` | Apply Prettier formatting                              |
| `npm run test`         | Run Vitest unit tests once                             |
| `npm run test:watch`   | Run Vitest in watch mode                               |
| `npm run e2e`          | Run the Playwright Chromium test                       |
| `npm run check`        | Run typecheck, lint, formatting, unit tests, and build |

For a first local browser-test run, install Chromium with `npx playwright install chromium`. The browser-test command builds and serves the production application automatically.

## Visual reference

Selected dashboard-shell and table patterns were adapted from the MIT-licensed ShadcnStore dashboard template supplied with Task 001. See `REFERENCE_STYLE.md`, `THIRD_PARTY_NOTICES.md`, and `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`.
