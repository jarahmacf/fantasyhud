import { priceToPositionRank } from "@/lib/draft-value/price-curve"

export const adpFields = [
  "adp_ppr",
  "adp_half_ppr",
  "adp_std",
  "adp_2qb",
  "adp_dynasty_ppr",
  "adp_dynasty_half_ppr",
  "adp_dynasty_std",
  "adp_dynasty_2qb",
] as const
export type AdpField = (typeof adpFields)[number]
export type MarketPlayer = {
  id: string
  name: string
  position: string
  team: string | null
  injury: string | null
  adp: Partial<Record<AdpField, number>>
  updatedAt: string | null
}
export type StatPlayerWeek = {
  id: string
  position: string
  week: number
  opponent: string | null
  team: string | null
  stats: Record<string, number>
  updatedAt: string | null
}
export type ResearchContext = {
  token: string
  name: string
  scoring: Record<string, unknown>
  positions: string[]
  teams: number
  dynasty: boolean
}
export type AuctionObservation = {
  draft: string
  player: string
  amount: number
  budget: number
  teams: number
  context: ResearchContext
}
export type AuctionMatch = {
  equivalentAdp: number | null
  adpBound?: { value: number; direction: "at_most" | "at_least" }
  peerDrafts: number
  matchedPlayers: number
  method: string
  adjustedTeams: boolean
}
function record(x: unknown): Record<string, unknown> {
  if (!x || typeof x !== "object" || Array.isArray(x))
    throw new Error("Invalid research source record.")
  return x as Record<string, unknown>
}
function identity(x: unknown) {
  if (typeof x !== "string" || !/^[A-Za-z0-9_-]{1,32}$/.test(x))
    throw new Error("Invalid source player identity.")
  return x
}
function timestamp(x: unknown) {
  return typeof x === "number" && Number.isFinite(x) && x > 0 && x < 8.64e15
    ? new Date(x).toISOString()
    : null
}
export function normalizeMarket(
  value: unknown,
  season: number
): MarketPlayer[] {
  if (!Array.isArray(value) || value.length > 20000)
    throw new Error("Invalid ADP collection.")
  const seen = new Set<string>()
  return value.map((item) => {
    const r = record(item),
      p = record(r.player),
      stats = record(r.stats)
    if (
      r.category !== "proj" ||
      String(r.season) !== String(season) ||
      r.season_type !== "regular" ||
      r.week != null
    )
      throw new Error("Wrong ADP source period.")
    const id = identity(r.player_id)
    if (seen.has(id)) throw new Error("Duplicate market player.")
    seen.add(id)
    const adp: MarketPlayer["adp"] = {}
    for (const field of adpFields) {
      const price = stats[field]
      if (
        typeof price === "number" &&
        Number.isFinite(price) &&
        price >= 1 &&
        price < 999
      )
        adp[field] = price
    }
    return {
      id,
      name:
        [p.first_name, p.last_name]
          .filter((v) => typeof v === "string")
          .join(" ") || id,
      position: typeof p.position === "string" ? p.position : "?",
      team: typeof r.team === "string" ? r.team : null,
      injury: typeof p.injury_status === "string" ? p.injury_status : null,
      adp,
      updatedAt: timestamp(r.last_modified),
    }
  })
}
export function normalizeStatistics(
  value: unknown,
  season: number,
  week: number
): StatPlayerWeek[] {
  if (!Array.isArray(value) || value.length > 20000)
    throw new Error("Invalid weekly statistics.")
  const seen = new Set<string>()
  return value.map((item) => {
    const r = record(item),
      p = record(r.player),
      raw = record(r.stats)
    if (
      r.category !== "stat" ||
      String(r.season) !== String(season) ||
      r.season_type !== "regular" ||
      r.week !== week
    )
      throw new Error("Projections or wrong period cannot be actual results.")
    const id = identity(r.player_id)
    if (seen.has(id)) throw new Error("Duplicate player week.")
    seen.add(id)
    const stats: Record<string, number> = {}
    for (const [key, v] of Object.entries(raw)) {
      if (typeof v !== "number" || !Number.isFinite(v))
        throw new Error("Invalid statistic.")
      stats[key] = v
    }
    return {
      id,
      position: typeof p.position === "string" ? p.position : "?",
      team: typeof r.team === "string" ? r.team : null,
      opponent: typeof r.opponent === "string" ? r.opponent : null,
      week,
      stats,
      updatedAt: timestamp(r.last_modified),
    }
  })
}

// These source statistic keys are directly additive event counts. Unknown scoring
// rules fail closed. Missing keys in a supplied sparse STAT row mean no such event;
// a missing player/week is never manufactured as a zero-game observation.
const scoringKeys = new Set(
  `blk_kick bonus_rec_rb bonus_rec_te bonus_rec_wr def_st_ff def_st_fum_rec def_st_td def_td ff fgm_0_19 fgm_20_29 fgm_30_39 fgm_40_49 fgm_50_59 fgm_50p fgm_60p fgmiss fum_lost fum_rec fum_rec_td int kr_yd pass_2pt pass_cmp pass_cmp_40p pass_int pass_int_td pass_td pass_td_40p pass_td_50p pass_yd pr_yd pts_allow_0 pts_allow_14_20 pts_allow_1_6 pts_allow_28_34 pts_allow_35p pts_allow_7_13 rec rec_0_4 rec_10_19 rec_20_29 rec_2pt rec_30_39 rec_40p rec_5_9 rec_fd rec_td rec_td_40p rec_td_50p rec_yd rush_2pt rush_40p rush_att rush_td rush_td_40p rush_td_50p rush_yd sack safe st_ff st_fum_rec st_td xpm xpmiss`.split(
    " "
  )
)
export function unsupportedScoring(scoring: Record<string, unknown>) {
  return Object.entries(scoring)
    .filter(
      ([key, v]) =>
        typeof v !== "number" ||
        !Number.isFinite(v) ||
        (v !== 0 && !scoringKeys.has(key))
    )
    .map(([key]) => key)
}
export function scorePlayer(
  row: StatPlayerWeek,
  scoring: Record<string, unknown>
): number | null {
  if (unsupportedScoring(scoring).length || !((row.stats.gp ?? 0) > 0))
    return null
  return (
    Math.round(
      Object.entries(scoring).reduce(
        (n, [key, weight]) => n + Number(weight) * (row.stats[key] ?? 0),
        0
      ) * 100
    ) / 100
  )
}
export function marketField(context: ResearchContext): AdpField {
  const qb =
    context.positions.filter((p) => p === "QB").length >= 2 ||
    context.positions.some((p) => p === "SUPER_FLEX" || p === "QB_FLEX")
  const suffix = qb
    ? "2qb"
    : context.scoring.rec === 0.5
      ? "half_ppr"
      : !context.scoring.rec
        ? "std"
        : "ppr"
  return `adp_${context.dynasty ? "dynasty_" : ""}${suffix}` as AdpField
}
export function contextKey(context: ResearchContext) {
  // Team count is deliberately excluded only for the explicitly labelled room-capital adjustment.
  return JSON.stringify([
    Object.entries(context.scoring)
      .filter(([, v]) => v !== 0)
      .sort(([a], [b]) => a.localeCompare(b)),
    [...context.positions].sort(),
    context.dynasty,
  ])
}
export function priceImpliedRank(
  price: number | null,
  position: string,
  market: MarketPlayer[],
  field: AdpField
) {
  if (price === null) return null
  const pool = market
    .filter((p) => p.position === position && p.adp[field] !== undefined)
    .sort((a, b) => a.adp[field]! - b.adp[field]! || a.id.localeCompare(b.id))
  if (!pool.length || pool.length > 1024) return null
  const result = priceToPositionRank(
    price,
    pool.map((p, i) => ({ rank: i + 1, price: p.adp[field]! })),
    "pick"
  )
  return result.status === "available"
    ? Math.round(result.rank * 100) / 100
    : null
}
function median(values: number[]) {
  const s = [...values].sort((a, b) => a - b),
    mid = Math.floor(s.length / 2)
  return s.length % 2 ? s[mid]! : (s[mid - 1]! + s[mid]!) / 2
}
/** Leave-one-draft-out, exact scoring/lineup peer prices, normalized to total room
 * capital. PAVA removes local bid noise while keeping the fitted ADP curve monotone.
 * This is a current-reference estimate, never a historical at-draft market fact. */
export function matchAuction(
  amount: number,
  budget: number,
  teams: number,
  draft: string,
  context: ResearchContext,
  observations: AuctionObservation[],
  market: MarketPlayer[]
): AuctionMatch {
  const field = marketField(context),
    prices = new Map(market.map((p) => [p.id, p.adp[field]])),
    key = contextKey(context)
  const peers = observations.filter(
    (o) =>
      o.draft !== draft &&
      contextKey(o.context) === key &&
      o.budget > 0 &&
      o.teams > 1 &&
      o.amount >= 0 &&
      o.amount <= o.budget &&
      prices.has(o.player) &&
      prices.get(o.player) !== undefined
  )
  const byPlayer = new Map<string, number[]>()
  for (const p of peers)
    byPlayer.set(p.player, [
      ...(byPlayer.get(p.player) ?? []),
      p.amount / (p.budget * p.teams),
    ])
  const result: AuctionMatch = {
    equivalentAdp: null,
    peerDrafts: new Set(peers.map((p) => p.draft)).size,
    matchedPlayers: byPlayer.size,
    method: "Leave-one-draft-out peer auction / Sleeper ADP fit",
    adjustedTeams: peers.some((p) => p.teams !== teams),
  }
  if (
    budget <= 0 ||
    teams < 2 ||
    amount < 0 ||
    amount > budget ||
    byPlayer.size < 20 ||
    result.peerDrafts < 1
  )
    return result
  const samples = [...byPlayer]
    .map(([id, values]) => ({ adp: prices.get(id)!, price: median(values) }))
    .sort((a, b) => a.adp - b.adp)
  const blocks: { sum: number; n: number; adps: number[] }[] = []
  for (const s of samples) {
    // Group identical ADP first so the inverse never depends on player order.
    const last = blocks.at(-1)
    if (last?.adps.every((a) => a === s.adp)) {
      last.sum += s.price
      last.n++
      last.adps.push(s.adp)
    } else blocks.push({ sum: s.price, n: 1, adps: [s.adp] })
    while (blocks.length > 1) {
      const b = blocks.at(-1)!,
        a = blocks.at(-2)!
      if (a.sum / a.n > b.sum / b.n) break
      blocks.splice(-2, 2, {
        sum: a.sum + b.sum,
        n: a.n + b.n,
        adps: [...a.adps, ...b.adps],
      })
    }
  }
  const curve = blocks.map((b) => ({
      price: b.sum / b.n,
      adp: median(b.adps),
    })),
    paid = amount / (budget * teams)
  if (paid > curve[0]!.price)
    result.adpBound = { value: curve[0]!.adp, direction: "at_most" }
  else if (paid < curve.at(-1)!.price)
    result.adpBound = { value: curve.at(-1)!.adp, direction: "at_least" }
  for (let i = 0; i < curve.length; i++) {
    const a = curve[i]!,
      b = curve[i + 1]
    if (Math.abs(paid - a.price) < 1e-10) result.equivalentAdp = a.adp
    else if (b && paid < a.price && paid > b.price)
      result.equivalentAdp =
        a.adp + ((b.adp - a.adp) * (a.price - paid)) / (a.price - b.price)
  }
  if (result.equivalentAdp !== null)
    result.equivalentAdp = Math.round(result.equivalentAdp * 100) / 100
  return result
}
export type Performance = {
  id: string
  points: number
  games: number
  ppg: number
  rank: number
  weekly: {
    week: number
    points: number
    opponent: string | null
    rank: number | null
  }[]
}
export function rankPerformance(
  rows: StatPlayerWeek[],
  scoring: Record<string, unknown>,
  throughWeek: number
): Map<string, Performance> {
  const byPlayer = new Map<string, Performance & { position: string }>()
  for (const r of rows.filter((r) => r.week <= throughWeek)) {
    const points = scorePlayer(r, scoring)
    if (points === null) continue
    let p = byPlayer.get(r.id)
    if (!p) {
      p = {
        id: r.id,
        position: r.position,
        points: 0,
        games: 0,
        ppg: 0,
        rank: 0,
        weekly: [],
      }
      byPlayer.set(r.id, p)
    }
    if (p.position !== r.position) {
      byPlayer.delete(r.id)
      continue
    }
    p.points = Math.round((p.points + points) * 100) / 100
    p.games += r.stats.gp ?? 0
    p.ppg = p.points / p.games
    p.weekly.push({ week: r.week, points, opponent: r.opponent, rank: null })
  }
  for (const position of new Set(
    [...byPlayer.values()].map((p) => p.position)
  )) {
    const pool = [...byPlayer.values()]
      .filter((p) => p.position === position)
      .sort((a, b) => b.points - a.points || a.id.localeCompare(b.id))
    let rank = 1
    pool.forEach((p, i) => {
      if (i === 0 || p.points !== pool[i - 1]!.points) rank = i + 1
      p.rank = rank
    })
  }
  return byPlayer
}
export function hasCompletedParticipation(draft: {
  complete: boolean
  error: string | null
  picks: { own: boolean }[]
}) {
  return draft.complete && !draft.error && draft.picks.some((p) => p.own)
}
