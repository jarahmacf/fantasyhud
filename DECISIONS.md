# Decision log

This log is append-only. New decisions are added as new rows; prior entries are not rewritten.

| Date       | Decision                                            | Reason                                                               | Status   |
| ---------- | --------------------------------------------------- | -------------------------------------------------------------------- | -------- |
| 2026-08-30 | Clean rebuild; legacy repository not copied         | Prevent legacy code and assumptions from entering the new foundation | Accepted |
| 2026-08-30 | Next.js App Router                                  | Use the current file-system application model                        | Accepted |
| 2026-08-30 | TypeScript strict mode                              | Make unsafe states visible during development                        | Accepted |
| 2026-08-30 | Tailwind CSS and shadcn/ui                          | Establish a small, composable UI baseline                            | Accepted |
| 2026-08-30 | Use the ShadcnStore reference selectively under MIT | Adopt useful visual patterns without importing template scope        | Accepted |
| 2026-08-30 | Dark-only initial shell                             | Match the intended product language while keeping Task 001 focused   | Accepted |
| 2026-08-30 | Exclude the theme customizer                        | Keep appearance intentional and avoid unnecessary state              | Accepted |
| 2026-08-30 | Vitest for unit tests                               | Provide fast component-level verification                            | Accepted |
| 2026-08-30 | Playwright for browser tests                        | Verify the rendered application in Chromium                          | Accepted |
| 2026-08-30 | GitHub is the source of truth                       | Keep code, history, and automated checks together                    | Accepted |
| 2026-08-30 | Defer the backend                                   | Task 001 is limited to the frontend and engineering baseline         | Accepted |
| 2026-08-30 | Use small independently audited tasks               | Keep changes directly reviewable                                     | Accepted |
| 2026-08-30 | Compilation alone never proves completion           | Completion requires all specified quality gates                      | Accepted |
