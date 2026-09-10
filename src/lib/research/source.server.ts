import "server-only"
import {
  loadTrackerResearchSource,
  requireTrackerAccess,
  trackerPlayerToken,
} from "@/lib/tracker/source.server"
import { mapWithBoundedConcurrency } from "@/lib/sleeper/bounded-concurrency"
import { loadMarket, loadWeeklyStatistics } from "./consumer.server"
import {
  hasCompletedParticipation,
  matchAuction,
  marketField,
  priceImpliedRank,
  rankPerformance,
  unsupportedScoring,
  scorePlayer,
  contextKey,
  type MarketPlayer,
  type AuctionObservation,
  type ResearchContext,
} from "./model"
import type {
  Acquisition,
  PlayerProfile,
  ResearchData,
  ResearchPlayer,
} from "./types"

async function inputs() {
  await requireTrackerAccess()
  const source = await loadTrackerResearchSource(),
    season = source.state.season,
    week = source.state.week ?? 0
  const issues: string[] = []
  let market: MarketPlayer[] = [],
    marketFetchedAt: string | null = null,
    marketUrl = `https://api.sleeper.app/projections/nfl/${season}?season_type=regular&order_by=adp_ppr`
  const [m, weeks] = await Promise.all([
    loadMarket(season).catch(() => null),
    mapWithBoundedConcurrency(
      Array.from({ length: week }, (_, i) => i + 1),
      3,
      async (w) => ({
        week: w,
        result: await loadWeeklyStatistics(season, w).catch(() => null),
      })
    ),
  ])
  if (m) {
    market = m.players
    marketFetchedAt = m.fetchedAt
    marketUrl = m.url
  } else
    issues.push(
      "Sleeper ADP could not be refreshed. No substitute rankings were invented."
    )
  const failedWeeks = weeks.filter((w) => !w.result).map((w) => w.week)
  if (failedWeeks.length)
    issues.push(
      `Weekly statistics unavailable for weeks ${failedWeeks.join(", ")}; cumulative comparisons are withheld.`
    )
  const stats = weeks.flatMap((w) => w.result?.rows ?? []),
    completedWeek = Math.max(0, week - 1)
  const contexts: ResearchContext[] = source.overview.leagues.map((l) => ({
    token: l.token,
    name: l.name,
    scoring: l.scoring,
    positions: l.positions,
    teams: l.teams,
    dynasty: l.management === "dynasty",
  }))
  const boards = source.boards.filter(hasCompletedParticipation)
  const auctions: AuctionObservation[] = boards
    .filter((d) => d.type === "auction" && d.budget && d.teams)
    .flatMap((d) => {
      const context = contexts.find((c) => c.token === d.leagueToken)
      return context
        ? d.picks
            .filter((p) => p.amount !== null && p.keeper !== true)
            .map((p) => ({
              draft: d.id,
              player: p.id,
              amount: p.amount!,
              budget: d.budget!,
              teams: d.teams!,
              context,
            }))
        : []
    })
  const invalidContexts = new Set<string>()
  for (const context of contexts) {
    if (unsupportedScoring(context.scoring).length) {
      invalidContexts.add(context.token)
      continue
    }
    const league = source.overview.leagues.find(
        (l) => l.token === context.token
      )!,
      current = new Map(
        stats.filter((s) => s.week === week).map((s) => [s.id, s])
      )
    for (const matchup of league.matchups)
      for (const [id, points] of Object.entries(matchup.playerPoints ?? {})) {
        const raw = current.get(id),
          calculated = raw ? scorePlayer(raw, context.scoring) : null
        if (calculated !== null && Math.abs(calculated - points) > 0.011)
          invalidContexts.add(context.token)
      }
  }
  if (invalidContexts.size)
    issues.push(
      `${invalidContexts.size} scoring contexts could not be verified; their performance comparisons are withheld until the sources agree.`
    )
  return {
    source,
    season,
    week,
    completedWeek,
    market,
    marketFetchedAt,
    marketUrl,
    stats,
    statsFetchedAt:
      weeks
        .map((w) => w.result?.fetchedAt)
        .filter((s): s is string => Boolean(s))
        .sort()[0] ?? null,
    contexts,
    boards,
    auctions,
    issues,
    failedWeeks,
    invalidContexts,
  }
}
function directory(
  input: Awaited<ReturnType<typeof inputs>>
): ResearchPlayer[] {
  const { source, market, boards } = input,
    players = new Map<string, ResearchPlayer>()
  for (const p of market)
    players.set(p.id, {
      token: trackerPlayerToken(p.id),
      name: p.name,
      position: p.position,
      team: p.team,
      injury: p.injury,
      adp: p.adp.adp_ppr ?? null,
      held: 0,
      drafted: 0,
      updatedAt: p.updatedAt,
    })
  for (const d of boards)
    for (const p of d.picks)
      if (p.own) {
        const player = players.get(p.id) ?? {
          token: trackerPlayerToken(p.id),
          name: p.name,
          position: p.position ?? "?",
          team: p.team,
          injury: null,
          adp: null,
          held: 0,
          drafted: 0,
          updatedAt: null,
        }
        player.drafted++
        players.set(p.id, player)
      }
  for (const l of source.overview.leagues)
    for (const id of new Set(
      l.rosters.filter((r) => r.owned).flatMap((r) => r.players ?? [])
    )) {
      const p = players.get(id)
      if (p) p.held++
    }
  return [...players.values()].sort(
    (a, b) =>
      b.held - a.held ||
      b.drafted - a.drafted ||
      (a.adp ?? 1000) - (b.adp ?? 1000) ||
      a.name.localeCompare(b.name)
  )
}
function acquisitions(
  input: Awaited<ReturnType<typeof inputs>>
): Acquisition[] {
  const {
      market,
      boards,
      auctions,
      stats,
      completedWeek,
      week,
      contexts,
      failedWeeks,
      invalidContexts,
    } = input,
    profiles = new Map(market.map((p) => [p.id, p]))
  const results: Acquisition[] = []
  const positionsByPlayer = new Map(stats.map((s) => [s.id, s.position]))
  const performanceCache = new Map<
    string,
    {
      live: ReturnType<typeof rankPerformance>
      complete: ReturnType<typeof rankPerformance>
    }
  >()
  for (const d of boards) {
    const context = contexts.find((c) => c.token === d.leagueToken)
    if (!context) continue
    const field = marketField(context),
      key = contextKey(context)
    let perf = performanceCache.get(key)
    if (!perf) {
      perf = {
        live: rankPerformance(stats, context.scoring, week),
        complete: rankPerformance(stats, context.scoring, completedWeek),
      }
      performanceCache.set(key, perf)
    }
    const unavailable =
      failedWeeks.length > 0 || invalidContexts.has(context.token)
    const auctionMatches = new Map<number, ReturnType<typeof matchAuction>>()
    const positionPools = new Map(
      [...new Set(stats.map((s) => s.position))].map((position) => [
        position,
        [...perf.complete.values()]
          .filter((p) => positionsByPlayer.get(p.id) === position)
          .sort((a, b) => b.points - a.points),
      ])
    )
    for (const p of d.picks.filter((p) => p.own)) {
      const profile = profiles.get(p.id),
        marketAdp = profile?.adp[field] ?? null
      let bridge: ReturnType<typeof matchAuction> | null = null
      if (d.type === "auction" && p.amount !== null && d.budget && d.teams) {
        bridge =
          auctionMatches.get(p.amount) ??
          matchAuction(
            p.amount,
            d.budget,
            d.teams,
            d.id,
            context,
            auctions,
            market
          )
        auctionMatches.set(p.amount, bridge)
      }
      const equivalent =
        d.type === "auction" ? (bridge?.equivalentAdp ?? null) : p.pick
      const position = p.position ?? profile?.position ?? "?"
      const implied =
        p.keeper === true
          ? null
          : priceImpliedRank(equivalent, position, market, field)
      const curvePrices = market
        .filter((m) => m.position === position && m.adp[field] !== undefined)
        .map((m) => m.adp[field]!)
        .sort((a, b) => a - b)
      const boundPrice = equivalent ?? bridge?.adpBound?.value
      const rankAtBound =
        boundPrice == null
          ? null
          : priceImpliedRank(boundPrice, position, market, field)
      const rankBound =
        implied === null &&
        boundPrice != null &&
        curvePrices.length &&
        p.keeper !== true
          ? bridge?.adpBound
            ? {
                value:
                  rankAtBound ??
                  (bridge.adpBound.direction === "at_most"
                    ? 1
                    : curvePrices.length),
                direction: bridge.adpBound.direction,
              }
            : boundPrice < curvePrices[0]!
              ? { value: 1, direction: "at_most" as const }
              : boundPrice > curvePrices.at(-1)!
                ? { value: curvePrices.length, direction: "at_least" as const }
                : undefined
          : undefined
      const actual = unavailable ? undefined : perf.complete.get(p.id),
        live = unavailable ? undefined : perf.live.get(p.id)
      const pool = positionPools.get(position) ?? []
      const left = implied === null ? null : pool[Math.floor(implied) - 1],
        right = implied === null ? null : pool[Math.ceil(implied) - 1]
      const benchmark =
        left && right && implied !== null
          ? left.points +
            (right.points - left.points) * (implied - Math.floor(implied))
          : null
      results.push({
        key: trackerPlayerToken(`${d.id}-${p.pick}`),
        playerToken: trackerPlayerToken(p.id),
        name: p.name,
        position,
        team: p.team,
        leagueToken: context.token,
        league: context.name,
        draftType: d.type,
        paid: d.type === "auction" ? p.amount : p.pick,
        budget: d.budget ?? null,
        teams: d.teams,
        equivalentAdp: equivalent,
        adpBound: bridge?.adpBound,
        rankBound,
        marketAdp,
        adpField: field,
        adpGain:
          marketAdp !== null && equivalent !== null && p.keeper !== true
            ? equivalent - marketAdp
            : null,
        impliedRank: implied,
        actualRank: actual?.rank ?? null,
        liveRank: live?.rank ?? null,
        rankGain: actual && implied !== null ? implied - actual.rank : null,
        points: actual?.points ?? null,
        livePoints: live?.points ?? null,
        games: live?.games ?? 0,
        pointsAbovePrice:
          actual && benchmark !== null ? actual.points - benchmark : null,
        peerDrafts: bridge?.peerDrafts ?? 0,
        matchedPlayers: bridge?.matchedPlayers ?? 0,
        adjustedTeams: bridge?.adjustedTeams ?? false,
        reason:
          p.keeper === true
            ? "Keeper cost excluded from open-market comparison"
            : unavailable
              ? "Performance source not verified"
              : equivalent === null
                ? bridge?.adpBound
                  ? "Cost outside peer range; a bound is shown, not an extrapolated estimate"
                  : "Insufficient comparable auction peers"
                : implied === null
                  ? "Price outside this position’s ADP range"
                  : null,
      })
    }
  }
  return results
}
export async function loadResearch(): Promise<ResearchData> {
  const input = await inputs(),
    {
      source,
      season,
      week,
      completedWeek,
      marketFetchedAt,
      marketUrl,
      statsFetchedAt,
      contexts,
      issues,
    } = input
  return {
    season,
    week,
    completedWeek,
    marketFetchedAt,
    marketUrl,
    statsFetchedAt,
    contexts,
    issues,
    fetchedAt: new Date().toISOString(),
    membershipCount: source.overview.membershipCount,
    completedDrafts: input.boards.length,
    snakeDrafts: input.boards.filter((d) => d.type !== "auction").length,
    auctionDrafts: input.boards.filter((d) => d.type === "auction").length,
    unresolvedDrafts: source.boards.filter((d) => d.error).length,
    players: directory(input),
    acquisitions: acquisitions(input),
  }
}
export async function loadPlayerProfile(
  token: string,
  contextToken: string | null
): Promise<PlayerProfile> {
  if (
    !/^[a-f0-9]{24}$/.test(token) ||
    (contextToken && !/^[a-f0-9]{24}$/.test(contextToken))
  )
    throw new Error("Invalid player selection.")
  const input = await inputs(),
    player = directory(input).find((p) => p.token === token)
  if (!player) throw new Error("Player not found in the source catalog.")
  const sourcePlayer = input.market.find(
      (p) => trackerPlayerToken(p.id) === token
    ),
    picks = acquisitions(input).filter((p) => p.playerToken === token)
  const context =
    input.contexts.find(
      (c) => c.token === (contextToken ?? picks[0]?.leagueToken)
    ) ?? (!contextToken ? input.contexts[0] : undefined)
  if (!context) throw new Error("Scoring context not found.")
  const id =
    sourcePlayer?.id ??
    input.boards
      .flatMap((d) => d.picks)
      .find((p) => trackerPlayerToken(p.id) === token)?.id
  const valid =
    !input.failedWeeks.length && !input.invalidContexts.has(context.token)
  const rankings = rankPerformance(
      input.stats,
      context.scoring,
      input.completedWeek
    ),
    lives = rankPerformance(input.stats, context.scoring, input.week),
    p = id && valid ? rankings.get(id) : undefined,
    live = id && valid ? lives.get(id) : undefined,
    field = marketField(context)
  const weekly = Array.from({ length: input.week }, (_, i) => {
    const week = i + 1,
      row = input.stats.find((s) => s.id === id && s.week === week),
      rank =
        id && valid
          ? rankPerformance(input.stats, context.scoring, week).get(id)
          : undefined
    const points = row && valid ? scorePlayer(row, context.scoring) : null
    return {
      week,
      opponent: row?.opponent ?? null,
      points,
      cumulative: rank?.points ?? null,
      rank: rank?.rank ?? null,
      provisional: week > input.completedWeek,
      status: input.failedWeeks.includes(week)
        ? "Source unavailable"
        : points === null
          ? "No recorded game"
          : week > input.completedWeek
            ? "Live / provisional"
            : "Recorded",
      stats: row?.stats ?? null,
    }
  })
  return {
    player,
    context,
    contexts: input.contexts,
    acquisitions: picks,
    adpField: field,
    marketAdp: sourcePlayer?.adp[field] ?? null,
    marketRank: priceImpliedRank(
      sourcePlayer?.adp[field] ?? null,
      player.position,
      input.market,
      field
    ),
    points: p?.points ?? null,
    livePoints: live?.points ?? null,
    ppg: live?.ppg ?? null,
    games: live?.games ?? 0,
    actualRank: p?.rank ?? null,
    liveRank: live?.rank ?? null,
    eligiblePlayers: [...lives.values()].filter(
      (p) =>
        input.stats.find((s) => s.id === p.id)?.position === player.position
    ).length,
    weekly,
    season: input.season,
    week: input.week,
    completedWeek: input.completedWeek,
    marketFetchedAt: input.marketFetchedAt,
    statsFetchedAt: input.statsFetchedAt,
    issues: input.issues,
  }
}
