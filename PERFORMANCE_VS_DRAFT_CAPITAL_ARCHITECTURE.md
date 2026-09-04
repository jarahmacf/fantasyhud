# Performance versus draft capital architecture

This document is the engineering and product contract for future comparisons between draft investment and player outcomes. It does not implement a statistics source, scoring engine, rank, performance table, metric, provider request, or product surface. Reviewed migrations remain the SQL source of truth.

## Purpose and analytical levels

FANTASY HUD will compare draft investment with in-season and final outcomes at these explicit levels:

- pick
- player
- NFL team at draft
- draft or fantasy roster
- league
- overall tracked portfolio

The comparison always preserves the immutable draft pick, its exact draft environment, the eligible ADP sample available at the comparison time, the outcome's exact scoring context, and the versions of every ranking, capital, and expected-outcome methodology. Permanent source-table flags such as `outperformed_adp`, `was_a_hit`, `was_a_bust`, and `season_alpha` are prohibited.

## Context integrity prerequisite

Exact provider context identity and semantic compatibility are different contracts. Exact scoring identity preserves the complete provider source object. Semantic scoring compatibility preserves every material rule, normalizes only reviewed no-ops, and retains unknown or malformed values through bounded conservative fallback. Exact league-format identity includes exact league-settings identity and ordered lineup identity; compatible format routing uses every slot token and count, reviewed draft-relevant settings, independent quarterback format and IDP state, and conservative unknown-settings fallback.

Provider-neutral compatibility keys are versioned FANTASY HUD semantic identities, not proof that two providers are already equivalent. A second provider requires its own reviewed mapping. No performance cohort silently broadens when exact matching is unavailable, and unknown context makes a cohort narrower rather than broader.

## Separate statistical, scoring, and ranking layers

Raw football statistics, context-specific fantasy scoring, and context-specific rankings are different grains:

```text
authorized raw football statistics
→ canonical player identity mapping
→ versioned scoring engine
→ exact scoring-context fantasy result
→ typed context-specific ranking
```

A raw stat line is not duplicated for every league. A scoring result is computed or persisted once for each unique exact scoring context and period, then reused by every league sharing that context.

## Future source and result grains

These grains are planned contracts. Task 008A.1 creates no performance or statistics table.

### `player_stat_snapshots`

Grain:

```text
one canonical player
+ statistics source
+ sport
+ season
+ season type
+ week or period
+ source revision or as-of time
```

This is raw football statistical truth, not league-scored fantasy points. Each fact preserves:

- exact statistics-source identity
- exact period
- source timestamp
- source fingerprint or revision identity
- a bounded exact source-stat object or reviewed typed facts

Corrections create a traceable source revision or as-of state; they do not silently rewrite the historical input used by a reproducible scoring result.

### `player_scoring_snapshots`

Grain:

```text
one canonical player
+ scoring_context_id
+ statistical period or through-week
+ statistics source
+ scoring_engine_version
```

A result may include weekly fantasy points, season-to-date fantasy points, games played, fantasy points per game, scored-through week, source as-of time, and calculation time. It resolves from the authorized raw-stat grain through one versioned scoring engine and the exact immutable scoring context. One result is reused by every league sharing that scoring context.

### `player_ranking_snapshots`

Grain:

```text
one scoring-result universe
+ ranking type
+ versioned position group
+ period
+ player
```

Every ranking result identifies:

- `scoring_context_id`
- `season`
- `through_week` or `as_of`
- `season_type`
- `ranking_type`
- `position_group`
- `position_group_version`
- an explicit minimum-games or minimum-opportunities rule when applicable
- statistics source
- `scoring_engine_version`
- `ranking_methodology_version`

Ranking results may begin as reviewed SQL views. Stored snapshots are justified only by historical reproducibility, source-revision requirements, or measured query performance.

## Statistics-source policy

The documented public Sleeper API must not be assumed to supply player statistics, season rankings, projections, or ADP. Consumer-facing Sleeper scores or rankings and undocumented endpoints do not establish a stable, authorized public API contract. `players.search_rank` remains search metadata only.

Before implementing any statistics or performance grain, a separate source-feasibility and licensing task must verify:

- authorization and commercial-use rights
- canonical player-ID coverage and mapping quality
- correction and revision semantics
- weekly and season-to-date availability
- historical depth
- team-defense and IDP support
- coverage of the stat categories required by every stored scoring context
- latency and update cadence

The preferred path is an authorized raw NFL-statistics source mapped to canonical players, followed by a versioned scoring engine and exact scoring-context results. A provider-supplied default PPR rank without its exact scoring definition is not a substitute for league-specific performance analytics.

## Position-group contract

Draft positional ADP rank uses a versioned position group derived from immutable draft-time position context. Season positional rank uses a separately versioned outcome position group for that statistical period. Historical picks must not silently join to current `players.primary_position`.

For a player with changed or dual-position eligibility, preserve every source position and disclose whether the methodology uses the primary source position, all eligible fantasy positions, or one normalized analytics position group. The default selection and tie behavior are versioned.

## Required ranking types

At minimum, keep these ranking types separate:

- `season_total_points_rank`
- `season_points_per_game_rank`
- `overall_total_points_rank`
- `overall_points_per_game_rank`

A points-per-game rank requires an explicit minimum-games or minimum-opportunities rule. No result may be labeled only `season_rank`, and total-points rank must never silently substitute for points-per-game rank.

## Player-level performance metrics

The first player display contract includes:

- draft overall pick
- context-specific overall ADP
- context-specific positional ADP rank
- season-to-date positional rank
- final positional rank
- position-rank delta
- draft-capital percentile
- outcome percentile
- percentile delta
- actual fantasy points
- expected fantasy points
- points above expectation
- actual fantasy points per game
- expected fantasy points per game

Position-rank delta is:

```text
position_rank_delta
= adp_position_rank - outcome_position_rank
```

A positive value means the player finished better than drafted. This player-level explanation is useful, but raw positional-rank differences are not additive across positions or contexts. An outcome may be compared only with ADP from the same disclosed context or an explicitly requested and displayed broader match level. A league observation conflict cannot be resolved by choosing either same-time context: Task 008A.1 permits one accepted format context per league and observation time and fails the enclosing mutation closed.

## Expected-outcome curve

Cross-position analysis uses a context-specific, versioned expected-outcome curve based on normalized draft capital. The methodology identifies:

- training seasons
- eligible draft classes and player pools
- context matching and fallback level
- draft-capital normalization
- outcome metric
- injury and availability treatment
- minimum sample
- methodology version

The curve may support draft-capital percentile, outcome percentile, percentile delta, points above context-specific expectation, points-per-game above expectation, and normalized capital efficiency. One arbitrary finishing-rank cutoff does not define a hit or bust.

Raw pick number remains exact. Cross-format capital normalization accounts for board size, team count, round count, draft type, context, player pool, and keeper status. Auction values use a separate AAV methodology and are never compared directly with snake or linear pick numbers.

## Aggregation rules

Every aggregation discloses context, time, eligibility, sample size, and methodology versions. One canonical provider draft counts once in network samples, while portfolio ownership follows explicit future `fantasy_account_drafts` associations.

### Pick

Compare one immutable pick's normalized investment with its context-scored outcome and the expected-outcome curve that was eligible for that pick. The ADP comparator excludes the subject draft and uses only information available at or before the subject pick.

### Player

Aggregate confirmed portfolio picks for one canonical player. Expose unique drafts, average and median pick, average normalized capital, season outcome, and capital efficiency. Never multiply-count one canonical shared draft because several app users imported it.

### NFL team

Group original investment by immutable `nfl_team_at_draft`, not only the player's current NFL team. A current-team view may be shown separately but cannot rewrite the original allocation or outcome grouping.

### Draft, fantasy roster, or league

Aggregate only picks explicitly attributed to the tracked account's confirmed draft slot. The complete draft board remains the comparator universe and does not imply portfolio ownership. League aggregation preserves the draft environment and each outcome's scoring context rather than silently pooling incompatible formats.

### Portfolio

Support total invested normalized capital, actual versus expected fantasy points, capital efficiency, hit rate, bust rate, position allocation, and NFL-team-at-draft allocation. Hit and bust definitions are versioned results of the expected-outcome methodology, not permanent source-table booleans.

Cross-position, NFL-team, league, and portfolio results use a comparable scale such as draft-capital percentile, outcome percentile, points above context-specific expectation, points per game above expectation, or normalized capital efficiency. They never sum raw RB, WR, QB, TE, or IDP rank deltas as though those ranks shared one additive unit.

## Time contract

Every performance result is explicitly `through_week` or `final` and contains `source_as_of` and `metric_calculated_at`. A through-week result identifies the exact week; an in-season outcome through Week 6 is never labeled final.

An at-draft comparison uses only ADP snapshots or comparator drafts available before the subject pick. Later drafts, later source revisions, and end-of-season aggregates cannot enter an at-time result unless the product explicitly labels the result as hindsight.

## Availability and injury

Keep total production and per-game production as separate outcome views. Per-game results disclose their minimum-games or minimum-opportunities rule. Availability-adjusted analysis is a separate versioned methodology.

The product must show which outcome definition is in use and must not silently classify an injured or otherwise unavailable player with the same measure as a healthy underperformer. Injury treatment is also explicit in every expected-outcome-curve version.

## Dynamic player-page contract

A future player page can show:

- selected scoring and format context
- portfolio average pick
- portfolio positional ADP rank
- FANTASY HUD sample ADP
- FANTASY HUD sample positional rank
- season total-points rank
- season points-per-game rank
- position-rank delta
- points above expected
- unique draft sample
- through week or final state
- context match level
- source as-of time and methodology versions

Changing the scoring or format selector recomputes every context-dependent field. There is no global player ADP, universal current rank, or context-free performance result.

## No premature persistence

Begin with authorized source facts, reviewed context-specific scoring results, and queryable views. Do not create one giant mutable performance table.

Materialize or snapshot only when historical reproducibility requires it, source revisions require an as-of record, or measured query performance requires it. Any persisted result retains the exact source, context, period, sample, and methodology versions needed to reproduce its meaning.

## Current implementation boundary

Task 007B.2 is deployed and Production-verified. Task 008A.1 documents this future performance-versus-capital model while its corrected context migration remains undeployed. It implements no raw-stat import, scoring engine, scoring snapshot, ranking snapshot, performance metric, or product UI. Task 008A.2 has not begun.
