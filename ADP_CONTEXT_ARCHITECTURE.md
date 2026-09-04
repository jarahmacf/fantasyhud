# ADP context architecture

This document is the engineering and product contract for future average-pick, ranking, and draft-capital analytics. It does not implement a metric, table, view, provider request, or product surface. Reviewed migrations remain the SQL source of truth.

## Core rule

ADP is a contextual query result, never a player property. `players` must not contain `adp`, `average_pick`, `market_adp`, `sleeper_adp`, `rank`, or `value` columns.

Exact provider `scoring_settings` are authoritative and define provider-specific immutable scoring identity. Broad labels and derived dimensions support filtering, compatibility matching, display, and diagnostics; they never replace the exact source object.

Semantic scoring compatibility is a separate FANTASY HUD identity. Its version-one effective-scoring projection preserves every known material scoring rule, including ordinary nonzero yardage, touchdown, turnover, first-down, kicking, team-defense, special-teams, IDP, bonus, and position-specific rules. Version one normalizes only explicitly allowlisted, reviewed additive-bonus rules whose value is numeric zero and numeric `rec_{fb,qb,rb,te,wr}` rules equal to numeric base `rec`. Unknown or malformed keys remain in a bounded exact fallback and therefore narrow matching instead of disappearing.

## Context layers

The layers remain distinct:

- **Scoring context:** exact scoring rules under a provider-specific fingerprint, plus a versioned provider-neutral semantic compatibility key that never replaces exact identity.
- **League format context:** scoring context plus exact ordered roster positions, an exact league-settings fingerprint, team count, roster size, best-ball state, roster-management type, independent quarterback format and IDP state, with exact league settings preserved as part of that immutable identity.
- **Draft environment:** a future Task 008A.2 concept that adds draft type, player pool, rounds, draft-specific settings, and context-resolution quality to a league format context.

Scoring and league format contexts are immutable and versioned. A change to exact scoring settings or another format-fingerprint dimension creates or reuses a different context. The normalization or classification version is part of context identity, so a classification change never updates an existing context in place.

## Exact and compatible format identity

Exact and compatible lineup concepts remain separate:

- `lineup_fingerprint` preserves the exact ordered roster-position array.
- `lineup_profile_fingerprint` hashes an order-independent, count-sensitive profile containing every exact slot token, including safe unknown tokens.
- `league_settings_fingerprint` hashes the canonical exact league-settings object with its provider and normalization version and participates in the exact format fingerprint.

The same slot counts in a different order may share a lineup profile while remaining different exact lineups. Different WR, TE, FLEX, bench, reserve, taxi, QB, IDP, or unknown-token counts never share a version-one lineup profile merely because roster size is equal.

Quarterback topology is independent from IDP. Version one records `quarterback_format` as `one_qb`, `superflex`, `two_qb`, `two_qb_superflex`, `no_qb`, `custom`, or `unknown`, while `has_idp` remains a separate boolean. An IDP Superflex league is therefore still Superflex and IDP rather than an `idp` quarterback family.

Format compatibility is a provider-neutral FANTASY HUD semantic key over the semantic scoring key, full lineup profile, team count, roster size, roster-management type, best-ball state, quarterback format, IDP state, reviewed draft-relevant league settings, and conservative unknown-settings fallback. Version one reviews numeric `type`, `best_ball`, `num_teams`, `capacity_override`, `draft_rounds`, `max_keepers`, `pick_trading`, `reserve_slots`, `reserve_allow_{cov,dnr,doubtful,na,out,sus}`, `taxi_slots`, `taxi_years`, `taxi_allow_vets`, and `taxi_deadline`; all other or malformed key-values enter the exact fallback fingerprint. A provider-neutral namespace defines FANTASY HUD semantics; it does not claim that a second provider is equivalent until that provider has a reviewed mapping to the same projection.

One shared version-one format classifier drives context creation and immutable-row insert validation. The insert boundary recomputes exact scoring linkage, exact league-settings and ordered-lineup fingerprints, lineup-profile fingerprint, exact format fingerprint, quarterback format, compatibility key, context quality, and derived dimensions. A source-supported version-one row cannot claim contradictory routing fields, and an unimplemented provider or version cannot claim exact quality.

Each league and source observation timestamp accepts at most one format context. An identical context-and-version replay is idempotent; a conflicting same-time context fails closed and rolls back the league source mutation, pointer, and observation together. A later accepted representation may append history, while an older stale representation changes neither pointer nor history.

## Semantic-integrity correction contract

The undeployed Task 008A.1 correction requires all twelve invariants together:

1. Exact scoring identity preserves every exact source rule.
2. Semantic scoring compatibility preserves every material scoring difference.
3. Only reviewed semantic no-ops normalize together.
4. Exact format identity includes exact league-settings identity.
5. Format compatibility uses a full count-sensitive lineup profile.
6. Exact lineup order and compatible lineup composition remain separate concepts.
7. Quarterback format and IDP remain independent dimensions.
8. Unknown scoring or league settings narrow matching rather than create false compatibility.
9. One league observation time accepts one format context.
10. Every context row is fully validated before immutable insertion.
11. Provider-neutral compatibility keys identify FANTASY HUD semantics and do not prove two providers have already been mapped.
12. Context fallback is never silent.

## Sample universes

Future metrics use one of these explicit values:

- `portfolio`: confirmed drafts for the selected tracked fantasy account.
- `fantasyhud_sleeper_network`: deduplicated canonical Sleeper drafts imported across FANTASY HUD users.
- `external_market`: an independently licensed and named data source.

Sleeper's documented public API does not provide a public Sleeper-wide aggregate ADP feed. The FANTASY HUD imported-user sample must never be labeled `Sleeper platform ADP`, `Sleeper global ADP`, or `All Sleeper drafts`.

## Required metric key

Every future ADP or average-pick result is keyed by:

- `player_id`
- `sample_universe`
- one of `scoring_context_id`, `league_format_context_id`, or the future `draft_environment_id`
- `season`
- `draft_type`
- `draft_pool_type`
- `team_count`
- `date_window` or `as_of`
- `eligibility_version`
- `context_match_version`
- `position_group_version`
- `central_tendency_method`

No result is a context-free property of a player.

## Context matching

The future matching order is:

1. `exact_draft_environment`
2. `exact_league_format`
3. `exact_scoring_compatible_format`
4. `compatible`
5. `broad`
6. `unscoped`, only when explicitly requested

Every result displays its match level, sample size, context label, and methodology version. A query never silently moves down this ladder. Missing exact data is not zero; the product returns no exact value or offers a clearly labeled broader cohort. Unknown scoring or league settings never justify a broader match.

## Eligibility

Default pick-ADP eligibility requires:

- a source-complete finalized board
- a snake or linear draft
- a valid exact pick number
- a non-keeper pick by default
- a known player pool
- one canonical provider draft counted once

Auction drafts route to average auction value, not pick ADP. Rookie drafts, dynasty startups, redraft drafts, supplemental drafts, unknown pools, and keeper-influenced boards remain separate cohorts. Keeper picks are separately filterable and excluded from standard market-style ADP by default.

## Raw and derived ADP metrics

A future context-specific result may contain:

- mean overall pick
- median overall pick
- earliest and latest pick
- standard deviation
- unique draft count
- pick count
- overall ADP rank
- positional ADP rank
- context label
- `as_of` time or date window
- match level
- methodology version

The unique draft count, pick count, date window, and context match level are part of the metric, not optional explanatory detail.

Positional ADP rank is derived rather than provider-supplied:

```text
eligible complete drafts
→ one deduplicated context-specific ADP value per player
→ versioned draft-time position group
→ ordered players within that group
→ positional ADP rank
```

The result is keyed by sample universe, context, season, the draft cohort expressed by `draft_type` and `draft_pool_type`, date window or as-of time, central-tendency method, and position-group methodology version. The selected central tendency—such as mean or median—must be disclosed and must drive both the player ADP value and the ordering derived from it. Tie behavior, central-tendency behavior, and position grouping are versioned. A provider-supplied `RB17`, `WR9`, or `QB4` label is not required, and no universal positional ADP rank is persisted on `players`.

Metrics begin as reviewed SQL views or application queries. Persistence is not required. Materialization is allowed only after measured need and an explicit refresh contract.

## Time and leave-one-out comparison

Current ADP uses the latest eligible context-specific snapshot. An at-time pick comparison uses the nearest prior eligible snapshot or a prior-only draft sample and only information available at or before the draft or pick time.

The subject draft is excluded from its comparator sample. A FANTASY HUD network comparison also supports excluding the current user's canonical portfolio drafts. Future information or an end-of-season aggregate cannot be presented as an at-time comparison unless it is explicitly labeled as hindsight.

## Network methodology and privacy

The same shared draft imported through several app users counts once, deduplicated by canonical provider draft ID. Cross-user aggregates require a reviewed minimum unique-draft threshold and suppression behavior before display. They must not expose another user's draft, slot, identity, or unique small-cohort behavior.

## Player pages

A future player page selects one context. Changing that context recomputes every context-dependent value, including portfolio results, network results, differences, ranks, sample sizes, and match labels.

An example display contract is:

```text
Context:
12-team · Half-PPR · Best ball · 1QB · Redraft · Snake

Portfolio average pick:
18.3 · RB7 · 4 unique drafts

FANTASY HUD Sleeper sample:
16.7 ADP · RB6 · 842 unique drafts

Difference:
+1.6 picks later

Match:
Exact

As of:
2026-08-25
```

There is no global player ADP field.

## Rankings, projections, and external markets

Future `player_scoring_snapshots`, `player_ranking_snapshots`, `market_adp_snapshots`, and `market_adp_values` use or resolve through the same context architecture. Rankings and ADP are not combined across scoring paradigms by default.

Every future external-market contract includes source, platform, sample universe, as-of time, format or scoring context, match level, sample size, and methodology version. No ambiguous universal market ADP snapshot is allowed.

## Draft-capital weighting

Raw pick number remains exact. A future normalized draft-capital methodology is versioned and accounts for board size, team count, round count, draft type, context, and keeper status. Auction amounts are never compared directly with snake or linear pick numbers.

## Current implementation boundary

Task 007B.2 is deployed and Production-verified. The current undeployed Task 008A.1 draft branch introduces scoring contexts, corrected exact and semantic format identity, append-only one-context-per-time observations, and the contracts in this document. Its semantic-integrity correction amends the same unmerged migration; none of these context rows are Production state. It implements no draft table, pick table, ADP metric, new provider request, route, or product UI. Task 008A.2 has not begun.
