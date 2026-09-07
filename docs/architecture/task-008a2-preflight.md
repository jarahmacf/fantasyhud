# Task 008A.2 preflight

Task 008A.2 starts from the exact deployed and hosted-verified Task 008A.1 baseline:

```text
896fbff3282502f33dc45259444510e5dbfdd995
```

The working tree was clean before branch creation. The implementation branch is `task/008a2-draft-domain-architecture`. GitHub reported no open pull requests, and merged-main CI run `33927582964` passed both `quality` and `database` for the exact baseline. Vercel Production was Ready and Current on that commit, and Supabase Production contained every migration through `20260901220000_scoring_and_format_context_architecture.sql`.

## Sanitized hosted baseline

| Domain                                |                            Count or state |
| ------------------------------------- | ----------------------------------------: |
| Current Sleeper league season         |                                      2026 |
| Current leagues                       |                                        30 |
| Active account-to-league associations |                                        30 |
| Confirmed owned rosters               |                                        30 |
| Active league users                   |                                       387 |
| Active shared rosters                 |                                       372 |
| Active roster memberships             |                                     7,196 |
| Confirmed-owned memberships           |                                       616 |
| Canonical player entities             |                                    12,225 |
| Active primary Sleeper mappings       |                                    12,225 |
| Current format pointers               |                                        30 |
| Format observations                   |                                        30 |
| Exact scoring contexts                |                                        13 |
| Semantic scoring compatibility keys   |                                        13 |
| Exact league-format contexts          |                                        25 |
| Lineup profiles                       |                                        14 |
| Format compatibility keys             |                                        25 |
| Context quality                       |            exact 25; partial 0; unknown 0 |
| Quarterback format                    | one-QB 6; superflex 18; two-QB 1; other 0 |
| IDP                                   |                          false 25; true 0 |
| Terminal/running roster-sync runs     |                                     2 / 0 |
| Private roster stage/scope rows       |                                     0 / 0 |
| `fantasy_accounts.last_synced_at`     |                        null for every row |

All 30 current leagues have a non-null immutable format-context pointer. Hosted Task 008A.1 recomputation and collision checks passed with zero known material scoring or format collisions.

## Existing identity and access paths

- Fantasy accounts are canonical by provider plus exact external user ID. App users reach them only through `user_fantasy_accounts`.
- Leagues are shared provider resources. Account history is represented through `fantasy_account_leagues`; current roster visibility additionally requires active league reachability.
- Rosters are shared league resources. Confirmed account ownership is explicit in `fantasy_account_rosters`, and every roster membership references both a canonical player and its exact source mapping.
- Scoring and league-format contexts are immutable. A league-format observation proves that one exact context was accepted for one league at one observation time.
- Existing `sync_runs` browser reads use explicit safe-column grants that omit `triggered_by_user_id`. Application reads filter explicitly by `league_discovery` in `src/lib/leagues/dashboard.server.ts` or `roster_sync` in `src/lib/rosters/dashboard.server.ts`; the corresponding partial unique indexes independently protect one running operation per account and scope.
- Provider-domain writes are performed only through reviewed owner-executing lifecycle functions. Browser roles and `service_role` have no direct provider-table mutation grants.

## Draft-domain absence

Before this task, Production and the baseline schema contain none of:

```text
fantasy_account_draft_collections
drafts
draft_slots
fantasy_account_drafts
draft_picks
```

There is no private draft stage or scope table, draft source request, draft normalization module, draft lifecycle RPC, Server Action, route, navigation item, product UI, ADP metric, ranking, or performance result. No live draft request is part of this task.

## Task 008A.2 scope

This task adds one architecture-only migration containing draft collection watermarks, five normalized public tables, conservative draft-environment identity, finalized-board and confirmed-participation protection, account-scoped historical RLS, explicit safe browser projections, and the independent `draft_sync` observability scope. It also adds exact pgTAP coverage, regenerated database types, and the architecture contracts required before Task 008B.

Task 008A.2 imports no rows, performs no provider request, adds no import lifecycle, and adds no product surface. Task 008B remains unstarted.
