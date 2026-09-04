# Conceptual data model

This document summarizes the conceptual model. `FANTASY_DATA_ARCHITECTURE.md` is the long-term grain and history contract, and reviewed migrations remain the SQL source of truth.

## Entities

- **App user:** A person who uses FANTASY HUD.
- **Fantasy account:** One shared provider identity keyed by provider and external user ID.
- **User-to-fantasy-account link:** An app user's tracked association to a shared fantasy account.
- **League:** A shared fantasy competition from a provider.
- **Provider season state:** The latest shared season and period state for one provider and sport.
- **Scoring context:** One immutable, versioned provider-specific identity for exact scoring rules plus a separate conservative FANTASY HUD semantic compatibility identity.
- **League format context:** One immutable, versioned identity for a scoring context, exact ordered lineup, exact league settings, and league-level draft-relevant dimensions, with a separate count-sensitive compatibility profile.
- **League format observation:** One append-only accepted format context for one league and source observation time; a contradictory context cannot share that league-time identity.
- **Account-to-league discovery:** The observation that a provider reported a shared league for a tracked fantasy account. Its presence alone does not prove roster ownership; paired account/league resolution status and observation time record that truth separately on the same association.
- **League user:** One provider user identity as represented within one league.
- **Roster:** A team roster within a league.
- **Account-to-roster ownership:** One explicit tracked fantasy-account association to one roster in one league.
- **Roster-player membership:** One canonical player's current membership on one roster, including source-grounded starter, reserve, taxi, and keeper state.
- **Player:** One shared canonical football entity with a mutable current profile; this may be an individual, team defense, or sparse unknown entity.
- **Player external identity:** One exact namespace, sport, and external ID mapped historically to one canonical player.
- **Provider catalog run:** One global provider, sport, catalog resource, and refresh attempt.
- **Draft environment:** A future Task 008A.2 identity for one league format context plus draft type, player pool, rounds, draft-specific settings, and context-resolution quality.
- **Draft:** One canonical provider draft associated with a league or provider context and the contemporaneous draft environment that can be resolved for it.
- **Account-to-draft membership:** The association between a connected account and a draft.
- **Complete draft board:** The full ordered set of selections from every drafter.
- **Draft pick:** One selection at an exact position in a draft.
- **Player-stat snapshot:** One canonical player's raw football statistics from one source, sport, season, season type, statistical period, and source revision or as-of observation.
- **Player-scoring snapshot:** One canonical player's calculated fantasy result for one exact scoring context, statistical period, statistics source, and scoring-engine version, reusable by every league with that context.
- **Player-ranking snapshot:** One player's typed rank within one exact scoring-result universe, period, and versioned outcome position group.
- **Performance-versus-draft-capital result:** A derived, versioned comparison of immutable draft investment with a context-scored through-period or final outcome; it is not a mutable source field.
- **Matchup:** A scoring comparison for a roster and period.
- **League-standing snapshot:** One roster's source or versioned standing within one league, season, and scoring period or snapshot time.
- **Sync run:** One traceable attempt to import or reconcile provider data.

## Implemented fantasy-data grains

- `provider_season_states`: one latest state row per provider and sport.
- `leagues`: one shared league per provider and exact external league ID, including the latest published complete roster-bundle watermark.
- `fantasy_account_leagues`: one discovery association per fantasy account and shared league, including nullable `owned`, `not_owned`, or `unresolved` roster-ownership resolution and its observation time.
- `sync_runs`: one tracked fantasy account, scope, and attempt.
- `players`: one shared canonical NFL entity and mutable current profile.
- `player_external_ids`: one exact historical namespace, sport, and external ID mapping.
- `provider_catalog_runs`: one global provider, sport, catalog resource, and attempt.
- `league_users`: one provider user identity as represented within one canonical league.
- `rosters`: one league-local current provider roster with exact nullable source arrays that distinguish absent from explicitly empty.
- `fantasy_account_rosters`: one explicit tracked-account ownership association to one roster in one league.
- `roster_players`: one canonical player's current membership on one roster, tied to its exact source identity mapping.

Task 006 populates these grains for the first time through one validated current-season Sleeper collection. `leagues.fetched_at` is the required observation time. Shared provider state and league representations are monotonic by this time, while account associations remain independent observations. `leagues.provider_updated_at` remains nullable, is never replaced with request time, and is not erased by a null incoming value.

Task 007B.2 populates the four roster-domain grains through one frozen current-season scope and one complete validated users-and-rosters bundle per expected league. Exact source arrays remain beside normalized membership. `players` is the membership authority; null preserves prior confirmed normalized state while explicit empty confirms absence. `leagues.roster_bundle_fetched_at` records the latest fully validated users-and-rosters collection published for the shared league. Shared league users, rosters, memberships, annotations, and removals advance only when the incoming complete bundle is at least as fresh as that watermark, so an older collection cannot resurrect a resource that a newer collection proved absent. Per-row freshness checks remain defense in depth.

Roster ownership resolution is account/league state on `fantasy_account_leagues`, with paired `roster_ownership_status` and `roster_ownership_observed_at`. The status is `owned`, `not_owned`, `unresolved`, or null when never evaluated. Resolution reads the current canonical shared rosters at the league roster-bundle watermark. A preserved `fantasy_account_rosters` row under `unresolved` remains historical account state, not current confirmed ownership. Current owned-roster and holdings reads require the matching account/league status to be `owned`.

The browser authorization path is `auth user → user_fantasy_accounts → fantasy account → fantasy_account_leagues → league`. Browser roles receive read-only, RLS-scoped access. Provider data is written only through reviewed service-only RPCs; `service_role` has no direct provider-table CRUD.

The canonical player catalog is globally readable to an authenticated app user after the application confirms a tracked Sleeper account. It is not owned by one fantasy account. Global catalog-run status is browser-readable only through explicitly granted safe columns. Its `triggered_by_user_id` records server-only audit and run-ownership state and is not browser-selectable; source freshness and active-run uniqueness are global to Sleeper/NFL/players.

## Planned fantasy-data grains

- `scoring_contexts`: one immutable exact scoring identity per provider, sport, normalization version, and provider-specific scoring fingerprint. Exact source JSON is authoritative. A separate `fantasyhud:nfl:scoring_compatibility` semantic key preserves every material rule, normalizes only reviewed no-ops, and includes bounded fallback for unknown or malformed source values.
- `league_format_contexts`: one immutable exact league-format identity per version and format fingerprint. It references one scoring context and preserves exact ordered roster positions, an exact league-settings fingerprint and source object, team count, roster size, roster-management type, best-ball state, independent quarterback format and IDP state, context quality, and versioned compatibility dimensions. Its dedicated count-sensitive `lineup_profile` retains every exact slot token and count.
- `league_format_observations`: one accepted league + observation time event carrying one format context, source, and normalization version. Exact replay is idempotent; a conflicting same-time context fails closed, and history begins at the first known stored observation.
- `player_stat_snapshots`: one canonical player + statistics source + sport + season + season type + week or period + source revision or as-of observation. It preserves raw football statistics and their exact source identity, timestamp, and fingerprint independently of fantasy scoring.
- `player_scoring_snapshots`: one canonical player + exact scoring context + statistical period or through-week + statistics source + scoring-engine version. One context result is reused across every league sharing that exact scoring identity.
- `player_ranking_snapshots`: one scoring-result universe + typed rank + versioned outcome position group + period + canonical player. Required context includes scoring context, season, through-week or as-of time, ranking type, position group and version, any minimum-games rule, statistics source, scoring-engine version, and ranking-methodology version.
- `league_standing_snapshots`: one league + season + scoring period or snapshot time + roster. It preserves source or versioned standings when immutable facts alone cannot reproduce provider and commissioner rules.

Task 008A.1's current undeployed draft branch introduces only the scoring and league-format context grains, `leagues.current_format_context_id`, immutable owner-only helpers, atomic league-discovery integration, scoped RLS, and safe derived projections. Its pre-deployment correction makes exact league settings part of format identity, separates ordered lineup identity from count-sensitive compatibility, keeps QB topology independent from IDP, fully recomputes immutable insert fields, and permits only one context per league observation time. It also establishes the future contracts in `ADP_CONTEXT_ARCHITECTURE.md` and `PERFORMANCE_VS_DRAFT_CAPITAL_ARCHITECTURE.md`. It creates no player-stat, player-scoring, player-ranking, performance-result, draft, pick, market, or ADP-metric table or data, and those future grains remain conceptual. The context tables are not Production state until the amended migration is reviewed, merged, and verified.

## Future draft context contract

Task 008A.2 must give every draft a `league_format_context_id`, `context_resolution_status`, `context_observed_at`, `draft_environment_fingerprint`, `draft_environment_version`, and `draft_pool_type`. Resolution status is `exact`, `partial`, or `unknown`. Current league context cannot be assigned to a historical draft as exact unless a contemporaneous source relationship is verified.

Each future `draft_picks` row inherits context through its parent draft. Picks contain exact source facts, not duplicated mutable ADP fields; pick-level comparator results remain derived or explicitly versioned analytics.

Future external market data requires source, platform, sample universe, as-of time, format or scoring context, match level, sample size, and methodology version. No universal market ADP snapshot is valid.

Future picks preserve NFL team at draft and enough source position eligibility to reproduce a versioned draft-time primary or normalized position group. A present-day player profile never rewrites that historical team or position context.

## Future performance context contract

Raw football statistics, exact-context fantasy scoring, and player rankings use separate grains. Scoring results are calculated or sourced once per unique scoring context and period and reused across leagues. Rankings are always typed and through-period: total points and points per game, positional and overall, remain distinct, and points-per-game ranks disclose their minimum-games or minimum-opportunities rule. There is no universal season rank on `players`.

Draft positional ADP rank is derived from contextual player ADP within a versioned draft-time position group; it is not supplied as a permanent label such as `RB17`. Outcome rank uses a versioned position group for the scoring period. All eligible source positions are preserved for dual-position players, and the method discloses whether it selects a primary source position or one normalized analytics group.

At player grain, `position_rank_delta = adp_position_rank - outcome_position_rank`, so positive means the player finished better than drafted. Rank delta is a display measure, not an additive cross-position or portfolio unit. Higher-grain results use a comparable versioned unit such as capital percentile, outcome percentile, points above context-specific expectation, points per game above expectation, or normalized capital efficiency.

Expected-outcome results disclose training seasons, eligible draft classes, context matching, capital normalization, outcome metric, injury or availability treatment, minimum sample, and methodology version. At-draft comparisons use prior-only information and exclude the subject draft. Every outcome is explicitly through-week or final and carries source-as-of and calculation times; total and per-game production remain separate.

Aggregation is explicit at pick, player, NFL team at draft, draft, fantasy roster, league, and tracked-portfolio grain. Player aggregation includes only confirmed portfolio picks and reports unique drafts. NFL-team allocation groups original capital by NFL team at draft, with current team as a separate view. Draft, fantasy-roster, and league ownership includes only picks attributed through the tracked account's confirmed draft slot; the complete board remains a comparator. Network aggregation deduplicates canonical provider drafts and observes privacy suppression. Portfolio summaries use normalized capital and versioned expected-outcome measures rather than summing raw positional-rank deltas.

Before any statistics, scoring, ranking, or performance implementation, a separate source-feasibility task must verify authorization and commercial use, player-ID coverage, correction and revision semantics, weekly and season-to-date availability, historical depth, team-defense and IDP support, every statistic required by stored scoring contexts, and update latency. The documented public Sleeper API, consumer ranking surfaces, `search_rank`, and undocumented endpoints are not assumed to be a supported statistics, projection, rank, or ADP contract. The preferred path is authorized raw NFL statistics → canonical player mappings → versioned scoring engine → exact scoring-context results → typed rankings.

These analytics begin as immutable source facts, reusable scoring results, and reviewed views. A mutable all-purpose performance table and permanent hit, bust, alpha, or outperformance flags are prohibited. Snapshots or materialization require historical reproducibility, source-revision history, or measured performance plus explicit refresh semantics.

## Invariants

- Shared Sleeper resources are stored once.
- Sleeper player IDs are primary canonical identity inputs; secondary IDs never auto-merge players.
- A removed primary mapping is retained and reactivated if the exact Sleeper ID returns.
- Current player profiles advance only for an equal or newer profile fetch observation.
- Team defenses are canonical entities, while sparse valid source rows remain explicit unknown entities.
- Canonical-entity counts include retained historical rows even after their primary Sleeper mapping is removed.
- Active-player counts include only active individual player entities with an active primary Sleeper/NFL mapping.
- Current team-defense counts include only team-defense entities with an active primary Sleeper/NFL mapping and do not depend on the optional provider active field.
- Optional display fields reject original ASCII control characters before trimming supported outer whitespace.
- Sleeper search rank is source search metadata, never fantasy rank or ADP.
- The global full player map is fetched at most once per successful rolling 24-hour window.
- Concurrent first creation of a shared resource reuses one canonical row.
- Shared-resource locks are acquired in deterministic canonical-key order.
- Older provider observations never overwrite newer shared current representations.
- Complete mutable collections use a collection-level watermark because per-row timestamps cannot protect the absence of a row.
- Auth users and provider identities remain separate concepts.
- Provider plus external user ID is canonical; usernames are mutable.
- A user may have at most one primary fantasy-account link.
- Browser sessions cannot create fantasy accounts or links.
- User ownership is represented through associations.
- League discovery never implies roster ownership.
- One tracked account may have at most one active roster ownership association in one league.
- Shared rosters and memberships contain no app-user ownership.
- Every roster membership references both a canonical player and its exact source identity mapping.
- Exact roster source arrays remain stored beside normalized current memberships.
- Current shared roster-domain reads require an active account-to-league discovery association.
- Active source and starter membership orders are unique within each roster.
- Current keeper state never substitutes for immutable completed-draft keeper history.
- Roster import validates every expected league before private staging and publishes the exact staged scope atomically.
- Only exact `players` source arrays define current roster membership; annotation arrays only preserve or clear current flags and order.
- Repeated exact `"0"` starter placeholders remain source facts and never create canonical player identities.
- Valid exact unmapped roster references create sparse source-marked canonical identities rather than being discarded.
- A null co-owner source state is unresolved and cannot prove that prior account ownership ended.
- Roster ownership status and observation time are paired on each account/league association; current ownership analytics require status `owned`.
- Preserved ownership history for an `unresolved` association is excluded from current owned-roster and holdings reads.
- Source-null roster arrays render as not reported, while explicit empty arrays render as confirmed zero.
- Membership annotation source state is validated per starter, reserve, taxi, and keeper field and renders as yes, no, or not reported.
- Every league-user source object must provide an exact `league_id` matching the requested canonical league before normalization; provider avatar IDs remain exact rather than display-trimmed.
- Roster import never updates `fantasy_accounts.last_synced_at`.
- League-discovery persistence requires `fantasy_accounts.provider = leagues.provider = sync_runs.provider`; cross-provider associations are invalid.
- Removing one account-to-league discovery association never deletes the shared league.
- Dynasty, keeper/redraft, best ball, superflex, IDP, and broad scoring are independent context dimensions.
- Exact provider settings, scoring settings, roster positions, and metadata remain available beside derived dimensions.
- Exact provider scoring settings define immutable provider-specific scoring identity; derived broad scoring labels never replace the exact source object.
- Semantic scoring compatibility retains every material scoring rule and normalizes only explicitly reviewed no-ops. Unknown or malformed rules remain in bounded fallback and narrow matching.
- Scoring context, league format context, and the future draft environment are separate layers.
- Scoring and league format contexts are immutable, fingerprinted, and versioned; a changed exact source object or normalization version creates or reuses a different context.
- Broad scoring buckets and compatibility keys support explicit fallback only and are never unique identities.
- Exact league-format identity includes the exact league-settings fingerprint as well as exact ordered roster positions, scoring identity, team count, roster size, best-ball state, roster-management type, quarterback topology, and IDP state; no immutable row may reuse another league's differing exact settings.
- Exact lineup order and compatible lineup composition are separate. Compatibility uses every slot token and count rather than roster size alone, while quarterback format and IDP remain independent dimensions.
- Unknown scoring or league-setting keys narrow compatibility. Provider-neutral keys identify versioned FANTASY HUD semantics and do not claim an unmapped provider is equivalent.
- Immutable context insertion recomputes every exact identity and derived routing field from source through the same classifier used for creation.
- The current league format pointer resolves scoring identity through the format context rather than duplicating a scoring pointer.
- League format observations are append-only accepted source events, permit at most one context per league and observation time, fail closed on same-time conflicts, and do not fabricate pre-observation history.
- Complete draft boards include every drafter’s picks.
- One canonical provider draft contributes at most one sample observation across app users.
- Pick ownership is derived, not stored as a universal boolean.
- One league may have multiple drafts.
- ADP and average-pick values are contextual query results, never fields on `players` or mutable fields on `draft_picks`.
- Every ADP result identifies its sample universe, exact or explicit fallback context, season, draft type, player pool, team count, time window or as-of time, eligibility version, context-match version, sample size, and match level.
- Context matching never silently broadens; a missing exact sample is not zero.
- Portfolio, FANTASY HUD Sleeper network, and external-market samples remain truthfully labeled; the imported-user network is not Sleeper platform-wide ADP.
- Pick-ADP excludes auction drafts, keeper picks by default, incomplete boards, unknown player pools, invalid picks, and duplicate canonical drafts.
- Auction drafts use average auction value, and rookie, dynasty startup, redraft, keeper-influenced, supplemental, and unknown cohorts remain explicit.
- At-time comparisons use prior-only information and exclude the subject draft; network methodology can also exclude the current user's canonical drafts.
- Cross-user aggregates require a reviewed privacy threshold and suppression behavior.
- Provider IDs remain strings.
- Sleeper usernames are mutable; Sleeper `user_id` is the canonical account key.
- Resolving an identity creates no league, roster, player, draft, or synchronization data.
- A valid empty current-season league collection is a successful observed zero; a source failure is not.
- Current-season league rows and success are scoped to the provider-resolved league season; historical associations remain stored.
- League discovery never updates `fantasy_accounts.last_synced_at`.
- Player catalog refresh never updates `fantasy_accounts.last_synced_at`.
- Best-ball starter and bench labels do not affect exposure.
- Best-ball exposure counts every current `roster_players` membership while preserving source starter, reserve, taxi, and keeper facts.
- Drafted exposure comes from immutable `draft_picks`; weekly lineup history comes from `matchup_player_points`; acquisitions, drops, and trades come from transaction facts.
- Current mutable state and historical facts use separate grains.
- Historical standings are reproducible from immutable facts or stored as source/versioned snapshots; provider-only ranking rules and commissioner adjustments are not discarded.
- Historical draft facts preserve NFL team at draft and versioned draft-time position eligibility; outcome scoring and ranks preserve the versioned position group for their period rather than joining only to current player profiles.
- Positional ADP rank is derived from context-specific ADP inside a versioned draft-time position group, never stored as a provider-supplied player label.
- Raw statistics, exact-context scoring results, and typed rankings remain separate; scoring results are reused across leagues with the same scoring context.
- Player rankings require statistics source, exact scoring context, through-period, ranking type, position-group version, scoring-engine version, ranking-methodology version, and an explicit eligibility rule when applicable.
- Total-points and points-per-game ranking and outcome views remain distinct.
- Player-level positional-rank delta is not summed across positions; higher-grain performance uses a versioned comparable scale.
- Performance-versus-capital results derive from immutable picks, exact draft environments, prior-only comparators, context-scored outcomes, and disclosed versions; mutable hit, bust, alpha, and outperformance fields are prohibited.
- Performance aggregation has explicit pick, player, NFL-team-at-draft, draft or league, and tracked-portfolio paths with canonical-draft deduplication and explicit ownership attribution.
- Sleeper consumer surfaces, `search_rank`, and undocumented endpoints never substitute for a verified, authorized player-statistics source contract.
- Scoreboards use roster-week entries and per-player score lines.
- Generic entity, document, object, and record stores are prohibited.
