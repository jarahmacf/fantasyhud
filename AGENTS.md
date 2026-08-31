<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# FANTASY HUD working rules

- Follow the current task exactly.
- Do not expand scope.
- Do not copy from the legacy repository unless explicitly instructed.
- Inspect existing code before editing.
- Keep business logic outside React components.
- Prefer pure tested functions.
- Write meaningful tests.
- Never call real external APIs in CI.
- Never commit secrets.
- Never claim completion with failing checks.
- Run all required commands before completion.
- Report exact command results.
- Keep tasks small enough for direct review.
- Do not create abstractions for hypothetical future needs.
- Do not silently reinterpret product terminology.
- Preserve uncertainty instead of inventing values.
- Treat the supplied ShadcnStore dashboard as the canonical visual base under its preserved MIT license.
- When changing shell, card, sidebar, header, heading, page spacing, or table styling, inspect the corresponding canonical reference files first.
- Prefer direct adaptation of the reference tokens, structure, dimensions, spacing, and component composition where product requirements allow.
- Do not recreate the reference from memory or introduce a generic AI-dashboard aesthetic.
- Do not replace the neutral reference styling with arbitrary brand colors.
- Do not claim visual fidelity without desktop and mobile screenshots.
- Preserve visual-regression tests unless intentionally updating the documented visual system and its baselines.
- New product screens must use the canonical card, table, heading, and page-spacing patterns documented in `VISUAL_SYSTEM.md`.
- Vercel and Supabase deploy through their GitHub integrations.
- GitHub Actions verifies code and migrations but never deploys them.
- Represent every schema change with a version-controlled migration.
- Do not make dashboard-only schema changes.
- Never claim a remote migration deployed before verifying it.
- Never commit secrets or expose service-role keys.
- Never use a production database for development tests.
- Use `getClaims()` or the current verified equivalent to protect server routes and data.
- Never trust `getSession()` for authorization.
- Never create fantasy-account connections or link rows directly from browser input.
- Never expose auth codes, token hashes, passwords, access tokens, or refresh tokens.
- Never put service secrets in public environment variables.
- Keep authenticated app users and provider fantasy identities separate.
- Never use a Sleeper username as canonical identity.
- Never parse provider IDs as numbers.
- Never call Sleeper from browser code.
- Never accept canonical provider IDs from browser input.
- Never use the admin client before validating the app user.
- Never import the admin client into Client Components.
- Never label a connected identity as synchronized.
- Never call the real Sleeper API in CI.
- Never infer roster ownership from league discovery.
- Never infer one draft per league.
- Never discard exact scoring settings.
- Never combine best ball and dynasty into one value.
- Never delete shared resources because one account stops reporting them.
- Never overwrite immutable historical facts.
- Never treat a source error as an empty collection.
- Never add a materialized analytics table without measured need.
- Never add a ranking without source and scoring context.
