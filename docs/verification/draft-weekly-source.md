# Draft and weekly source feasibility — 2026-09-09

This is an implementation audit for PR 17, not evidence that imports or weekly tracking have deployed. Production was inspected read-only. No production schema or provider rows were changed during development.

## Draft source

[Sleeper's public API](https://docs.sleeper.com/) documents league draft lists, account season draft lists, draft detail, and complete picks. The adapter uses only those four read-only endpoints. The account list returned 49 drafts across snake and auction types during this audit. This is an observed account collection count, not a claim that every league has one draft or that every board is finalized. One sampled completed snake board contained 264 picks; its keeper flags were null. The sampled auction board contained zero picks, so that sample cannot establish an auction price field.

The source terms describe token-free noncommercial use and direct commercial licensing inquiries. This personal prototype audit does not establish commercial redistribution rights. No undocumented player statistics, consumer ranking, or ADP endpoint is used.

The collector limits each response to 10 MB while streaming, the complete collection to 40 MB, concurrent source work to four requests, and the union to 1,000 drafts. It validates canonical string identities and exact season membership. A failed list is never an empty list. Auction amount remains null until an actual numeric source field is audited. Numeric `settings.player_type` is retained exactly but its undocumented enum semantics do not establish a player-pool label.

## Weekly statistics candidate

The [nflverse data repository license](https://github.com/nflverse/nflverse-data/blob/main/LICENSE.md) is CC BY 4.0. Source attribution and a description of transformations must accompany any use. This observation does not extend to separately licensed FTN or other third-party datasets.

The [maintained player-statistics dictionary](https://nflreadr.nflverse.com/articles/dictionary_player_stats.html) identifies players by GSIS ID and provides weekly raw box-score categories. The [loader source](https://github.com/nflverse/nflreadr/blob/main/R/load_stats.R) distinguishes weekly data from season aggregates. Both `player_stats` and `stats_player` release assets were inspected; neither exposed a 2026 asset at audit time. A fetch must return unavailable for the requested season rather than substitute 2025.

The [update schedule](https://nflreadr.nflverse.com/articles/nflverse_data_schedule.html) describes updates after game days and subsequent corrections, with Thursday recommended for the cleanest corrected data. These are revisable observations, not immutable final results. A future importer must record retrieval time, source asset identity, content fingerprint, and calculation version. It must not fabricate a provider revision timestamp from request time.

The documented nflreadr `load_players` source points to the nflverse `players/players.csv` release. A bounded read on 2026-09-09 returned 24,826 unique GSIS IDs and 16,558 nonempty, unique ESPN IDs (7,288,330 bytes; SHA-256 `a61c2e436918655b0e2df9644a5fe93ea06b3b99371352275c84d0c9230c738a`). This establishes an exact-ID crosswalk source, not portfolio or full-universe mapping coverage.

Canonical mapping is feasible but not yet verified end to end: the existing catalog has 6,718 active ESPN and 11,546 Sportradar mappings, but no GSIS namespace. A reviewed GSIS crosswalk must resolve through exact source IDs with collision and missing-identity reports. Player names cannot be a fallback join. The complete positional universe must be mapped, including unowned players; ranking only the portfolio would be invalid.

## Exact scoring coverage

The stored league rules include reception-distance bins, long-touchdown bonuses, interception-return touchdowns, offensive special-team fumbles/recoveries, positional reception bonuses, kicking, and defense rules. Basic weekly offensive totals do not establish every required event count. Summing only rushing, receiving, and sack fumbles is not proof of total fumbles lost because other play types exist.

`src/lib/statistics/weekly-scoring.ts` implements and tests a deliberately bounded box-score scoring subset. It supports the documented passing/rushing/receiving columns and additive RB/WR/TE reception bonuses. Every nonzero unsupported or malformed rule blocks the result. Missing statistics remain missing; explicit zero is distinct. It never uses `fantasy_points_ppr`, silently drops bonus rules, or publishes a complete-universe rank.

The source gate is **not approved for full automatic league-specific rankings**. Still required: audited play-by-play or another authorized source covering the missing categories; exact canonical crosswalk coverage; games-played and full-universe rules; team-defense and IDP coverage; correction-revision storage; and availability for the requested season. No statistics table, scheduled refresh, or automatic performance claim is justified by this audit alone.

## Current product boundary

The manual price-implied-rank calculator remains usable. Draft source collection and publication are under isolated verification. Draft import does not create historical ADP/AAV snapshots, prove a known draft pool, or repair unknown keeper evidence. Those facts remain independent requirements for an at-draft price benchmark. Temporary workspace access remains read-only: the authenticated import orchestrator does not impersonate an Auth user or permit anonymous writes.
