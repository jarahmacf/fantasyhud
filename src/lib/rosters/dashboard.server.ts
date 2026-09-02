import "server-only"

import { createServerSupabaseClient } from "@/lib/supabase/server"
import type {
  CurrentHoldingPreviewRow,
  OwnedRosterRow,
  RosterAnnotationDisplayState,
} from "./dashboard-types"

export type {
  CurrentHoldingPreviewRow,
  OwnedRosterRow,
} from "./dashboard-types"

type ServerSupabaseClient = Awaited<
  ReturnType<typeof createServerSupabaseClient>
>

export type RosterRunStatus =
  "not_started" | "running" | "succeeded" | "failed" | "partial"

export type RosterPrerequisite = "ready" | "league_discovery" | "player_catalog"

export type RosterDashboard = {
  prerequisite: RosterPrerequisite
  currentLeagueSeason: number | null
  currentSeasonLeagueCount: number
  latestStatus: RosterRunStatus
  hasSuccessfulImport: boolean
  lastRefreshedAt: string | null
  ownedRosterCount: number
  currentHoldingCount: number
  unresolvedLeagueCount: number
  ownedRosters: OwnedRosterRow[]
  holdingPreview: CurrentHoldingPreviewRow[]
}

type RawOwnership = {
  id: string
  roster_id: string
  league_id: string
  ownership_role: string
  fantasy_account_leagues:
    | {
        fantasy_account_id: string
        league_id: string
        removed_at: string | null
        roster_ownership_status: string | null
      }
    | {
        fantasy_account_id: string
        league_id: string
        removed_at: string | null
        roster_ownership_status: string | null
      }[]
}

type RawRoster = {
  id: string
  league_id: string
  external_roster_id: number
  owner_external_user_id: string | null
  source_player_ids: string[] | null
  source_starter_ids: string[] | null
  source_reserve_ids: string[] | null
  source_taxi_ids: string[] | null
  source_keeper_ids: string[] | null
  leagues: { id: string; name: string } | { id: string; name: string }[]
}

type RawLeagueUser = {
  league_id: string
  external_user_id: string
  team_name: string | null
  display_name: string | null
  username: string | null
}

type RawMembership = {
  id: string
  roster_id: string
  source_order: number | null
  is_starter: boolean
  is_reserve: boolean
  is_taxi: boolean
  is_keeper: boolean
  source_metadata: unknown
  players:
    | {
        display_name: string | null
        primary_position: string | null
        nfl_team: string | null
      }
    | {
        display_name: string | null
        primary_position: string | null
        nfl_team: string | null
      }[]
  player_external_ids:
    | {
        external_id: string
        namespace: string
        sport: string
        is_primary: boolean
        removed_at: string | null
      }
    | {
        external_id: string
        namespace: string
        sport: string
        is_primary: boolean
        removed_at: string | null
      }[]
}

const pageSize = 1_000
const idChunkSize = 50
const maximumSourceMetadataBytes = 32_768
const maximumNormalizationWarningFields = 16
const safeWarningTokenPattern = /^[a-z][a-z0-9_]{0,63}$/u
const validStatuses = new Set(["running", "succeeded", "failed", "partial"])

export class RosterDashboardQueryError extends Error {}

function firstRelated<Row>(value: Row | Row[]): Row | undefined {
  return Array.isArray(value) ? value[0] : value
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false
  }
  const prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

function jsonByteLength(value: unknown): number {
  try {
    return new TextEncoder().encode(JSON.stringify(value)).byteLength
  } catch {
    throw new RosterDashboardQueryError()
  }
}

export function sourceArrayCount(
  values: readonly string[] | null,
  excludedValue?: string
): number | null {
  if (values === null) return null
  if (excludedValue === undefined) return values.length
  return values.filter((value) => value !== excludedValue).length
}

export function deriveMembershipAnnotationStates(
  sourceMetadata: unknown,
  flags: {
    isStarter: boolean
    isReserve: boolean
    isTaxi: boolean
    isKeeper: boolean
  }
): {
  starterState: RosterAnnotationDisplayState
  reserveState: RosterAnnotationDisplayState
  taxiState: RosterAnnotationDisplayState
  keeperState: RosterAnnotationDisplayState
} {
  if (
    !isPlainObject(sourceMetadata) ||
    jsonByteLength(sourceMetadata) > maximumSourceMetadataBytes ||
    Object.keys(sourceMetadata).length !== 2 ||
    !Object.hasOwn(sourceMetadata, "annotation_source_state") ||
    !Object.hasOwn(sourceMetadata, "normalization_warning_fields")
  ) {
    throw new RosterDashboardQueryError()
  }

  const annotationState = sourceMetadata.annotation_source_state
  if (
    !isPlainObject(annotationState) ||
    Object.keys(annotationState).length !== 4
  ) {
    throw new RosterDashboardQueryError()
  }

  const fields = ["starters", "reserve", "taxi", "keepers"] as const
  for (const field of fields) {
    if (
      annotationState[field] !== "known" &&
      annotationState[field] !== "unknown"
    ) {
      throw new RosterDashboardQueryError()
    }
  }

  const warnings = sourceMetadata.normalization_warning_fields
  if (
    !Array.isArray(warnings) ||
    warnings.length > maximumNormalizationWarningFields ||
    warnings.some(
      (warning) =>
        typeof warning !== "string" || !safeWarningTokenPattern.test(warning)
    ) ||
    new Set(warnings).size !== warnings.length
  ) {
    throw new RosterDashboardQueryError()
  }

  const displayState = (
    sourceState: unknown,
    retainedValue: boolean
  ): RosterAnnotationDisplayState =>
    sourceState === "unknown" ? "not_reported" : retainedValue ? "yes" : "no"

  return {
    starterState: displayState(annotationState.starters, flags.isStarter),
    reserveState: displayState(annotationState.reserve, flags.isReserve),
    taxiState: displayState(annotationState.taxi, flags.isTaxi),
    keeperState: displayState(annotationState.keepers, flags.isKeeper),
  }
}

function compareText(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0
}

function chunks<Row>(values: readonly Row[], size = idChunkSize): Row[][] {
  const result: Row[][] = []
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size))
  }
  return result
}

function unresolvedCount(value: unknown, required: boolean): number {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    if (required) throw new RosterDashboardQueryError()
    return 0
  }
  const count = (value as Record<string, unknown>)[
    "unresolved_ownership_leagues"
  ]
  if (count === undefined && !required) return 0
  if (typeof count !== "number" || !Number.isSafeInteger(count) || count < 0) {
    throw new RosterDashboardQueryError()
  }
  return count
}

async function loadAllOwnerships(
  supabase: ServerSupabaseClient,
  fantasyAccountId: string
): Promise<RawOwnership[]> {
  const rows: RawOwnership[] = []
  for (let from = 0; ; from += pageSize) {
    const result = await supabase
      .from("fantasy_account_rosters")
      .select(
        "id, roster_id, league_id, ownership_role, fantasy_account_leagues!inner(fantasy_account_id, league_id, removed_at, roster_ownership_status)"
      )
      .eq("fantasy_account_id", fantasyAccountId)
      .eq("fantasy_account_leagues.fantasy_account_id", fantasyAccountId)
      .eq("fantasy_account_leagues.roster_ownership_status", "owned")
      .is("removed_at", null)
      .is("fantasy_account_leagues.removed_at", null)
      .order("league_id")
      .order("roster_id")
      .range(from, from + pageSize - 1)
    if (result.error) throw new RosterDashboardQueryError()
    const page = result.data as RawOwnership[]
    for (const ownership of page) {
      const association = firstRelated(ownership.fantasy_account_leagues)
      if (
        !association ||
        association.fantasy_account_id !== fantasyAccountId ||
        association.league_id !== ownership.league_id ||
        association.removed_at !== null ||
        association.roster_ownership_status !== "owned"
      ) {
        throw new RosterDashboardQueryError()
      }
    }
    rows.push(...page)
    if (page.length < pageSize) return rows
  }
}

async function loadCurrentRosters(
  supabase: ServerSupabaseClient,
  rosterIds: readonly string[],
  season: number
): Promise<{ rows: RawRoster[]; exactCount: number }> {
  const rows: RawRoster[] = []
  let exactCount = 0
  for (const rosterIdChunk of chunks(rosterIds)) {
    const countResult = await supabase
      .from("rosters")
      .select("id, leagues!inner(id)", { count: "exact", head: true })
      .in("id", rosterIdChunk)
      .is("removed_at", null)
      .eq("leagues.provider", "sleeper")
      .eq("leagues.sport", "nfl")
      .eq("leagues.season", season)
    if (countResult.error || countResult.count === null) {
      throw new RosterDashboardQueryError()
    }
    exactCount += countResult.count

    const result = await supabase
      .from("rosters")
      .select(
        "id, league_id, external_roster_id, owner_external_user_id, source_player_ids, source_starter_ids, source_reserve_ids, source_taxi_ids, source_keeper_ids, leagues!inner(id, name, provider, sport, season)"
      )
      .in("id", rosterIdChunk)
      .is("removed_at", null)
      .eq("leagues.provider", "sleeper")
      .eq("leagues.sport", "nfl")
      .eq("leagues.season", season)
    if (result.error) throw new RosterDashboardQueryError()
    rows.push(...(result.data as RawRoster[]))
  }
  if (rows.length !== exactCount) throw new RosterDashboardQueryError()
  return { rows, exactCount }
}

async function countCurrentOwnerships(
  supabase: ServerSupabaseClient,
  fantasyAccountId: string,
  rosterIds: readonly string[]
): Promise<number> {
  let exactCount = 0
  for (const rosterIdChunk of chunks(rosterIds)) {
    const result = await supabase
      .from("fantasy_account_rosters")
      .select("id, fantasy_account_leagues!inner(id)", {
        count: "exact",
        head: true,
      })
      .eq("fantasy_account_id", fantasyAccountId)
      .eq("fantasy_account_leagues.fantasy_account_id", fantasyAccountId)
      .eq("fantasy_account_leagues.roster_ownership_status", "owned")
      .in("roster_id", rosterIdChunk)
      .is("removed_at", null)
      .is("fantasy_account_leagues.removed_at", null)
    if (result.error || result.count === null) {
      throw new RosterDashboardQueryError()
    }
    exactCount += result.count
  }
  return exactCount
}

async function loadLeagueUsers(
  supabase: ServerSupabaseClient,
  leagueIds: readonly string[]
): Promise<RawLeagueUser[]> {
  const rows: RawLeagueUser[] = []
  for (const leagueIdChunk of chunks(leagueIds)) {
    for (let from = 0; ; from += pageSize) {
      const result = await supabase
        .from("league_users")
        .select(
          "league_id, external_user_id, team_name, display_name, username"
        )
        .in("league_id", leagueIdChunk)
        .is("removed_at", null)
        .order("league_id")
        .order("external_user_id")
        .range(from, from + pageSize - 1)
      if (result.error) throw new RosterDashboardQueryError()
      const page = result.data as RawLeagueUser[]
      rows.push(...page)
      if (page.length < pageSize) break
    }
  }
  return rows
}

async function loadMemberships(
  supabase: ServerSupabaseClient,
  rosterIds: readonly string[]
): Promise<{ rows: RawMembership[]; exactCount: number }> {
  const rows: RawMembership[] = []
  let exactCount = 0

  for (const rosterIdChunk of chunks(rosterIds)) {
    const countResult = await supabase
      .from("roster_players")
      .select("id", { count: "exact", head: true })
      .in("roster_id", rosterIdChunk)
      .is("removed_at", null)
    if (countResult.error || countResult.count === null) {
      throw new RosterDashboardQueryError()
    }
    exactCount += countResult.count

    for (let from = 0; ; from += pageSize) {
      const result = await supabase
        .from("roster_players")
        .select(
          "id, roster_id, source_order, is_starter, is_reserve, is_taxi, is_keeper, source_metadata, players!roster_players_player_id_fkey(display_name, primary_position, nfl_team), player_external_ids!roster_players_mapping_player_fkey(external_id, namespace, sport, is_primary, removed_at)"
        )
        .in("roster_id", rosterIdChunk)
        .is("removed_at", null)
        .order("roster_id")
        .order("source_order", { ascending: true, nullsFirst: false })
        .range(from, from + pageSize - 1)
      if (result.error) throw new RosterDashboardQueryError()
      const page = result.data as unknown as RawMembership[]
      rows.push(...page)
      if (page.length < pageSize) break
    }
  }

  if (rows.length !== exactCount) throw new RosterDashboardQueryError()
  return { rows, exactCount }
}

export async function loadRosterDashboardData(
  supabase: ServerSupabaseClient,
  fantasyAccountId: string
): Promise<RosterDashboard> {
  const seasonResult = await supabase
    .from("provider_season_states")
    .select("league_season")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .maybeSingle()
  if (seasonResult.error) throw new RosterDashboardQueryError()

  const season = seasonResult.data?.league_season ?? null
  if (season === null) {
    return {
      prerequisite: "league_discovery",
      currentLeagueSeason: null,
      currentSeasonLeagueCount: 0,
      latestStatus: "not_started",
      hasSuccessfulImport: false,
      lastRefreshedAt: null,
      ownedRosterCount: 0,
      currentHoldingCount: 0,
      unresolvedLeagueCount: 0,
      ownedRosters: [],
      holdingPreview: [],
    }
  }

  const [leagueCount, leagueSuccess, catalogSuccess, latestRun, latestSuccess] =
    await Promise.all([
      supabase
        .from("fantasy_account_leagues")
        .select("league_id, leagues!inner(id)", { count: "exact", head: true })
        .eq("fantasy_account_id", fantasyAccountId)
        .is("removed_at", null)
        .eq("leagues.provider", "sleeper")
        .eq("leagues.sport", "nfl")
        .eq("leagues.season", season),
      supabase
        .from("sync_runs")
        .select("id")
        .eq("fantasy_account_id", fantasyAccountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "league_discovery")
        .eq("season", season)
        .eq("status", "succeeded")
        .limit(1)
        .maybeSingle(),
      supabase
        .from("provider_catalog_runs")
        .select("id")
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("catalog", "players")
        .eq("status", "succeeded")
        .limit(1)
        .maybeSingle(),
      supabase
        .from("sync_runs")
        .select("status, result_counts, finished_at")
        .eq("fantasy_account_id", fantasyAccountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "roster_sync")
        .eq("season", season)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from("sync_runs")
        .select("finished_at")
        .eq("fantasy_account_id", fantasyAccountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "roster_sync")
        .eq("season", season)
        .in("status", ["succeeded", "partial"])
        .order("finished_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ])

  if (
    leagueCount.error ||
    leagueCount.count === null ||
    leagueSuccess.error ||
    catalogSuccess.error ||
    latestRun.error ||
    latestSuccess.error
  ) {
    throw new RosterDashboardQueryError()
  }

  const rawStatus = latestRun.data?.status
  if (rawStatus !== undefined && !validStatuses.has(rawStatus)) {
    throw new RosterDashboardQueryError()
  }
  const latestStatus = (rawStatus ?? "not_started") as RosterRunStatus
  const unresolvedLeagueCount = unresolvedCount(
    latestRun.data?.result_counts,
    latestStatus === "partial"
  )
  const hasSuccessfulImport = latestSuccess.data !== null
  const prerequisite: RosterPrerequisite =
    leagueCount.count < 1 || !leagueSuccess.data
      ? "league_discovery"
      : !catalogSuccess.data
        ? "player_catalog"
        : "ready"

  if (prerequisite !== "ready") {
    return {
      prerequisite,
      currentLeagueSeason: season,
      currentSeasonLeagueCount: leagueCount.count,
      latestStatus,
      hasSuccessfulImport,
      lastRefreshedAt: latestSuccess.data?.finished_at ?? null,
      ownedRosterCount: 0,
      currentHoldingCount: 0,
      unresolvedLeagueCount,
      ownedRosters: [],
      holdingPreview: [],
    }
  }

  const allOwnerships = await loadAllOwnerships(supabase, fantasyAccountId)
  const currentRosters = await loadCurrentRosters(
    supabase,
    allOwnerships.map((ownership) => ownership.roster_id),
    season
  )
  const rosters = currentRosters.rows
  const rosterById = new Map(rosters.map((roster) => [roster.id, roster]))
  const ownerships = allOwnerships.filter((ownership) =>
    rosterById.has(ownership.roster_id)
  )
  if (ownerships.length !== currentRosters.exactCount) {
    throw new RosterDashboardQueryError()
  }

  const rosterIds = ownerships.map((ownership) => ownership.roster_id)
  const leagueIds = [...new Set(rosters.map((roster) => roster.league_id))]
  const [leagueUsers, memberships, exactOwnershipCount] = await Promise.all([
    loadLeagueUsers(supabase, leagueIds),
    loadMemberships(supabase, rosterIds),
    countCurrentOwnerships(supabase, fantasyAccountId, rosterIds),
  ])
  if (
    exactOwnershipCount !== ownerships.length ||
    exactOwnershipCount !== currentRosters.exactCount
  ) {
    throw new RosterDashboardQueryError()
  }

  const leagueUserByIdentity = new Map(
    leagueUsers.map((user) => [
      `${user.league_id}\u0000${user.external_user_id}`,
      user,
    ])
  )
  const ownedRosters = ownerships
    .map((ownership): OwnedRosterRow => {
      const roster = rosterById.get(ownership.roster_id)
      if (!roster) throw new RosterDashboardQueryError()
      const league = firstRelated(roster.leagues)
      if (!league) throw new RosterDashboardQueryError()
      const owner = roster.owner_external_user_id
        ? leagueUserByIdentity.get(
            `${roster.league_id}\u0000${roster.owner_external_user_id}`
          )
        : undefined
      if (
        ownership.ownership_role !== "owner" &&
        ownership.ownership_role !== "co_owner"
      ) {
        throw new RosterDashboardQueryError()
      }

      return {
        id: ownership.id,
        leagueName: league.name,
        teamName:
          owner?.team_name ??
          owner?.display_name ??
          owner?.username ??
          `Roster ${roster.external_roster_id}`,
        ownershipRole: ownership.ownership_role,
        playerCount: sourceArrayCount(roster.source_player_ids),
        starterCount: sourceArrayCount(roster.source_starter_ids, "0"),
        reserveCount: sourceArrayCount(roster.source_reserve_ids),
        taxiCount: sourceArrayCount(roster.source_taxi_ids),
        keeperCount: sourceArrayCount(roster.source_keeper_ids),
      }
    })
    .sort(
      (left, right) =>
        compareText(left.leagueName, right.leagueName) ||
        compareText(left.teamName, right.teamName)
    )

  const leagueNameByRoster = new Map(
    rosters.map((roster) => {
      const league = firstRelated(roster.leagues)
      if (!league) throw new RosterDashboardQueryError()
      return [roster.id, league.name] as const
    })
  )

  const holdingPreview = memberships.rows
    .map((membership) => {
      const player = firstRelated(membership.players)
      const mapping = firstRelated(membership.player_external_ids)
      const leagueName = leagueNameByRoster.get(membership.roster_id)
      if (
        !player ||
        !mapping ||
        !leagueName ||
        mapping.namespace !== "sleeper" ||
        mapping.sport !== "nfl" ||
        !mapping.is_primary ||
        mapping.removed_at !== null
      ) {
        throw new RosterDashboardQueryError()
      }
      const annotationStates = deriveMembershipAnnotationStates(
        membership.source_metadata,
        {
          isStarter: membership.is_starter,
          isReserve: membership.is_reserve,
          isTaxi: membership.is_taxi,
          isKeeper: membership.is_keeper,
        }
      )
      return {
        id: membership.id,
        playerLabel: player.display_name ?? mapping.external_id,
        leagueName,
        primaryPosition: player.primary_position,
        nflTeam: player.nfl_team,
        ...annotationStates,
        sourceOrder: membership.source_order,
      }
    })
    .sort(
      (left, right) =>
        compareText(left.leagueName, right.leagueName) ||
        (left.sourceOrder ?? Number.MAX_SAFE_INTEGER) -
          (right.sourceOrder ?? Number.MAX_SAFE_INTEGER) ||
        compareText(left.playerLabel, right.playerLabel)
    )
    .slice(0, 100)
    .map((holding): CurrentHoldingPreviewRow => ({
      id: holding.id,
      playerLabel: holding.playerLabel,
      leagueName: holding.leagueName,
      primaryPosition: holding.primaryPosition,
      nflTeam: holding.nflTeam,
      starterState: holding.starterState,
      reserveState: holding.reserveState,
      taxiState: holding.taxiState,
      keeperState: holding.keeperState,
    }))

  return {
    prerequisite,
    currentLeagueSeason: season,
    currentSeasonLeagueCount: leagueCount.count,
    latestStatus,
    hasSuccessfulImport,
    lastRefreshedAt: latestSuccess.data?.finished_at ?? null,
    ownedRosterCount: exactOwnershipCount,
    currentHoldingCount: memberships.exactCount,
    unresolvedLeagueCount,
    ownedRosters,
    holdingPreview,
  }
}
