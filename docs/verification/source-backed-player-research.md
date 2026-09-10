# Automatic draft valuation and player research

The primary portfolio now counts fully validated, completed boards with picks directly attributed to the configured Sleeper recipient. Memberships, unstarted drafts, incomplete boards and complete boards without participation remain separately accessible. Current roster ownership does not establish draft ownership; traded selections preserve the source recipient.

## Source contracts

League membership, complete draft boards, rosters and authoritative matchup player scores use Sleeper's documented v1 API. Independent read-only source verification identified these additional **consumer endpoints**, which are not part of the documented v1 contract:

- `https://api.sleeper.app/projections/nfl/{season}?season_type=regular&order_by=adp_ppr`: only explicit ADP fields are retained. Projected points, games and search ranks are discarded.
- `https://api.sleeper.app/stats/nfl/{season}/{week}?season_type=regular`: actual event statistics, source player identity, games played, opponent and update timestamps. The season aggregate was not suitable; cumulative results use weekly observations.

The adapters validate category, season, regular-season period, identity and finite values; reject duplicate identities; allow an omitted or null week in the season ADP collection; remove ADP sentinel 999; bound streamed responses to 16 MB; limit concurrency and timeouts; and disallow redirects/arbitrary remote hosts. CI fixtures use loopback only, with explicit test mode and no production override.

ADP sample size, exact custom scoring and draft-day history are not supplied. The UI labels this as a current-reference observation with a fetch date, potentially after the draft. Next's data cache is not a durable historical archive, and this release does not claim recovered draft-day snapshots. Existing imports and migrations remain intact.

## Price model

Snake/linear purchases use actual overall pick. The automatic market selector chooses explicit PPR, half-PPR, standard, superflex/2QB and dynasty fields. Custom scoring still applies exactly to results; it is not silently claimed as an exact ADP cohort.

Auction purchases are paired by exact player ID to the selected ADP field. Each subject draft is entirely excluded from its benchmark. Peers must have the same scoring weights, roster-slot multiset and dynasty context. Prices are normalized by total room capital (team count times starting budget); team-size adjustment is disclosed. Known keepers are excluded. The median peer price per player is fitted against ADP using monotone pooled-adjacent-violators regression. At least one other complete board and 20 matched players are required. In-range costs interpolate to an estimated pick equivalent; out-of-range costs display bounds without extrapolating precise gains. These are explicit estimates, not provider-reported auction ADP.

Price-implied positional rank interpolates the selected position's ADP curve at the acquired pick equivalent. ADP value is acquired pick equivalent minus the player's market ADP (positive means later/cheaper). Rank gain is price-implied rank minus actual positional rank. Points above price interpolate actual points at that rank. Bounds do not generate precise rank gain or surplus.

## Performance

Actual sparse event counts are multiplied by supported exact league scoring weights, including positional reception bonuses. Unknown nonzero scoring rules fail closed. Results are cross-checked against current league matchup player scores; disagreement suppresses that context's outcomes. Full-source positional ranking includes players with recorded games, rather than only rostered or drafted players. Ties share competition ranks. Missing player-weeks are not fabricated as games or scores.

Current-week points and ranks are explicitly provisional. Gain/loss uses completed weeks only (strictly before the current provider week), preventing unplayed zero-point players and partial opening games from producing spurious season returns. A missing weekly feed suppresses cumulative comparisons. No projected points enter the result engine.

## User flows and preservation

The home portfolio defaults to participated completed drafts; all memberships and saved import records remain available. Draft value loads automatically, including auctions. Player research offers a searchable directory and addressable profiles with exact league context, every acquisition, weekly statistics, cumulative rank charts, source explanations, and browser-local research notes/watch status. The original calculator and board diagnostics remain secondary tools. No database records, imports or schema objects are deleted or overwritten by this change.

## Verification

Unit coverage includes participation versus membership, projection/actual separation, source IDs and missing periods, custom scoring, no-game qualification, tied ranks, budget/team normalization, same-draft exclusion, out-of-range estimates, source outages, matchup disagreement and opaque profile scoping. Browser coverage exercises automatic auction matching, profile navigation, weekly chart/table, acquisitions, notes persistence and desktop/mobile overflow. Provider data in tests is synthetic. Read-only source reconciliation is performed separately and private account observations are not committed as fixtures.
