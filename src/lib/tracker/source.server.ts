import "server-only"
import { hasCompletedParticipation } from "@/lib/research/model"
import { createHash } from "node:crypto"
import { unstable_cache } from "next/cache"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
import { fetchNflState } from "@/lib/sleeper/nfl-state.server"
import { fetchSleeperLeagues } from "@/lib/sleeper/leagues.server"
import { sleeperGetJsonWithMetadata } from "@/lib/sleeper/http.server"
import { mapWithBoundedConcurrency } from "@/lib/sleeper/bounded-concurrency"
import {
  normalizeDraftList,
  normalizeDraftDetail,
  normalizeDraftBoard,
} from "@/lib/sleeper/draft-normalization"
import {
  normalizeTrackerMatchups,
  normalizeTrackerRosters,
  type TrackerOverview,
  type TrackerLeague,
  type TrackerDetail,
  type TrackerDraft,
  type TrackerPlayer,
} from "./model"

// This first prototype has one server-controlled provider identity; requests cannot choose an account.
const sleeperOwner = "1373015982733295616"
const fantasyAccount = "dfe53328-459b-4120-99e3-6c2982f87446"
export async function requireTrackerAccess() {
  const access = await getWorkspaceAccess()
  if (!access?.account || access.account.id !== fantasyAccount)
    throw new Error(
      "This tracker belongs to the configured prototype workspace."
    )
  return access
}
export const trackerPlayerToken = (id: string) =>
  createHash("sha256")
    .update(`fantasyhud:player:v1:${id}`)
    .digest("hex")
    .slice(0, 24)
const tokenFor = (id: string, season: number) =>
  createHash("sha256")
    .update(`fantasyhud:tracker:v1:${sleeperOwner}:${season}:${id}`)
    .digest("hex")
    .slice(0, 24)
const read = (segments: string[]) =>
  sleeperGetJsonWithMetadata(segments, {
    maxResponseBytes: 10_000_000,
    timeoutMs: 10_000,
  })

const discovery = unstable_cache(
  async () => {
    const state = await fetchNflState()
    if (
      state.week === null ||
      state.week < 0 ||
      state.week > 18 ||
      state.leagueSeason !== state.season
    )
      throw new Error(
        "Sleeper has not established the tracking week for this season."
      )
    const leagues = await fetchSleeperLeagues(
      sleeperOwner,
      state.leagueSeason,
      { maxResponseBytes: 10_000_000, timeoutMs: 10_000 }
    )
    if (leagues.length > 250)
      throw new Error("The prototype league limit was exceeded.")
    const userDrafts = await read([
      "user",
      sleeperOwner,
      "drafts",
      "nfl",
      String(state.season),
    ])
    const userDraftList = normalizeDraftList(userDrafts.data, state.season)
    return {
      state,
      leagues,
      userDraftIds: userDraftList.map((d) => d.externalDraftId),
      userDraftList,
    }
  },
  ["jarahmacf-tracker-discovery-v2"],
  { revalidate: 120 }
)

const readBoard = unstable_cache(
  async (
    id: string,
    season: number,
    leagueId: string | null
  ): Promise<TrackerDraft> => {
    const [d, p] = await Promise.all([
      read(["draft", id]),
      read(["draft", id, "picks"]),
    ])
    const detail = normalizeDraftDetail(
      d.data,
      season,
      id,
      leagueId ?? undefined
    )
    const board = normalizeDraftBoard(detail, p.data)
    return {
      id,
      type: detail.draftType,
      complete: board.complete,
      teams: detail.teamCount,
      leagueToken: leagueId ? tokenFor(leagueId, season) : undefined,
      budget:
        typeof detail.settings.budget === "number" && detail.settings.budget > 0
          ? detail.settings.budget
          : null,
      error: null,
      picks: board.picks.map((p) => {
        const raw = p.metadata.amount
        const amount =
          typeof raw === "number"
            ? raw
            : typeof raw === "string" && /^\d+(?:\.\d{1,4})?$/.test(raw)
              ? Number(raw)
              : null
        return {
          id: p.externalPlayerId,
          name: p.displayName ?? p.externalPlayerId,
          position: p.position,
          team: p.team,
          pick: p.pickNo,
          round: p.round,
          slot: p.draftSlot,
          // Direct recipient attribution survives traded picks and roster ownership changes.
          own: p.pickedBy === sleeperOwner,
          keeper: p.isKeeper,
          amount:
            detail.draftType === "auction" &&
            amount !== null &&
            Number.isFinite(amount) &&
            amount >= 0
              ? amount
              : null,
        }
      }),
    }
  },
  ["tracker-validated-board-v2"],
  { revalidate: 3600 }
)
async function discoveredBoards(source: Awaited<ReturnType<typeof discovery>>) {
  return mapWithBoundedConcurrency(source.userDraftList, 4, async (d) => {
    try {
      return await readBoard(
        d.externalDraftId,
        source.state.season,
        d.externalLeagueId
      )
    } catch {
      return {
        id: d.externalDraftId,
        type: d.draftType,
        complete: false,
        teams: d.teamCount,
        leagueToken: d.externalLeagueId
          ? tokenFor(d.externalLeagueId, source.state.season)
          : undefined,
        error: "Board could not be validated; participation unresolved.",
        picks: [],
      } satisfies TrackerDraft
    }
  })
}
export async function loadTrackerResearchSource() {
  await requireTrackerAccess()
  const source = await discovery()
  const boards = await discoveredBoards(source)
  const overview = await overviewSource()
  return { boards, overview, state: source.state }
}

async function leagueSnapshot(
  league: Awaited<ReturnType<typeof discovery>>["leagues"][number],
  week: number
): Promise<TrackerLeague> {
  const base = {
    token: tokenFor(league.externalLeagueId, league.season),
    name: league.name,
    season: league.season,
    teams: league.teamCount,
    bestBall: league.isBestBall,
    format: league.scoringFormat,
    management: league.rosterManagementType,
    scoring: league.scoringSettings,
    positions: league.rosterPositions,
    fetchedAt: new Date().toISOString(),
  }
  try {
    const [r, m] = await Promise.all([
      read(["league", league.externalLeagueId, "rosters"]),
      week > 0
        ? read(["league", league.externalLeagueId, "matchups", String(week)])
        : Promise.resolve({ data: [], fetchedAt: base.fetchedAt }),
    ])
    const rosters = normalizeTrackerRosters(r.data, sleeperOwner),
      matchups = normalizeTrackerMatchups(m.data)
    if (
      rosters.length !== league.teamCount ||
      matchups.some((m) => !rosters.some((r) => r.id === m.rosterId))
    )
      throw new Error("Incomplete roster collection.")
    return { ...base, rosters, matchups, error: null, fetchedAt: m.fetchedAt }
  } catch {
    return {
      ...base,
      rosters: [],
      matchups: [],
      error:
        "Sleeper could not refresh this league. Its absence is not a removal.",
    }
  }
}
const overviewSource = unstable_cache(
  async () => {
    const source = await discovery()
    const { state, leagues } = source
    const boards = await discoveredBoards(source)
    const completed = boards.filter(hasCompletedParticipation)
    const included = new Set(completed.map((d) => d.leagueToken))
    const snapshots = await mapWithBoundedConcurrency(leagues, 4, (l) =>
      leagueSnapshot(l, state.week!)
    )
    return {
      season: state.season,
      week: state.week!,
      seasonType: state.seasonType,
      fetchedAt: new Date().toISOString(),
      leagues: snapshots.filter((l) => included.has(l.token)),
      otherLeagues: snapshots.filter((l) => !included.has(l.token)),
      membershipCount: leagues.length,
      draftSummary: {
        completed: completed.length,
        snake: completed.filter(
          (d) => d.type === "snake" || d.type === "linear"
        ).length,
        auction: completed.filter((d) => d.type === "auction").length,
        unresolved: boards.filter((d) => d.error).length,
      },
    }
  },
  ["jarahmacf-tracker-overview-v2"],
  { revalidate: 120 }
)

export async function loadTrackerOverview(): Promise<TrackerOverview> {
  const access = await requireTrackerAccess()
  const overview = await overviewSource()
  const playerIds = [
    ...new Set(
      overview.leagues.flatMap((l) =>
        l.rosters.filter((r) => r.owned).flatMap((r) => r.players ?? [])
      )
    ),
  ]
  const players: TrackerPlayer[] = []
  for (let start = 0; start < playerIds.length; start += 150) {
    const result = await access.supabase
      .from("player_external_ids")
      .select(
        "external_id, players!inner(display_name, primary_position, nfl_team)"
      )
      .eq("namespace", "sleeper")
      .eq("is_primary", true)
      .is("removed_at", null)
      .in("external_id", playerIds.slice(start, start + 150))
    if (!result.error)
      players.push(
        ...result.data.map((r) => ({
          token: trackerPlayerToken(r.external_id),
          id: r.external_id,
          name: r.players.display_name ?? r.external_id,
          position: r.players.primary_position ?? "?",
          team: r.players.nfl_team,
        }))
      )
  }
  return { ...overview, players }
}

const detailSource = unstable_cache(
  async (token: string): Promise<TrackerDetail> => {
    const { state, leagues, userDraftIds } = await discovery()
    const source = leagues.find(
      (l) => tokenFor(l.externalLeagueId, l.season) === token
    )
    if (!source)
      throw new Error("League is not in this prototype's current collection.")
    const league = await leagueSnapshot(source, state.week!)
    if (league.error) throw new Error(league.error)
    const list = await read(["league", source.externalLeagueId, "drafts"])
    const drafts = normalizeDraftList(
      list.data,
      state.season,
      source.externalLeagueId
    )
    const boards = await mapWithBoundedConcurrency(drafts, 3, async (d) => {
      try {
        const board = await readBoard(
          d.externalDraftId,
          state.season,
          source.externalLeagueId
        )
        return {
          ...board,
          picks: board.picks.map((p) => ({
            ...p,
            own: userDraftIds.includes(d.externalDraftId) && p.own,
          })),
        }
      } catch {
        return {
          id: d.externalDraftId,
          type: d.draftType,
          complete: false,
          teams: d.teamCount,
          picks: [],
          error: "This board could not be fully validated.",
        } satisfies TrackerDraft
      }
    })
    const weeks = await mapWithBoundedConcurrency(
      Array.from({ length: state.week! }, (_, i) => i + 1),
      3,
      async (week) => {
        if (week === state.week)
          return {
            week,
            fetchedAt: league.fetchedAt,
            matchups: league.matchups,
            error: league.error,
          }
        try {
          const response = await read([
            "league",
            source.externalLeagueId,
            "matchups",
            String(week),
          ])
          return {
            week,
            fetchedAt: response.fetchedAt,
            matchups: normalizeTrackerMatchups(response.data),
            error: null,
          }
        } catch {
          return {
            week,
            fetchedAt: new Date().toISOString(),
            matchups: null,
            error: "Week could not be refreshed.",
          }
        }
      }
    )
    return {
      league,
      drafts: boards,
      weeks,
      fetchedAt: new Date().toISOString(),
    }
  },
  ["jarahmacf-tracker-detail-v2"],
  { revalidate: 120 }
)
export async function loadTrackerDetail(token: string) {
  await requireTrackerAccess()
  if (!/^[a-f0-9]{24}$/.test(token))
    throw new Error("Invalid league selection.")
  return detailSource(token)
}
