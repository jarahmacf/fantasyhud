import {
  auctionBudgetShare,
  positionalMarketCurve,
  priceToPositionRank,
  requireInteger,
  type MarketPlayerPrice,
  type PriceKind,
} from "./price-curve"

export const PRICE_RANK_VERSION = "price-implied-position-rank/v1" as const
export type PriceContext = Readonly<{
  scoringContextId: string
  formatContextKey: string
  environmentKey: string
  quality: "exact" | "partial" | "unknown"
  season: number
  seasonType: string
  playerPool: string
  position: string
  positionGroupVersion: string
  teamCount: number
  priceKind: PriceKind
  auctionBudget: number | null
}>
export type DraftPurchase = Readonly<{
  pickId: string
  draftId: string
  playerId: string
  acquiredAt: string
  isKeeper: boolean | null
  price: number
  context: PriceContext
}>

/** Trusted adapters must verify complete boards and historical context. Not a browser persistence API. */
export type PositionalMarketSnapshot = Readonly<{
  id: string
  source: "portfolio" | "fantasyhud_sample" | "external_market"
  sourceRevision: string
  availableAt: string
  windowStartsAt: string
  windowEndsAt: string
  context: PriceContext
  keeperPolicy: "excluded"
  subjectDraftExcluded: boolean
  constituentDraftIds: readonly string[] | null
  sampleSize: number
  minimumDrafts: number
  minimumObservations: number
  samplePolicyVersion: string
  players: readonly MarketPlayerPrice[]
}>
type UnavailableReason =
  | "inexact_context"
  | "context_mismatch"
  | "keeper_or_unknown_keeper"
  | "future_market_data"
  | "subject_draft_in_sample"
  | "insufficient_sample"
  | "outside_market_range"

function timestamp(value: string) {
  if (
    !/(?:Z|[+-]\d{2}:\d{2})$/.test(value) ||
    !Number.isFinite(Date.parse(value))
  )
    throw new Error("Source times must be valid timestamps with a timezone.")
  return Date.parse(value)
}
function requireIdentity(value: string, label: string) {
  if (
    !value ||
    value !== value.trim() ||
    /[\u0000-\u001f\u007f]/.test(value) ||
    value.length > 256
  )
    throw new Error(`${label} must be an exact, nonempty identifier.`)
}
function validateContext(context: PriceContext) {
  for (const key of [
    "scoringContextId",
    "formatContextKey",
    "environmentKey",
    "seasonType",
    "playerPool",
    "position",
    "positionGroupVersion",
  ] as const)
    requireIdentity(context[key], key)
  requireInteger(context.season, "Season")
  requireInteger(context.teamCount, "Team count", 2)
  if (!["exact", "partial", "unknown"].includes(context.quality))
    throw new Error("Unknown context quality.")
  if (context.priceKind === "auction") {
    if (context.auctionBudget === null)
      throw new Error("Auction context requires its starting budget.")
    auctionBudgetShare(0, context.auctionBudget)
  } else if (context.priceKind !== "pick" || context.auctionBudget !== null)
    throw new Error("Pick and auction contexts must remain separate.")
}
function sameContext(left: PriceContext, right: PriceContext) {
  return (Object.keys(left) as (keyof PriceContext)[]).every(
    (key) => left[key] === right[key]
  )
}
function deepFreeze<T>(value: T): Readonly<T> {
  if (value && typeof value === "object") {
    Object.values(value).forEach(deepFreeze)
    Object.freeze(value)
  }
  return value
}
export type FrozenPriceBenchmark = Readonly<{
  methodologyVersion: typeof PRICE_RANK_VERSION
  purchase: DraftPurchase
  market: PositionalMarketSnapshot
  pricedPositionRank: number
  playerMarketPositionRank: number | null
  interpolation: "exact" | "interpolated" | "tied"
}>

/** Detaches all inputs. A future persistence adapter must store this snapshot append-only. */
export function freezePriceBenchmark(
  purchase: DraftPurchase,
  market: PositionalMarketSnapshot
):
  | Readonly<{ status: "available"; benchmark: FrozenPriceBenchmark }>
  | Readonly<{ status: "unavailable"; reason: UnavailableReason }> {
  for (const key of ["pickId", "draftId", "playerId"] as const)
    requireIdentity(purchase[key], key)
  for (const key of ["id", "sourceRevision", "samplePolicyVersion"] as const)
    requireIdentity(market[key], key)
  validateContext(purchase.context)
  validateContext(market.context)
  const acquiredAt = timestamp(purchase.acquiredAt)
  const availableAt = timestamp(market.availableAt)
  const startsAt = timestamp(market.windowStartsAt)
  const endsAt = timestamp(market.windowEndsAt)
  if (startsAt > endsAt || endsAt > availableAt)
    throw new Error("Market source times are inconsistent.")
  for (const key of [
    "sampleSize",
    "minimumDrafts",
    "minimumObservations",
  ] as const)
    requireInteger(market[key], key)
  if (
    market.minimumDrafts < 2 ||
    market.minimumObservations > market.sampleSize
  )
    throw new Error(
      "The versioned sample policy must require at least two drafts and attainable observations."
    )
  if (
    !["portfolio", "fantasyhud_sample", "external_market"].includes(
      market.source
    ) ||
    market.keeperPolicy !== "excluded"
  )
    throw new Error("Unsupported market source or keeper policy.")
  if (
    market.source !== "external_market" &&
    market.constituentDraftIds === null
  )
    throw new Error(
      "An imported-draft sample must identify every canonical draft."
    )
  if (market.constituentDraftIds !== null) {
    market.constituentDraftIds.forEach((id) =>
      requireIdentity(id, "Canonical draft ID")
    )
    if (
      new Set(market.constituentDraftIds).size !== market.sampleSize ||
      market.constituentDraftIds.length !== market.sampleSize
    )
      throw new Error(
        "Market sample size must count unique canonical drafts exactly once."
      )
  }
  for (const player of market.players) {
    requireIdentity(player.playerId, "Market player ID")
    requireInteger(player.observations, "Player observations")
    if (player.observations > market.sampleSize)
      throw new Error("A player cannot have more observations than drafts.")
  }
  const unavailable = (reason: UnavailableReason) => ({
    status: "unavailable" as const,
    reason,
  })
  if (
    purchase.context.quality !== "exact" ||
    market.context.quality !== "exact" ||
    purchase.context.playerPool === "unknown" ||
    market.context.playerPool === "unknown" ||
    purchase.context.position === "unknown" ||
    market.context.position === "unknown"
  )
    return unavailable("inexact_context")
  if (!sameContext(purchase.context, market.context))
    return unavailable("context_mismatch")
  if (purchase.isKeeper !== false)
    return unavailable("keeper_or_unknown_keeper")
  if (availableAt > acquiredAt || endsAt > acquiredAt)
    return unavailable("future_market_data")
  if (
    market.subjectDraftExcluded !== true ||
    market.constituentDraftIds?.includes(purchase.draftId)
  )
    return unavailable("subject_draft_in_sample")
  // Dropping thinly sampled players here would silently renumber the market.
  if (
    market.sampleSize < market.minimumDrafts ||
    !market.players.length ||
    market.players.some(
      (player) => player.observations < market.minimumObservations
    )
  )
    return unavailable("insufficient_sample")
  const price =
    purchase.context.priceKind === "auction"
      ? auctionBudgetShare(purchase.price, purchase.context.auctionBudget!)
      : purchase.price
  if (purchase.context.priceKind === "pick")
    requireInteger(price, "Overall pick paid")
  const { points } = positionalMarketCurve(
    market.players,
    purchase.context.priceKind
  )
  const result = priceToPositionRank(price, points, purchase.context.priceKind)
  if (result.status === "unavailable") return unavailable(result.reason)
  const playerPrice = market.players.find(
    (player) => player.playerId === purchase.playerId
  )?.price
  const ownRank =
    playerPrice === undefined
      ? null
      : priceToPositionRank(playerPrice, points, purchase.context.priceKind)
  return {
    status: "available",
    benchmark: deepFreeze(
      structuredClone({
        methodologyVersion: PRICE_RANK_VERSION,
        purchase,
        market,
        pricedPositionRank: result.rank,
        playerMarketPositionRank:
          ownRank?.status === "available" ? ownRank.rank : null,
        interpolation: result.method,
      })
    ),
  }
}
