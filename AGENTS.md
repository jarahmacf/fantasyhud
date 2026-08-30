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
- Do not import new packages merely because the reference template used them.
- Reference-template code must be selectively adapted, not wholesale copied.
