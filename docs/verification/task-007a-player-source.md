# Task 007A Sleeper player-source verification

Status: **AWAITING CONTROLLED POST-MERGE PLAYER-CATALOG CANARY**

Prepared on 2026-08-31. This document deliberately contains no live player ID, player name, profile row, secondary ID, or source payload.

## Official contract evidence

Sleeper's official API documents a read-only, token-free full NFL player endpoint:

```text
GET /v1/players/nfl
```

The documentation describes a large map keyed by player ID, recommends retaining player IDs as canonical identifiers, and recommends limiting full retrieval to about once per day. Sleeper describes the API as free for noncommercial use; commercial operation therefore retains a licensing dependency.

## Fabricated fixture evidence

Deterministic tests cover a 600-record authenticated import and a separate 5,000-record local database load. Fabricated sentinels exercise an ordinary player, inactive player, team defense, dual-position player, injury data, sparse unknown entity, padded display labels, safe string and numeric secondary IDs, malformed optional values, ambiguity, conflict, replacement, primary reactivation, source absence, monotonic profile freshness, idempotent batch replay, and 24-hour global reuse.

Tests assert only aggregate and category behavior. No test calls the real Sleeper API or commits a production response.

## Controlled post-merge canary gate

After the migration and application commit deploy from `main`, one signed-in connected account must trigger the Production refresh. Record only:

- source byte and record-count ranges
- aggregate player, active, team-defense, unknown, mapping, and warning counts
- optional warning field categories
- sanitized source/catalog fingerprints
- run status, progress, duration, and staging cleanup
- repeated-within-24-hours request suppression

The canary must confirm one active primary Sleeper mapping per observed entity, no duplicate exact mappings, no ambiguous/conflicting auto-merge, readable authenticated profiles, no portfolio synchronization timestamp update, and no roster, draft, matchup, ranking, market, or ownership rows created by this task.

Live aggregates have not yet been observed. Fixture evidence is not represented as source-shape proof.
