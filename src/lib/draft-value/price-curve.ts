/** Prices are pick numbers for ADP, or budget shares for AAV. Never mix them. */
export type PriceKind = "pick" | "auction"
export type PricePoint = Readonly<{ rank: number; price: number }>
export type PriceRankResult =
  | Readonly<{
      status: "available"
      rank: number
      method: "exact" | "interpolated" | "tied"
      anchors: readonly PricePoint[]
    }>
  | Readonly<{ status: "unavailable"; reason: "outside_market_range" }>

export function requireFinite(value: number, label: string, minimum = 0) {
  if (!Number.isFinite(value) || value < minimum || value > 1_000_000) {
    throw new Error(
      `${label} must be a finite number from ${minimum} to 1000000.`
    )
  }
}

export function requireInteger(value: number, label: string, minimum = 1) {
  requireFinite(value, label, minimum)
  if (!Number.isSafeInteger(value))
    throw new Error(`${label} must be a whole number.`)
}

export function overallPick(round: number, selection: number, teams: number) {
  requireInteger(teams, "Team count", 2)
  requireInteger(round, "Round")
  requireInteger(selection, "Selection")
  if (selection > teams)
    throw new Error("Selection cannot exceed the team count.")
  const pick = (round - 1) * teams + selection
  requireInteger(pick, "Overall pick")
  return pick
}

/** Round notation describes the chronological selection, including in even rounds. */
export function parseRoundPick(value: string, teams: number) {
  const match = /^(\d{1,4})\.(\d{1,4})$/.exec(value.trim())
  if (!match) throw new Error("Enter a round and selection, such as 3.10.")
  return overallPick(Number(match[1]), Number(match[2]), teams)
}

export function auctionBudgetShare(amount: number, budget: number) {
  requireFinite(amount, "Auction amount")
  requireFinite(budget, "Starting auction budget", 0.01)
  if (amount > budget)
    throw new Error("Auction amount cannot exceed the starting budget.")
  return amount / budget
}

/** A contiguous positional slice is allowed. Tied prices use ordinal midranks. */
export function normalizePriceCurve(
  points: readonly PricePoint[],
  kind: PriceKind
) {
  if (kind !== "pick" && kind !== "auction")
    throw new Error("Unknown price type.")
  if (!points.length || points.length > 1_024)
    throw new Error("Provide between 1 and 1024 positional prices.")
  const ordered = points
    .map((point) => ({ ...point }))
    .sort((a, b) => a.rank - b.rank)
  for (const [index, point] of ordered.entries()) {
    requireInteger(point.rank, "Positional rank")
    requireFinite(point.price, "Market price", kind === "pick" ? 1 : 0)
    if (kind === "auction" && point.price > 1)
      throw new Error("Auction curves must use a share of the starting budget.")
    const previous = ordered[index - 1]
    if (!previous) continue
    if (point.rank !== previous.rank + 1)
      throw new Error(
        "Provide each consecutive positional rank without duplicates or gaps."
      )
    if (
      kind === "pick"
        ? point.price < previous.price
        : point.price > previous.price
    )
      throw new Error(
        "Market prices must get cheaper as positional ranks increase."
      )
  }
  const groups: PricePoint[] = []
  for (let start = 0; start < ordered.length;) {
    let end = start
    while (
      end + 1 < ordered.length &&
      ordered[end + 1]!.price === ordered[start]!.price
    )
      end++
    groups.push({
      price: ordered[start]!.price,
      rank: (ordered[start]!.rank + ordered[end]!.rank) / 2,
    })
    start = end + 1
  }
  return groups
}

export function priceToPositionRank(
  price: number,
  points: readonly PricePoint[],
  kind: PriceKind
): PriceRankResult {
  requireFinite(price, "Price paid", kind === "pick" ? 1 : 0)
  if (kind === "auction" && price > 1)
    throw new Error("Auction price must be a budget share.")
  const curve = normalizePriceCurve(points, kind)
  const exact = curve.find((point) => point.price === price)
  if (exact)
    return {
      status: "available",
      rank: exact.rank,
      method:
        points.filter((point) => point.price === price).length > 1
          ? "tied"
          : "exact",
      anchors: [exact],
    }
  for (let index = 1; index < curve.length; index++) {
    const left = curve[index - 1]!
    const right = curve[index]!
    if (
      price > Math.min(left.price, right.price) &&
      price < Math.max(left.price, right.price)
    ) {
      return {
        status: "available",
        rank:
          left.rank +
          ((price - left.price) / (right.price - left.price)) *
            (right.rank - left.rank),
        method: "interpolated",
        anchors: [left, right],
      }
    }
  }
  return { status: "unavailable", reason: "outside_market_range" }
}

export type MarketPlayerPrice = Readonly<{
  playerId: string
  price: number
  observations: number
}>

/** Derive ranks from the selected position's prices, never provider search_rank. */
export function positionalMarketCurve(
  players: readonly MarketPlayerPrice[],
  kind: PriceKind
) {
  if (new Set(players.map((player) => player.playerId)).size !== players.length)
    throw new Error(
      "Each canonical player may occur only once in the market snapshot."
    )
  const sorted = [...players].sort(
    (a, b) =>
      (kind === "pick" ? a.price - b.price : b.price - a.price) ||
      (a.playerId < b.playerId ? -1 : a.playerId > b.playerId ? 1 : 0)
  )
  const points = sorted.map((player, index) => ({
    rank: index + 1,
    price: player.price,
  }))
  normalizePriceCurve(points, kind)
  return { players: sorted, points }
}
