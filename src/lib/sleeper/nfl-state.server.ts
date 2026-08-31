import "server-only"

import { sleeperGetJson, type SleeperHttpOptions } from "./http.server"
import { SleeperClientError } from "./types"

export interface NormalizedNflState {
  season: number
  leagueSeason: number
  leagueCreateSeason: number | null
  previousSeason: number | null
  seasonType: string
  week: number | null
  leg: number | null
  displayWeek: number | null
  seasonStartDate: string | null
  providerMetadata: Record<string, unknown>
  fetchedAt: string
}

interface NflStateOptions extends SleeperHttpOptions {
  now?: () => Date
}

const modeledStateFields = new Set([
  "season",
  "league_season",
  "league_create_season",
  "previous_season",
  "season_type",
  "week",
  "leg",
  "display_week",
  "season_start_date",
])

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false
  }

  const prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

function parseSeason(value: unknown): number | null {
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
    return parsed >= 1900 && parsed <= 2999 ? parsed : null
  }

  return null
}

function parseNullableNonnegativeInteger(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null
  }
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw new SleeperClientError("invalid_response")
  }
  return value
}

function parseSeasonType(value: unknown): string {
  if (typeof value !== "string" || !/^[a-z][a-z0-9_-]{0,31}$/u.test(value)) {
    throw new SleeperClientError("invalid_response")
  }
  return value
}

function parseDate(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null
  }
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) {
    throw new SleeperClientError("invalid_response")
  }

  const parsed = new Date(`${value}T00:00:00.000Z`)
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new SleeperClientError("invalid_response")
  }
  return value
}

function collectProviderMetadata(
  source: Record<string, unknown>
): Record<string, unknown> {
  const metadata = Object.fromEntries(
    Object.entries(source).filter(([key]) => !modeledStateFields.has(key))
  )
  if (JSON.stringify(metadata).length > 32_000) {
    throw new SleeperClientError("invalid_response")
  }
  return metadata
}

export function normalizeNflState(
  value: unknown,
  fetchedAt: string
): NormalizedNflState {
  if (!isPlainObject(value)) {
    throw new SleeperClientError("invalid_response")
  }

  const season = parseSeason(value.season)
  const leagueSeason =
    parseSeason(value.league_season) ?? parseSeason(value.season)
  const parsedFetchedAt = new Date(fetchedAt)

  if (
    season === null ||
    leagueSeason === null ||
    Number.isNaN(parsedFetchedAt.getTime())
  ) {
    throw new SleeperClientError("invalid_response")
  }

  const leagueCreateSeason =
    value.league_create_season === null ||
    value.league_create_season === undefined
      ? null
      : parseSeason(value.league_create_season)
  const previousSeason =
    value.previous_season === null || value.previous_season === undefined
      ? null
      : parseSeason(value.previous_season)

  if (
    (value.league_create_season !== null &&
      value.league_create_season !== undefined &&
      leagueCreateSeason === null) ||
    (value.previous_season !== null &&
      value.previous_season !== undefined &&
      previousSeason === null)
  ) {
    throw new SleeperClientError("invalid_response")
  }

  return {
    season,
    leagueSeason,
    leagueCreateSeason,
    previousSeason,
    seasonType: parseSeasonType(value.season_type),
    week: parseNullableNonnegativeInteger(value.week),
    leg: parseNullableNonnegativeInteger(value.leg),
    displayWeek: parseNullableNonnegativeInteger(value.display_week),
    seasonStartDate: parseDate(value.season_start_date),
    providerMetadata: collectProviderMetadata(value),
    fetchedAt: parsedFetchedAt.toISOString(),
  }
}

export async function fetchNflState(
  options: NflStateOptions = {}
): Promise<NormalizedNflState> {
  const { now = () => new Date(), ...httpOptions } = options
  const body = await sleeperGetJson(["state", "nfl"], httpOptions)
  return normalizeNflState(body, now().toISOString())
}
