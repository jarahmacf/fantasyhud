import type { FrozenPriceBenchmark } from "./benchmark"
import { requireFinite, requireInteger } from "./price-curve"

export type RankingType =
  "season_total_points_rank" | "season_points_per_game_rank"
export const PERFORMANCE_RANK_VERSION =
  "positional-performance/competition-v1" as const
export type ScoredPlayer = Readonly<{
  playerId: string
  position: string
  points: number
  gamesPlayed: number
}>

/** Exact-context scoring is an upstream contract, not a default-PPR shortcut. */
export type PerformanceUniverse = Readonly<{
  id: string
  scoringContextId: string
  source: string
  sourceRevision: string
  sourceAsOf: string
  scoringEngineVersion: string
  positionGroupVersion: string
  season: number
  seasonType: string
  throughWeek: number
  isFinal: boolean
  completeUniverse: boolean
  unscoredRuleKeys: readonly string[]
  players: readonly ScoredPlayer[]
}>
export type RankedPerformance = Readonly<{
  universe: Omit<PerformanceUniverse, "players">
  methodologyVersion: typeof PERFORMANCE_RANK_VERSION
  rankingType: RankingType
  minimumGames: number | null
  players: readonly (ScoredPlayer & {
    rank: number
    pointsPerGame: number | null
  })[]
}>

export function rankPerformanceUniverse(
  universe: PerformanceUniverse,
  rankingType: RankingType,
  minimumGames: number | null
): RankedPerformance {
  if (!universe.completeUniverse)
    throw new Error(
      "Rank the complete eligible player universe, not just owned or drafted players."
    )
  if (universe.unscoredRuleKeys.length)
    throw new Error(
      "Every scoring rule must be supported before calculating an actual rank."
    )
  for (const value of [
    universe.id,
    universe.scoringContextId,
    universe.source,
    universe.sourceRevision,
    universe.scoringEngineVersion,
    universe.positionGroupVersion,
    universe.seasonType,
  ]) {
    if (!value || value !== value.trim())
      throw new Error("Performance source, context and versions are required.")
  }
  if (
    !/(?:Z|[+-]\d{2}:\d{2})$/.test(universe.sourceAsOf) ||
    !Number.isFinite(Date.parse(universe.sourceAsOf))
  )
    throw new Error("Performance source as-of time is required.")
  requireInteger(universe.season, "Season")
  requireInteger(universe.throughWeek, "Through week")
  const perGame = rankingType === "season_points_per_game_rank"
  if (perGame) {
    if (minimumGames === null)
      throw new Error("PPG rank requires an explicit minimum-games rule.")
    requireInteger(minimumGames, "Minimum games")
  } else if (
    rankingType !== "season_total_points_rank" ||
    minimumGames !== null
  )
    throw new Error("Total-points rank and PPG rank must remain separate.")
  const ids = new Set<string>()
  for (const player of universe.players) {
    if (!player.playerId || !player.position || ids.has(player.playerId))
      throw new Error(
        "Each canonical player needs one explicit outcome position."
      )
    ids.add(player.playerId)
    requireFinite(player.points, "Fantasy points", -1_000_000)
    requireInteger(player.gamesPlayed, "Games played", 0)
    if (player.gamesPlayed > universe.throughWeek)
      throw new Error("Games played cannot exceed the through-week period.")
    if (player.gamesPlayed === 0 && player.points !== 0)
      throw new Error("A player with points needs a played-game observation.")
  }
  const gamesHaveStarted = universe.players.some(
    (player) => player.gamesPlayed > 0
  )
  const eligible = gamesHaveStarted
    ? universe.players.filter(
        (player) => !perGame || player.gamesPlayed >= minimumGames!
      )
    : []
  const value = (player: ScoredPlayer) =>
    perGame ? player.points / player.gamesPlayed : player.points
  const ordered = [...eligible].sort(
    (a, b) =>
      (a.position < b.position ? -1 : a.position > b.position ? 1 : 0) ||
      value(b) - value(a) ||
      (a.playerId < b.playerId ? -1 : a.playerId > b.playerId ? 1 : 0)
  )
  let ordinal = 0
  let rank = 0
  const players = ordered.map((player, index) => {
    const previous = ordered[index - 1]
    ordinal = previous?.position === player.position ? ordinal + 1 : 1
    if (!previous || ordinal === 1 || value(previous) !== value(player))
      rank = ordinal
    return {
      ...player,
      rank,
      pointsPerGame: player.gamesPlayed
        ? player.points / player.gamesPlayed
        : null,
    }
  })
  const { players: _players, ...metadata } = universe
  void _players
  return {
    universe: structuredClone(metadata),
    methodologyVersion: PERFORMANCE_RANK_VERSION,
    rankingType,
    minimumGames,
    players,
  }
}

export function comparePriceWithPerformance(
  benchmark: FrozenPriceBenchmark,
  performance: RankedPerformance
) {
  const context = benchmark.purchase.context
  const universe = performance.universe
  if (
    context.scoringContextId !== universe.scoringContextId ||
    context.season !== universe.season ||
    context.seasonType !== universe.seasonType ||
    context.positionGroupVersion !== universe.positionGroupVersion
  )
    return {
      status: "unavailable" as const,
      reason: "outcome_context_mismatch" as const,
    }
  if (
    Date.parse(universe.sourceAsOf) < Date.parse(benchmark.purchase.acquiredAt)
  )
    return {
      status: "unavailable" as const,
      reason: "outcome_precedes_purchase" as const,
    }
  const player = performance.players.find(
    (row) => row.playerId === benchmark.purchase.playerId
  )
  if (!player)
    return {
      status: "unavailable" as const,
      reason: "no_qualifying_outcome" as const,
    }
  if (player.position !== context.position)
    return {
      status: "unavailable" as const,
      reason: "position_changed" as const,
    }
  return {
    status: "available" as const,
    pricedPositionRank: benchmark.pricedPositionRank,
    playerMarketPositionRank: benchmark.playerMarketPositionRank,
    actualPositionRank: player.rank,
    rankSurplus: benchmark.pricedPositionRank - player.rank,
    rankingType: performance.rankingType,
    minimumGames: performance.minimumGames,
    throughWeek: universe.throughWeek,
    isFinal: universe.isFinal,
    sourceAsOf: universe.sourceAsOf,
  }
}
