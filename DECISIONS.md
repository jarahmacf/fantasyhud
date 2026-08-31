# Decision log

This log is append-only. New decisions are added as new rows; prior entries are not rewritten.

| Date       | Decision                                            | Reason                                                                 | Status   |
| ---------- | --------------------------------------------------- | ---------------------------------------------------------------------- | -------- |
| 2026-08-30 | Clean rebuild; legacy repository not copied         | Prevent legacy code and assumptions from entering the new foundation   | Accepted |
| 2026-08-30 | Next.js App Router                                  | Use the current file-system application model                          | Accepted |
| 2026-08-30 | TypeScript strict mode                              | Make unsafe states visible during development                          | Accepted |
| 2026-08-30 | Tailwind CSS and shadcn/ui                          | Establish a small, composable UI baseline                              | Accepted |
| 2026-08-30 | Use the ShadcnStore reference selectively under MIT | Adopt useful visual patterns without importing template scope          | Accepted |
| 2026-08-30 | Dark-only initial shell                             | Match the intended product language while keeping Task 001 focused     | Accepted |
| 2026-08-30 | Exclude the theme customizer                        | Keep appearance intentional and avoid unnecessary state                | Accepted |
| 2026-08-30 | Vitest for unit tests                               | Provide fast component-level verification                              | Accepted |
| 2026-08-30 | Playwright for browser tests                        | Verify the rendered application in Chromium                            | Accepted |
| 2026-08-30 | GitHub is the source of truth                       | Keep code, history, and automated checks together                      | Accepted |
| 2026-08-30 | Defer the backend                                   | Task 001 is limited to the frontend and engineering baseline           | Accepted |
| 2026-08-30 | Use small independently audited tasks               | Keep changes directly reviewable                                       | Accepted |
| 2026-08-30 | Compilation alone never proves completion           | Completion requires all specified quality gates                        | Accepted |
| 2026-08-30 | Supabase for backend infrastructure                 | Support local-first Postgres migrations, pgTAP, and typed clients      | Accepted |
| 2026-08-30 | Direct Supabase project ownership                   | Keep project control outside the Vercel Marketplace                    | Accepted |
| 2026-08-30 | Migrations are the database source of truth         | Make schema history reviewable and reproducible                        | Accepted |
| 2026-08-30 | Platform Git integrations deploy                    | Let Vercel and Supabase deploy from GitHub without duplicate CI paths  | Accepted |
| 2026-08-30 | GitHub Actions verifies but does not deploy         | Keep CI credential-free and separate validation from deployment        | Accepted |
| 2026-08-30 | Defer database preview branches                     | The active Supabase free plan does not support them                    | Accepted |
| 2026-08-30 | ShadcnStore dashboard is canonical visual base      | Keep implementation details anchored to the supplied reference         | Accepted |
| 2026-08-30 | Direct MIT-licensed adaptation is preferred         | Preserve exact structure and spacing instead of approximating them     | Accepted |
| 2026-08-30 | Neutral dark tokens replace custom blue theme       | Match the reference and reserve chromatic color for semantic meaning   | Accepted |
| 2026-08-30 | Visual regression screenshots are required          | Make fidelity changes reviewable and detect unintentional layout drift | Accepted |
