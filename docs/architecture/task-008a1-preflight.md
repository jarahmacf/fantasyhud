# Task 008A.1 preflight

Verified on 2026-09-01 before scoring- and format-context editing.

## Baseline and delivery state

- Exact baseline: `d64d16a868538fea28f7dfc568be05fcfb962934`
- Branch: `task/008a1-scoring-format-context`
- Working tree: clean at branch creation
- Open pull requests at branch creation: none
- Baseline GitHub CI: run 33580900897, completed successfully on the exact baseline
- Vercel Production: `Ready` on `main` at the exact baseline
- Supabase project: `fantasyhud-development`, `main` Production branch
- Latest deployed migration: `20260901210000_current_season_sleeper_roster_sync.sql`

## Sanitized hosted starting state

The audit used stored Production rows only. It made no provider request and performed no write.

```text
current Sleeper league season                    2026
canonical current-season leagues                   30
active account-to-league associations              30
active current-season league users                387
active current-season rosters                     372
active confirmed owned rosters                     30
active current-season memberships               7,196
active owned-roster memberships                   616

canonical player entities                      12,225
active primary Sleeper player mappings         12,225
successful global player catalog runs               1
terminal roster-sync runs                           2
running roster-sync runs                            0
private roster-sync scope rows                      0
private roster-sync stage rows                      0
Sleeper accounts with last_synced_at                0
```

The existing `fantasy_accounts.last_synced_at` portfolio-completeness boundary remains untouched.

## Absence and scope gates

Before this task:

- `public.scoring_contexts` did not exist.
- `public.league_format_contexts` did not exist.
- `public.league_format_observations` did not exist.
- No prior broad Task 008A scoring/format-context implementation was present.
- No draft, draft-pick, ADP, ranking, or market relation existed in `public` or `app_private`.
- No Task 008A.2 draft-domain implementation had begun.

The stored scoring audit passed before implementation. Its sanitized evidence is recorded in `docs/verification/task-008a1-scoring-context-audit.md`.
