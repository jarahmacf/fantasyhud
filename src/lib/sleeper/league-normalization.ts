import { SleeperClientError } from "./types"

export type RosterManagementType = "redraft" | "keeper" | "dynasty" | "unknown"

export type ScoringFormat =
  "ppr" | "half_ppr" | "standard" | "custom" | "unknown"

export interface NormalizedSleeperLeague {
  externalLeagueId: string
  sport: "nfl"
  season: number
  name: string
  status: string
  seasonType: string
  teamCount: number
  rosterSize: number
  rosterManagementType: RosterManagementType
  isBestBall: boolean
  hasSuperflex: boolean
  hasIdp: boolean
  scoringFormat: ScoringFormat
  avatarId: string | null
  avatarUrl: string | null
  previousExternalLeagueId: string | null
  settings: Record<string, unknown>
  scoringSettings: Record<string, unknown>
  rosterPositions: string[]
  providerMetadata: Record<string, unknown>
  providerUpdatedAt: string | null
  fetchedAt: string
}

const validStatuses = new Set([
  "pre_draft",
  "drafting",
  "in_season",
  "complete",
])
const validSeasonTypes = new Set(["pre", "regular", "post"])
const superflexPositions = new Set(["SUPER_FLEX", "QB_FLEX"])
const idpPositions = new Set([
  "DL",
  "DE",
  "DT",
  "LB",
  "DB",
  "CB",
  "S",
  "EDGE",
  "IDP_FLEX",
])
export const receptionPremiumKeys = [
  "bonus_rec_te",
  "bonus_rec_rb",
  "bonus_rec_wr",
  "rec_te",
  "rec_rb",
  "rec_wr",
] as const

const modeledLeagueFields = new Set([
  "league_id",
  "sport",
  "season",
  "name",
  "status",
  "season_type",
  "total_rosters",
  "avatar",
  "previous_league_id",
  "settings",
  "scoring_settings",
  "roster_positions",
])

function invalidResponse(): never {
  throw new SleeperClientError("invalid_response")
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false
  }
  const prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

function parseBoundedString(value: unknown, maximumLength: number): string {
  if (typeof value !== "string") {
    return invalidResponse()
  }
  const trimmed = value.trim()
  if (
    trimmed.length === 0 ||
    trimmed.length > maximumLength ||
    trimmed !== value ||
    /[\u0000-\u001f\u007f]/u.test(value)
  ) {
    return invalidResponse()
  }
  return value
}

function parseNullableBoundedString(
  value: unknown,
  maximumLength: number
): string | null {
  if (value === null || value === undefined) {
    return null
  }
  return parseBoundedString(value, maximumLength)
}

function parseSeason(value: unknown): number {
  if (
    typeof value === "number" &&
    Number.isInteger(value) &&
    value >= 1900 &&
    value <= 2999
  ) {
    return value
  }
  if (typeof value === "string" && /^\d{4}$/u.test(value)) {
    const parsed = Number(value)
    if (parsed >= 1900 && parsed <= 2999) {
      return parsed
    }
  }
  return invalidResponse()
}

function parsePositiveInteger(value: unknown): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < 1 ||
    value > 1000
  ) {
    return invalidResponse()
  }
  return value
}

function classifyRosterManagement(
  settings: Record<string, unknown>
): RosterManagementType {
  if (settings.type === 0) return "redraft"
  if (settings.type === 1) return "keeper"
  if (settings.type === 2) return "dynasty"
  return "unknown"
}

function classifyBestBall(settings: Record<string, unknown>): boolean {
  return settings.best_ball === 1
}

function classifyScoring(
  scoringSettings: Record<string, unknown>
): ScoringFormat {
  const baseReception = scoringSettings.rec
  if (typeof baseReception !== "number" || !Number.isFinite(baseReception)) {
    return "unknown"
  }

  const hasMaterialPremium = receptionPremiumKeys.some((key) => {
    const value = scoringSettings[key]
    return typeof value === "number" && Number.isFinite(value) && value !== 0
  })
  if (hasMaterialPremium) {
    return "custom"
  }

  if (baseReception === 1) return "ppr"
  if (baseReception === 0.5) return "half_ppr"
  if (baseReception === 0) return "standard"
  return "custom"
}

function parseRosterPositions(value: unknown): string[] {
  if (!Array.isArray(value) || value.length > 1000) {
    return invalidResponse()
  }

  return value.map((position) => {
    const parsed = parseBoundedString(position, 64)
    if (!/^[A-Z0-9_]+$/u.test(parsed)) {
      return invalidResponse()
    }
    return parsed
  })
}

function collectProviderMetadata(
  source: Record<string, unknown>
): Record<string, unknown> {
  const metadata = Object.fromEntries(
    Object.entries(source).filter(([key]) => !modeledLeagueFields.has(key))
  )
  if (JSON.stringify(metadata).length > 64_000) {
    return invalidResponse()
  }
  return metadata
}

function normalizeLeague(
  value: unknown,
  expectedSeason: number,
  fetchedAt: string
): NormalizedSleeperLeague {
  if (!isPlainObject(value)) {
    return invalidResponse()
  }

  const sport = parseBoundedString(value.sport, 32)
  const season = parseSeason(value.season)
  const status = parseBoundedString(value.status, 32)
  const seasonType = parseBoundedString(value.season_type, 32)
  if (
    sport !== "nfl" ||
    season !== expectedSeason ||
    !validStatuses.has(status) ||
    !validSeasonTypes.has(seasonType)
  ) {
    return invalidResponse()
  }

  if (
    !isPlainObject(value.settings) ||
    !isPlainObject(value.scoring_settings)
  ) {
    return invalidResponse()
  }
  if (
    JSON.stringify(value.settings).length > 128_000 ||
    JSON.stringify(value.scoring_settings).length > 128_000
  ) {
    return invalidResponse()
  }

  const rosterPositions = parseRosterPositions(value.roster_positions)
  const avatarId = parseNullableBoundedString(value.avatar, 255)
  const previousExternalLeagueId = parseNullableBoundedString(
    value.previous_league_id,
    255
  )

  return {
    externalLeagueId: parseBoundedString(value.league_id, 255),
    sport: "nfl",
    season,
    name: parseBoundedString(value.name, 255),
    status,
    seasonType,
    teamCount: parsePositiveInteger(value.total_rosters),
    rosterSize: rosterPositions.length,
    rosterManagementType: classifyRosterManagement(value.settings),
    isBestBall: classifyBestBall(value.settings),
    hasSuperflex: rosterPositions.some((position) =>
      superflexPositions.has(position)
    ),
    hasIdp: rosterPositions.some((position) => idpPositions.has(position)),
    scoringFormat: classifyScoring(value.scoring_settings),
    avatarId,
    avatarUrl: avatarId
      ? `https://sleepercdn.com/avatars/${encodeURIComponent(avatarId)}`
      : null,
    previousExternalLeagueId,
    settings: value.settings,
    scoringSettings: value.scoring_settings,
    rosterPositions,
    providerMetadata: collectProviderMetadata(value),
    providerUpdatedAt: null,
    fetchedAt,
  }
}

export function normalizeSleeperLeagueCollection(
  value: unknown,
  expectedSeason: number,
  fetchedAt: string
): NormalizedSleeperLeague[] {
  if (!Array.isArray(value) || value.length > 1000) {
    return invalidResponse()
  }
  if (JSON.stringify(value).length > 4_000_000) {
    return invalidResponse()
  }

  const parsedFetchedAt = new Date(fetchedAt)
  if (Number.isNaN(parsedFetchedAt.getTime())) {
    return invalidResponse()
  }

  const normalized = value.map((league) =>
    normalizeLeague(league, expectedSeason, parsedFetchedAt.toISOString())
  )
  const ids = new Set<string>()
  for (const league of normalized) {
    if (ids.has(league.externalLeagueId)) {
      return invalidResponse()
    }
    ids.add(league.externalLeagueId)
  }
  return normalized
}
