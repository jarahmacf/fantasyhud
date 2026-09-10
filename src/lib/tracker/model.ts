import { exactDraftToken } from "@/lib/sleeper/draft-normalization"

export type TrackerPlayer = {
  id: string
  name: string
  position: string
  team: string | null
}
export type TrackerMatchup = {
  rosterId: string
  matchupId: number | null
  points: number | null
  customPoints: number | null
  players: string[] | null
  starters: string[] | null
  playerPoints: Record<string, number> | null
}
export type TrackerRoster = {
  id: string
  owned: boolean
  players: string[] | null
  wins: number | null
  losses: number | null
  ties: number | null
}
export type TrackerWeek = {
  week: number
  fetchedAt: string
  matchups: TrackerMatchup[] | null
  error: string | null
}
export type TrackerPick = {
  id: string
  name: string
  position: string | null
  team: string | null
  pick: number
  round: number
  slot: number
  own: boolean
  keeper: boolean | null
  amount: number | null
}
export type TrackerDraft = {
  id: string
  type: string
  complete: boolean
  teams: number | null
  picks: TrackerPick[]
  error: string | null
}
export type TrackerLeague = {
  token: string
  name: string
  season: number
  teams: number
  bestBall: boolean
  format: string
  management: string
  scoring: Record<string, unknown>
  positions: string[]
  rosters: TrackerRoster[]
  matchups: TrackerMatchup[]
  error: string | null
  fetchedAt: string
}
export type TrackerOverview = {
  season: number
  week: number
  seasonType: string
  fetchedAt: string
  leagues: TrackerLeague[]
  players: TrackerPlayer[]
}
export type TrackerDetail = {
  league: TrackerLeague
  drafts: TrackerDraft[]
  weeks: TrackerWeek[]
  fetchedAt: string
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Invalid Sleeper collection.")
  return value as Record<string, unknown>
}
function finite(value: unknown): number | null {
  if (value == null) return null
  if (typeof value !== "number" || !Number.isFinite(value))
    throw new Error("Invalid Sleeper score.")
  return value
}
export function rosterId(value: unknown): string {
  if (
    typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value > 0 &&
    value <= 1000
  )
    return String(value)
  if (typeof value === "string" && /^[1-9]\d{0,2}$/.test(value)) return value
  throw new Error("Invalid roster identifier.")
}
function ids(value: unknown, placeholders = false): string[] | null {
  if (value == null) return null
  if (!Array.isArray(value) || value.length > 1000)
    throw new Error("Invalid player collection.")
  const result = value.map(exactDraftToken)
  if (
    new Set(result.filter((id) => !placeholders || id !== "0")).size !==
    result.filter((id) => !placeholders || id !== "0").length
  )
    throw new Error("Duplicate player identity.")
  return result
}
export function normalizeTrackerRosters(
  value: unknown,
  ownerId: string
): TrackerRoster[] {
  if (!Array.isArray(value) || value.length > 1000)
    throw new Error("Invalid roster collection.")
  const result = value.map((item) => {
    const row = object(item),
      settings = row.settings == null ? {} : object(row.settings)
    const coOwners = ids(row.co_owners)
    return {
      id: rosterId(row.roster_id),
      owned: row.owner_id === ownerId || Boolean(coOwners?.includes(ownerId)),
      players: ids(row.players),
      wins: finite(settings.wins),
      losses: finite(settings.losses),
      ties: finite(settings.ties),
    }
  })
  if (new Set(result.map((r) => r.id)).size !== result.length)
    throw new Error("Duplicate roster identity.")
  return result
}
export function normalizeTrackerMatchups(value: unknown): TrackerMatchup[] {
  if (!Array.isArray(value) || value.length > 1000)
    throw new Error("Invalid matchup collection.")
  const result = value.map((item) => {
    const row = object(item),
      players = ids(row.players),
      starters = ids(row.starters, true)
    if (
      starters?.some(
        (id) => id !== "0" && players !== null && !players.includes(id)
      )
    )
      throw new Error("A starter is missing from its matchup roster.")
    let playerPoints: Record<string, number> | null = null
    if (row.players_points != null) {
      const source = object(row.players_points)
      if (Object.keys(source).length > 1000)
        throw new Error("Too many player scores.")
      playerPoints = Object.fromEntries(
        Object.entries(source).map(([key, value]) => {
          const id = exactDraftToken(key),
            score = finite(value)
          if (
            id === "0" ||
            score === null ||
            (players && !players.includes(id))
          )
            throw new Error("Invalid player score identity.")
          return [id, score]
        })
      )
    }
    const matchupId = finite(row.matchup_id)
    if (
      matchupId !== null &&
      (!Number.isSafeInteger(matchupId) || matchupId < 1)
    )
      throw new Error("Invalid matchup identifier.")
    return {
      rosterId: rosterId(row.roster_id),
      matchupId,
      points: finite(row.points),
      customPoints: finite(row.custom_points),
      players,
      starters,
      playerPoints,
    }
  })
  if (new Set(result.map((r) => r.rosterId)).size !== result.length)
    throw new Error("Duplicate matchup roster.")
  return result
}

/** League-source ranks, deliberately separate from full-NFL or market ADP ranks. */
export function evaluateTrackerDraft(
  draft: TrackerDraft,
  weeks: readonly TrackerWeek[],
  throughWeek: number
) {
  const selected = weeks.filter((w) => w.week <= throughWeek)
  const observations = new Map<string, Map<number, number>>()
  let activity = false
  for (const week of selected) {
    const seen = new Map<string, number>()
    for (const matchup of week.matchups ?? [])
      for (const [id, points] of Object.entries(matchup.playerPoints ?? {})) {
        if (seen.has(id) && seen.get(id) !== points)
          throw new Error("Conflicting player scores in one league week.")
        seen.set(id, points)
        if (points !== 0) activity = true
      }
    for (const [id, points] of seen) {
      const history = observations.get(id) ?? new Map<number, number>()
      history.set(week.week, points)
      observations.set(id, history)
    }
  }
  const periodsComplete =
    selected.length === throughWeek &&
    selected.every((w) => w.matchups !== null && !w.error) &&
    new Set(selected.map((w) => w.week)).size === throughWeek
  const rows = draft.picks.map((p) => {
    const history = observations.get(p.id)
    const observedWeeks = history?.size ?? 0
    return {
      ...p,
      priceRank: null as number | null,
      actualRank: null as number | null,
      rankDelta: null as number | null,
      pointsAbovePrice: null as number | null,
      points: observedWeeks
        ? [...history!.values()].reduce((a, b) => a + b, 0)
        : null,
      observedWeeks,
      weekly: selected.map((w) => ({
        week: w.week,
        points: history?.get(w.week) ?? null,
      })),
    }
  })
  for (const position of new Set(rows.map((p) => p.position))) {
    if (!position) continue
    const pool = rows.filter((p) => p.position === position)
    const auction = draft.type === "auction"
    const priceAvailable =
      draft.complete &&
      (auction
        ? pool.every((p) => p.amount !== null)
        : ["snake", "linear"].includes(draft.type))
    const price = [...pool].sort((a, b) =>
      auction ? b.amount! - a.amount! || a.pick - b.pick : a.pick - b.pick
    )
    let rank = 1
    price.forEach((p, i) => {
      if (!auction || i === 0 || p.amount !== price[i - 1]!.amount) rank = i + 1
      if (priceAvailable) p.priceRank = rank
    })
    const scoresAvailable =
      draft.complete &&
      activity &&
      periodsComplete &&
      pool.every((p) => p.observedWeeks === throughWeek)
    if (!scoresAvailable) continue
    const scores = [...pool].sort(
      (a, b) => b.points! - a.points! || a.pick - b.pick
    )
    scores.forEach((p, i) => {
      if (i === 0 || p.points !== scores[i - 1]!.points) rank = i + 1
      p.actualRank = rank
      if (p.priceRank !== null) {
        p.rankDelta = p.priceRank - rank
        const benchmark = scores[p.priceRank - 1]?.points
        p.pointsAbovePrice = benchmark == null ? null : p.points! - benchmark
      }
    })
  }
  return rows
}

/** Failed refreshes preserve the prior observation and its timestamp, explicitly marked stale. */
export function mergeTrackerOverview(
  previous: TrackerOverview | null,
  next: TrackerOverview
): TrackerOverview {
  if (!previous || previous.season !== next.season) return next
  const old = new Map(previous.leagues.map((l) => [l.token, l]))
  return {
    ...next,
    leagues: next.leagues.map((l) =>
      l.error && old.has(l.token) ? { ...old.get(l.token)!, error: l.error } : l
    ),
  }
}
