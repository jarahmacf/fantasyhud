import "server-only"
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
    const userDraftIds = normalizeDraftList(userDrafts.data, state.season).map(
      (d) => d.externalDraftId
    )
    return { state, leagues, userDraftIds }
  },
  ["jarahmacf-tracker-discovery-v1"],
  { revalidate: 120 }
)

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
    const { state, leagues } = await discovery()
    const snapshots = await mapWithBoundedConcurrency(leagues, 4, (l) =>
      leagueSnapshot(l, state.week!)
    )
    return {
      season: state.season,
      week: state.week!,
      seasonType: state.seasonType,
      fetchedAt: new Date().toISOString(),
      leagues: snapshots,
    }
  },
  ["jarahmacf-tracker-overview-v1"],
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
    const boards = await mapWithBoundedConcurrency(
      drafts,
      3,
      async (draft): Promise<TrackerDraft> => {
        try {
          const [d, p] = await Promise.all([
            read(["draft", draft.externalDraftId]),
            read(["draft", draft.externalDraftId, "picks"]),
          ])
          const detail = normalizeDraftDetail(
            d.data,
            state.season,
            draft.externalDraftId,
            source.externalLeagueId
          )
          const board = normalizeDraftBoard(detail, p.data)
          const owned = new Set(
            league.rosters.filter((r) => r.owned).map((r) => r.id)
          )
          const ownSlots = new Set(
            board.slots
              .filter(
                (s) =>
                  s.sourceUserIds?.includes(sleeperOwner) ||
                  (s.externalRosterId !== null &&
                    owned.has(String(s.externalRosterId)))
              )
              .map((s) => s.draftSlot)
          )
          for (const pick of board.picks)
            if (pick.pickedBy === sleeperOwner) ownSlots.add(pick.draftSlot)
          if (ownSlots.size > 1) throw new Error("Participation is ambiguous.")
          return {
            id: detail.externalDraftId,
            type: detail.draftType,
            complete: board.complete,
            teams: detail.teamCount,
            error: null,
            picks: board.picks.map((p) => {
              const amount =
                detail.draftType === "auction" ? p.metadata.amount : null
              // PickWorth's amount field is retained as an explicitly source-reported cost.
              const parsed =
                typeof amount === "number"
                  ? amount
                  : typeof amount === "string" &&
                      /^\d+(?:\.\d{1,4})?$/.test(amount)
                    ? Number(amount)
                    : null
              return {
                id: p.externalPlayerId,
                name: p.displayName ?? p.externalPlayerId,
                position: p.position,
                team: p.team,
                pick: p.pickNo,
                round: p.round,
                slot: p.draftSlot,
                own:
                  userDraftIds.includes(detail.externalDraftId) &&
                  ownSlots.has(p.draftSlot),
                keeper: p.isKeeper,
                amount:
                  parsed !== null && Number.isFinite(parsed) && parsed >= 0
                    ? parsed
                    : null,
              }
            }),
          }
        } catch {
          return {
            id: draft.externalDraftId,
            type: draft.draftType,
            complete: false,
            teams: draft.teamCount,
            picks: [],
            error:
              "This board could not be fully validated. Prior saved data is unchanged.",
          }
        }
      }
    )
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
  ["jarahmacf-tracker-detail-v1"],
  { revalidate: 120 }
)
export async function loadTrackerDetail(token: string) {
  await requireTrackerAccess()
  if (!/^[a-f0-9]{24}$/.test(token))
    throw new Error("Invalid league selection.")
  return detailSource(token)
}
