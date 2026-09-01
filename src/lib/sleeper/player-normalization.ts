import type {
  NormalizedSleeperPlayerRecord,
  SleeperPlayerExternalIdCandidate,
} from "./player-types"
import { SleeperClientError } from "./types"

const minimumCatalogRecords = 500
const maximumCatalogRecords = 50_000
const maximumExternalIdLength = 255
const maximumMetadataBytes = 48_000
const maximumWarningFields = 64
const tokenPattern = /^[A-Z0-9_]{1,32}$/u
const controlCharacterPattern = /[\u0000-\u001f\u007f]/u

const displayFieldLimits = {
  first_name: 100,
  last_name: 100,
  full_name: 255,
  status: 64,
  height: 32,
  weight: 32,
  college: 255,
  high_school: 255,
  birth_country: 100,
  injury_status: 64,
  injury_body_part: 64,
  practice_participation: 64,
} as const

const integerFieldBounds = {
  number: [0, 99],
  age: [0, 120],
  years_exp: [0, 100],
  depth_chart_position: [0, 1_000],
  depth_chart_order: [0, 1_000],
  search_rank: [0, 2_147_483_647],
} as const

const secondaryFields = [
  ["espn_id", "espn"],
  ["yahoo_id", "yahoo"],
  ["stats_id", "stats"],
  ["sportradar_id", "sportradar"],
  ["fantasy_data_id", "fantasy_data"],
  ["rotowire_id", "rotowire"],
  ["rotoworld_id", "rotoworld"],
] as const

const modeledFields = new Set([
  "player_id",
  "sport",
  "first_name",
  "last_name",
  "full_name",
  "position",
  "fantasy_positions",
  "team",
  "active",
  "status",
  "number",
  "age",
  "height",
  "weight",
  "years_exp",
  "college",
  "high_school",
  "birth_country",
  "depth_chart_position",
  "depth_chart_order",
  "injury_status",
  "injury_body_part",
  "injury_start_date",
  "practice_participation",
  "news_updated",
  "search_rank",
  ...secondaryFields.map(([field]) => field),
])

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  )
}

function isExactExternalId(value: string): boolean {
  return (
    value.length > 0 &&
    value.length <= maximumExternalIdLength &&
    value === value.trim() &&
    !controlCharacterPattern.test(value)
  )
}

function addWarning(warnings: string[], field: string): void {
  if (!warnings.includes(field) && warnings.length < maximumWarningFields) {
    warnings.push(field)
  }
}

function normalizeDisplay(
  record: Record<string, unknown>,
  field: keyof typeof displayFieldLimits,
  warnings: string[]
): string | null {
  const value = record[field]
  if (value === undefined || value === null || value === "") return null
  if (typeof value !== "string") {
    addWarning(warnings, field)
    return null
  }

  if (controlCharacterPattern.test(value)) {
    addWarning(warnings, field)
    return null
  }

  const normalized = value.trim()
  if (!normalized) return null
  if (normalized.length > displayFieldLimits[field]) {
    addWarning(warnings, field)
    return null
  }
  return normalized
}

function normalizeToken(
  value: unknown,
  field: string,
  warnings: string[]
): string | null {
  if (value === undefined || value === null || value === "") return null
  if (
    typeof value !== "string" ||
    value !== value.trim() ||
    !tokenPattern.test(value)
  ) {
    addWarning(warnings, field)
    return null
  }
  return value
}

function normalizeInteger(
  value: unknown,
  field: keyof typeof integerFieldBounds,
  warnings: string[]
): number | null {
  if (value === undefined || value === null || value === "") return null
  const [minimum, maximum] = integerFieldBounds[field]
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    addWarning(warnings, field)
    return null
  }
  return value
}

function normalizeBoolean(
  value: unknown,
  field: string,
  warnings: string[]
): boolean | null {
  if (value === undefined || value === null) return null
  if (typeof value !== "boolean") {
    addWarning(warnings, field)
    return null
  }
  return value
}

function normalizeDate(
  value: unknown,
  field: string,
  warnings: string[]
): string | null {
  if (value === undefined || value === null || value === "") return null
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) {
    addWarning(warnings, field)
    return null
  }

  const parsed = new Date(`${value}T00:00:00.000Z`)
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    addWarning(warnings, field)
    return null
  }
  return value
}

function normalizeNewsUpdated(
  value: unknown,
  warnings: string[]
): string | null {
  if (value === undefined || value === null || value === "") return null
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    addWarning(warnings, "news_updated")
    return null
  }

  const milliseconds = value < 1_000_000_000_000 ? value * 1_000 : value
  const parsed = new Date(milliseconds)
  if (Number.isNaN(parsed.getTime())) {
    addWarning(warnings, "news_updated")
    return null
  }
  return parsed.toISOString()
}

function normalizeFantasyPositions(
  value: unknown,
  warnings: string[]
): string[] {
  if (value === undefined || value === null) return []
  if (!Array.isArray(value)) {
    addWarning(warnings, "fantasy_positions")
    return []
  }

  const positions: string[] = []
  for (const item of value) {
    const position = normalizeToken(item, "fantasy_positions", warnings)
    if (position && !positions.includes(position)) positions.push(position)
  }
  return positions.slice(0, 32)
}

function normalizeSecondaryIds(
  record: Record<string, unknown>,
  warnings: string[]
): SleeperPlayerExternalIdCandidate[] {
  const candidates: SleeperPlayerExternalIdCandidate[] = []

  for (const [sourceField, namespace] of secondaryFields) {
    const value = record[sourceField]
    if (value === undefined || value === null || value === "") continue

    let externalId: string | null = null
    if (typeof value === "string" && isExactExternalId(value)) {
      externalId = value
    } else if (
      typeof value === "number" &&
      Number.isSafeInteger(value) &&
      value >= 0
    ) {
      externalId = String(value)
    }

    if (!externalId) {
      addWarning(warnings, sourceField)
      continue
    }

    candidates.push({
      namespace,
      externalId,
      reportedBy: "sleeper",
      sourceField,
    })
  }

  return candidates
}

function boundedUnmodeledFields(
  record: Record<string, unknown>,
  warnings: string[]
): Record<string, unknown> {
  const unmodeled: Record<string, unknown> = {}

  for (const [key, value] of Object.entries(record)) {
    if (modeledFields.has(key)) continue
    if (
      key.length < 1 ||
      key.length > 100 ||
      controlCharacterPattern.test(key)
    ) {
      addWarning(warnings, "unmodeled_fields")
      continue
    }

    const candidate = { ...unmodeled, [key]: value }
    try {
      if (
        new TextEncoder().encode(JSON.stringify(candidate)).byteLength <=
        maximumMetadataBytes
      ) {
        unmodeled[key] = value
      } else {
        addWarning(warnings, "unmodeled_fields")
      }
    } catch {
      addWarning(warnings, "unmodeled_fields")
    }
  }

  return unmodeled
}

export function normalizeSleeperPlayerRecord(
  sleeperPlayerId: string,
  value: unknown,
  profileFetchedAt: string
): NormalizedSleeperPlayerRecord {
  if (!isExactExternalId(sleeperPlayerId) || !isPlainObject(value)) {
    throw new SleeperClientError("invalid_response")
  }
  if (
    Object.hasOwn(value, "player_id") &&
    value.player_id !== null &&
    value.player_id !== sleeperPlayerId
  ) {
    throw new SleeperClientError("invalid_response")
  }
  if (
    Object.hasOwn(value, "sport") &&
    value.sport !== null &&
    value.sport !== "nfl"
  ) {
    throw new SleeperClientError("invalid_response")
  }

  const fetchedAtDate = new Date(profileFetchedAt)
  if (
    Number.isNaN(fetchedAtDate.getTime()) ||
    fetchedAtDate.toISOString() !== profileFetchedAt
  ) {
    throw new SleeperClientError("invalid_response")
  }

  const warnings: string[] = []
  const firstName = normalizeDisplay(value, "first_name", warnings)
  const lastName = normalizeDisplay(value, "last_name", warnings)
  const fullName = normalizeDisplay(value, "full_name", warnings)
  const primaryPosition = normalizeToken(value.position, "position", warnings)
  const fantasyPositions = normalizeFantasyPositions(
    value.fantasy_positions,
    warnings
  )
  const nflTeam = normalizeToken(value.team, "team", warnings)
  const isTeamDefense =
    primaryPosition === "DEF" || fantasyPositions.includes("DEF")
  const hasPlayerShape = Boolean(
    firstName ||
    lastName ||
    fullName ||
    primaryPosition ||
    fantasyPositions.length
  )
  const entityType = isTeamDefense
    ? "team_defense"
    : hasPlayerShape
      ? "player"
      : "unknown"
  const displayName =
    fullName ??
    ([firstName, lastName].filter(Boolean).join(" ") || null) ??
    (isTeamDefense ? (nflTeam ?? sleeperPlayerId) : null)
  const externalIds = normalizeSecondaryIds(value, warnings)
  const unmodeledFields = boundedUnmodeledFields(value, warnings)

  return {
    sleeperPlayerId,
    profile: {
      sport: "nfl",
      entityType,
      displayName,
      firstName,
      lastName,
      fullName,
      primaryPosition,
      fantasyPositions,
      nflTeam,
      active: normalizeBoolean(value.active, "active", warnings),
      status: normalizeDisplay(value, "status", warnings),
      jerseyNumber: normalizeInteger(value.number, "number", warnings),
      age: normalizeInteger(value.age, "age", warnings),
      height: normalizeDisplay(value, "height", warnings),
      weight: normalizeDisplay(value, "weight", warnings),
      yearsExperience: normalizeInteger(value.years_exp, "years_exp", warnings),
      college: normalizeDisplay(value, "college", warnings),
      highSchool: normalizeDisplay(value, "high_school", warnings),
      birthCountry: normalizeDisplay(value, "birth_country", warnings),
      depthChartPosition: normalizeInteger(
        value.depth_chart_position,
        "depth_chart_position",
        warnings
      ),
      depthChartOrder: normalizeInteger(
        value.depth_chart_order,
        "depth_chart_order",
        warnings
      ),
      injuryStatus: normalizeDisplay(value, "injury_status", warnings),
      injuryBodyPart: normalizeDisplay(value, "injury_body_part", warnings),
      injuryStartDate: normalizeDate(
        value.injury_start_date,
        "injury_start_date",
        warnings
      ),
      practiceParticipation: normalizeDisplay(
        value,
        "practice_participation",
        warnings
      ),
      newsUpdatedAt: normalizeNewsUpdated(value.news_updated, warnings),
      searchRank: normalizeInteger(value.search_rank, "search_rank", warnings),
      profileSource: "sleeper",
      sourceMetadata: {
        unmodeled_fields: unmodeledFields,
        normalization_warning_fields: warnings,
      },
      profileFetchedAt,
    },
    externalIds,
    normalizationWarningCount: warnings.length,
  }
}

export function normalizeSleeperPlayerCatalog(
  source: unknown,
  profileFetchedAt: string
): NormalizedSleeperPlayerRecord[] {
  if (!isPlainObject(source)) {
    throw new SleeperClientError("invalid_response")
  }

  const entries = Object.entries(source)
  if (
    entries.length < minimumCatalogRecords ||
    entries.length > maximumCatalogRecords
  ) {
    throw new SleeperClientError("invalid_response")
  }

  return entries
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
    .map(([sleeperPlayerId, value]) =>
      normalizeSleeperPlayerRecord(sleeperPlayerId, value, profileFetchedAt)
    )
}
