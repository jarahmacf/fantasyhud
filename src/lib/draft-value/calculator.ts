import {
  auctionBudgetShare,
  parseRoundPick,
  priceToPositionRank,
  requireInteger,
  type PriceKind,
} from "./price-curve"
import type { RankingType } from "./performance"

export type CalculatorInput = {
  kind: PriceKind
  position: string
  contextLabel: string
  teams: string
  roundPick: string
  auctionAmount: string
  auctionBudget: string
  curve: string
  playerMarketRank: string
}
export const EMPTY_CALCULATOR: CalculatorInput = {
  kind: "pick",
  position: "RB",
  contextLabel: "",
  teams: "12",
  roundPick: "3.10",
  auctionAmount: "",
  auctionBudget: "200",
  curve: "",
  playerMarketRank: "",
}
export type ManualBenchmark = Readonly<{
  input: Readonly<CalculatorInput>
  pricedRank: number
  priceLabel: string
  playerMarketRank: number | null
  interpolation: "exact" | "interpolated" | "tied"
}>
export type ManualOutcomeInput = {
  week: string
  rankingType: RankingType
  actualRank: string
  minimumGames: string
  gamesPlayed: string
}
export type ManualComparison = Readonly<{
  week: number
  rankingType: RankingType
  actualRank: number
  minimumGames: number | null
  gamesPlayed: number | null
  surplus: number
}>

function numeric(value: string, label: string) {
  if (typeof value !== "string" || !/^\d+(?:\.\d+)?$/.test(value.trim()))
    throw new Error(`${label} must be a number.`)
  return Number(value)
}

export function calculateManualBenchmark(
  input: CalculatorInput
): ManualBenchmark {
  if (
    typeof input.contextLabel !== "string" ||
    !input.contextLabel.trim() ||
    input.contextLabel.length > 200
  )
    throw new Error(
      "Name the scoring and league format used for this calculation."
    )
  if (
    !["QB", "RB", "WR", "TE", "K", "DEF", "DL", "LB", "DB"].includes(
      input.position
    )
  )
    throw new Error("Choose a supported position group.")
  if (typeof input.curve !== "string" || input.curve.length > 32_768)
    throw new Error("The market curve is too large.")
  const teams = numeric(input.teams, "Team count")
  requireInteger(teams, "Team count", 2)
  const budget =
    input.kind === "auction"
      ? numeric(input.auctionBudget, "Starting auction budget")
      : null
  const paid =
    input.kind === "auction"
      ? auctionBudgetShare(
          numeric(input.auctionAmount, "Auction amount"),
          budget!
        )
      : parseRoundPick(input.roundPick, teams)
  const points = input.curve
    .trim()
    .split(/\r?\n/)
    .filter((line) => line.trim())
    .map((line) => {
      const parts = line.split(",")
      if (parts.length !== 2)
        throw new Error(
          "Use one positional rank and price per line, separated by a comma."
        )
      const price = numeric(parts[1]!, "Market price")
      return {
        rank: numeric(parts[0]!, "Positional rank"),
        price:
          input.kind === "auction" ? auctionBudgetShare(price, budget!) : price,
      }
    })
  const result = priceToPositionRank(paid, points, input.kind)
  if (result.status === "unavailable")
    throw new Error(
      "This price is outside the supplied market range. Add observed prices that bracket it."
    )
  const ownRank = input.playerMarketRank.trim()
    ? numeric(input.playerMarketRank, "Player market rank")
    : null
  if (
    ownRank !== null &&
    (!Number.isFinite(ownRank) || ownRank < 1 || ownRank > 1_000_000)
  )
    throw new Error("Player market rank must be positive.")
  return Object.freeze({
    input: Object.freeze({ ...input, contextLabel: input.contextLabel.trim() }),
    pricedRank: result.rank,
    priceLabel:
      input.kind === "pick"
        ? `${input.roundPick.trim()} · pick ${paid}`
        : `${input.auctionAmount} of ${input.auctionBudget} · ${formatRank(paid * 100)}% of budget`,
    playerMarketRank: ownRank,
    interpolation: result.method,
  })
}

export function compareManualOutcome(
  benchmark: ManualBenchmark,
  input: ManualOutcomeInput
): ManualComparison {
  const week = numeric(input.week, "Through week")
  const actualRank = numeric(input.actualRank, "Actual positional rank")
  requireInteger(week, "Through week")
  if (week > 25) throw new Error("Through week cannot exceed 25.")
  requireInteger(actualRank, "Actual positional rank")
  let minimumGames = null
  let gamesPlayed = null
  if (input.rankingType === "season_points_per_game_rank") {
    minimumGames = numeric(input.minimumGames, "Minimum games")
    gamesPlayed = numeric(input.gamesPlayed, "Games played")
    requireInteger(minimumGames, "Minimum games")
    requireInteger(gamesPlayed, "Games played", 0)
    if (gamesPlayed > week)
      throw new Error("Games played cannot exceed the through week.")
    if (gamesPlayed < minimumGames)
      throw new Error(
        "This player does not qualify for the selected PPG minimum."
      )
  } else if (input.rankingType !== "season_total_points_rank")
    throw new Error("Choose total points or points per game.")
  return Object.freeze({
    week,
    rankingType: input.rankingType,
    actualRank,
    minimumGames,
    gamesPlayed,
    surplus: benchmark.pricedRank - actualRank,
  })
}

export function formatRank(rank: number) {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(
    rank
  )
}
export function formatSurplus(surplus: number) {
  return `${surplus > 0 ? "+" : ""}${formatRank(surplus)}`
}
export function comparisonKey(row: ManualComparison) {
  return `${row.week}:${row.rankingType}:${row.minimumGames ?? "none"}`
}

export function saveManualCalculation(
  benchmark: ManualBenchmark,
  history: readonly ManualComparison[]
) {
  if (history.length > 104)
    throw new Error("Save at most 104 weekly comparisons in one calculation.")
  const saved = JSON.stringify({
    version: 1,
    input: benchmark.input,
    outcomes: history.map((row) => ({
      week: String(row.week),
      rankingType: row.rankingType,
      actualRank: String(row.actualRank),
      minimumGames: String(row.minimumGames ?? ""),
      gamesPlayed: String(row.gamesPlayed ?? ""),
    })),
  })
  if (saved.length > 65_536)
    throw new Error("The calculation is too large to save on this device.")
  return saved
}

/** Recompute all saved results; never trust cached ranks or surplus from storage. */
export function restoreManualCalculation(json: string) {
  if (json.length > 65_536)
    throw new Error("The saved calculation is too large.")
  try {
    const saved = JSON.parse(json)
    if (
      saved?.version !== 1 ||
      !Array.isArray(saved.outcomes) ||
      saved.outcomes.length > 104
    )
      throw new Error()
    const benchmark = calculateManualBenchmark(saved.input)
    const history = saved.outcomes.map((row: ManualOutcomeInput) =>
      compareManualOutcome(benchmark, row)
    ) as ManualComparison[]
    if (new Set(history.map(comparisonKey)).size !== history.length)
      throw new Error()
    return { benchmark, history }
  } catch {
    throw new Error(
      "The saved calculation is invalid or uses an unsupported version."
    )
  }
}
