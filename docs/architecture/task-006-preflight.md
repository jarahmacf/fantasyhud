# Task 006 preflight

Recorded on 2026-08-31 before implementation from a clean working tree.

## Baseline and delivery state

- Repository: `jarahmacf/fantasyhud`
- Branch: `task/006-current-season-league-discovery`
- Baseline: `364f5c2bab449005fa81bde417c74da63f673b66`
- Supabase project: `fantasyhud-development`
- Latest hosted migration: `20260831070614_harden_core_fantasy_data_architecture.sql`
- Vercel Production: Ready on baseline `364f5c2`
- Existing Production connection: the primary `@jarahmacf` Sleeper identity loaded successfully

## Hosted schema and grants

The hosted Task 005.1 audit returned zero rows in each provider-data parent table:

| Table                     | Rows |
| ------------------------- | ---: |
| `provider_season_states`  |    0 |
| `leagues`                 |    0 |
| `fantasy_account_leagues` |    0 |
| `sync_runs`               |    0 |

The corrected removal constraint requires `removed_at is null or removed_at >= last_seen_at`. `service_role` had zero direct `SELECT`, `INSERT`, `UPDATE`, or `DELETE` privileges across the four tables. Authenticated read grants and all four indexed select policies remained present; authenticated mutations remained denied.

Because `leagues` was empty, Task 006 can add required `fetched_at` without inventing historical timestamps. The additive migration also makes `provider_updated_at` nullable because Sleeper publishes no reliable league-level update timestamp.

## Source verification

Official Sleeper documentation was reviewed for the NFL state and user-leagues endpoints, read-only/no-token behavior, canonical user-ID use, response structure, and commercial-use dependency. A sanitized live source audit could not be completed on this host before implementation; see `docs/verification/task-006-sleeper-league-source.md`.

The pull request must remain draft while that source row is blocked. No canonical user ID, real league ID, league name, avatar, draft ID, settings payload, scoring payload, roster positions, or raw response was recorded or committed.

## Local database capability

This host has neither Docker nor Podman, so the container-backed local Supabase reset, pgTAP, generated-type refresh, and authenticated browser suite cannot run here. The credential-free GitHub Actions database job remains the authoritative executable database gate for this branch.
