import type {
  NormalizedRosterLeagueBundle,
  NormalizedSleeperLeagueUser,
  NormalizedSleeperRoster,
  NormalizedSleeperRosterMembership,
} from "./roster-types"
import { SleeperClientError } from "./types"

const controlCharacterPattern = /[\u0000-\u001f\u007f]/u
const maximumCollectionItems = 1_000
const maximumBundleBytes = 2_000_000
const maximumMetadataBytes = 65_536
const maximumSettingsBytes = 131_072
const verifiedStarterPlaceholder = "0"
const storageRosterPositions = new Set(["BN", "IR", "TAXI"])

type MetadataSourceState = "absent" | "null" | "object"

export interface NormalizeRosterLeagueBundleInput {
  externalLeagueId: string
  leagueSeason: number
  rosterPositions: readonly string[]
  bundleFetchedAt: string
  users: unknown
  rosters: unknown
  sourceMetadata: Record<string, unknown>
}

function invalidResponse(): never {
  throw new SleeperClientError("invalid_response")
}

function compareExact(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0
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
    return invalidResponse()
  }
}

function requireBoundedObject(
  value: unknown,
  maximumBytes: number
): Record<string, unknown> {
  if (!isPlainObject(value) || jsonByteLength(value) > maximumBytes) {
    return invalidResponse()
  }
  return value
}

function exactId(value: unknown): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 255 ||
    value !== value.trim() ||
    controlCharacterPattern.test(value)
  ) {
    return invalidResponse()
  }
  return value
}

function nullableExactId(value: unknown): string | null {
  if (value === null || value === undefined) return null
  return exactId(value)
}

function normalizeDisplay(
  value: unknown,
  maximumLength: number,
  warningField: string,
  warnings: Set<string>
): string | null {
  if (value === undefined || value === null || value === "") return null
  if (typeof value !== "string" || controlCharacterPattern.test(value)) {
    warnings.add(warningField)
    return null
  }

  const normalized = value.trim()
  if (!normalized) return null
  if (normalized.length > maximumLength) {
    warnings.add(warningField)
    return null
  }
  return normalized
}

function readOptionalMetadata(
  source: Record<string, unknown>,
  field: string
): { metadata: Record<string, unknown>; state: MetadataSourceState } {
  if (!Object.hasOwn(source, field)) {
    return { metadata: {}, state: "absent" }
  }
  if (source[field] === null) {
    return { metadata: {}, state: "null" }
  }
  const metadata = requireBoundedObject(source[field], maximumMetadataBytes)
  if (Object.hasOwn(metadata, "_fantasyhud")) return invalidResponse()
  return { metadata, state: "object" }
}

function augmentMetadata(
  source: { metadata: Record<string, unknown>; state: MetadataSourceState },
  details: Record<string, unknown> = {}
): Record<string, unknown> {
  const metadata = {
    ...source.metadata,
    _fantasyhud: {
      metadata_source_state: source.state,
      ...details,
    },
  }
  if (jsonByteLength(metadata) > maximumMetadataBytes) {
    return invalidResponse()
  }
  return metadata
}

function normalizeLeagueUser(
  value: unknown,
  expectedLeagueId: string,
  warnings: Set<string>
): NormalizedSleeperLeagueUser {
  if (!isPlainObject(value)) return invalidResponse()
  if (exactId(value.league_id) !== expectedLeagueId) return invalidResponse()

  const localWarnings = new Set<string>()
  const sourceMetadata = readOptionalMetadata(value, "metadata")
  const teamName = normalizeDisplay(
    sourceMetadata.metadata.team_name,
    255,
    "metadata.team_name",
    localWarnings
  )
  const avatarId = nullableExactId(value.avatar)

  let isCommissioner = false
  let isOwnerSourceState: "absent" | "null" | "boolean" | "malformed"
  if (typeof value.is_owner === "boolean") {
    isCommissioner = value.is_owner
    isOwnerSourceState = "boolean"
  } else if (!Object.hasOwn(value, "is_owner")) {
    isOwnerSourceState = "absent"
  } else if (value.is_owner === null) {
    isOwnerSourceState = "null"
  } else {
    isOwnerSourceState = "malformed"
    localWarnings.add("is_owner")
  }

  const username = normalizeDisplay(
    value.username,
    100,
    "username",
    localWarnings
  )
  const displayName = normalizeDisplay(
    value.display_name,
    255,
    "display_name",
    localWarnings
  )
  for (const warning of localWarnings) warnings.add(warning)

  return {
    externalUserId: exactId(value.user_id),
    username,
    displayName,
    teamName,
    avatarId,
    avatarUrl: avatarId
      ? `https://sleepercdn.com/avatars/${encodeURIComponent(avatarId)}`
      : null,
    isCommissioner,
    metadata: augmentMetadata(sourceMetadata, {
      is_owner_source_state: isOwnerSourceState,
      normalization_warning_fields: [...localWarnings].sort(),
    }),
  }
}

function normalizeLeagueUsers(
  value: unknown,
  expectedLeagueId: string,
  warnings: Set<string>
): NormalizedSleeperLeagueUser[] {
  if (!Array.isArray(value) || value.length > maximumCollectionItems) {
    return invalidResponse()
  }

  const users = value.map((user) =>
    normalizeLeagueUser(user, expectedLeagueId, warnings)
  )
  const ids = new Set<string>()
  for (const user of users) {
    if (ids.has(user.externalUserId)) return invalidResponse()
    ids.add(user.externalUserId)
  }
  return users.sort((left, right) =>
    compareExact(left.externalUserId, right.externalUserId)
  )
}

function normalizeExactArray(
  source: Record<string, unknown>,
  field: string,
  options: { allowRepeatedPlaceholder?: boolean } = {}
): string[] | null {
  const value = source[field]
  if (value === null || value === undefined) return null
  if (!Array.isArray(value) || value.length > maximumCollectionItems) {
    return invalidResponse()
  }

  const result = value.map(exactId)
  const seen = new Set<string>()
  for (const item of result) {
    if (seen.has(item)) {
      if (
        options.allowRepeatedPlaceholder &&
        item === verifiedStarterPlaceholder
      ) {
        continue
      }
      return invalidResponse()
    }
    seen.add(item)
  }
  return result
}

function assertAnnotationsBelongToPlayers(
  players: string[] | null,
  starters: string[] | null,
  reserve: string[] | null,
  taxi: string[] | null,
  keepers: string[] | null
): void {
  const playerIds = new Set(players ?? [])

  for (const starter of starters ?? []) {
    if (starter !== verifiedStarterPlaceholder && !playerIds.has(starter)) {
      return invalidResponse()
    }
  }
  for (const collection of [reserve, taxi, keepers]) {
    for (const playerId of collection ?? []) {
      if (!playerIds.has(playerId)) return invalidResponse()
    }
  }
}

function normalizeMemberships(
  players: string[] | null,
  starters: string[] | null,
  reserve: string[] | null,
  taxi: string[] | null,
  keepers: string[] | null,
  rosterPositions: readonly string[],
  warnings: Set<string>
): NormalizedSleeperRosterMembership[] | null {
  if (players === null) return null

  const startingPositions = rosterPositions.filter(
    (position) => !storageRosterPositions.has(position)
  )
  const starterSlotsAlign =
    starters !== null &&
    starters.length > 0 &&
    startingPositions.length === starters.length
  if (starters !== null && starters.length > 0 && !starterSlotsAlign) {
    warnings.add("starter_slot_alignment")
  }

  const starterOrder = new Map<string, number>()
  const starterSlot = new Map<string, string>()
  for (const [index, playerId] of (starters ?? []).entries()) {
    if (playerId === verifiedStarterPlaceholder) continue
    starterOrder.set(playerId, index + 1)
    const slot = starterSlotsAlign ? startingPositions[index] : undefined
    if (slot) starterSlot.set(playerId, slot)
  }

  const reserveIds = new Set(reserve ?? [])
  const taxiIds = new Set(taxi ?? [])
  const keeperIds = new Set(keepers ?? [])
  const annotationSourceState = {
    starters: starters === null ? "unknown" : "known",
    reserve: reserve === null ? "unknown" : "known",
    taxi: taxi === null ? "unknown" : "known",
    keepers: keepers === null ? "unknown" : "known",
  } as const

  return players.map((externalPlayerId, index) => {
    const order = starterOrder.get(externalPlayerId) ?? null
    return {
      externalPlayerId,
      sourceOrder: index + 1,
      isStarter: order !== null,
      starterOrder: order,
      starterSlot:
        order === null ? null : (starterSlot.get(externalPlayerId) ?? null),
      isReserve: reserveIds.has(externalPlayerId),
      isTaxi: taxiIds.has(externalPlayerId),
      isKeeper: keeperIds.has(externalPlayerId),
      sourceMetadata: {
        annotation_source_state: annotationSourceState,
        normalization_warning_fields:
          order !== null && !starterSlotsAlign
            ? ["starter_slot_alignment"]
            : [],
      },
    }
  })
}

function normalizeRoster(
  value: unknown,
  expectedLeagueId: string,
  rosterPositions: readonly string[],
  warnings: Set<string>
): NormalizedSleeperRoster {
  if (!isPlainObject(value)) return invalidResponse()
  if (exactId(value.league_id) !== expectedLeagueId) return invalidResponse()
  if (
    typeof value.roster_id !== "number" ||
    !Number.isSafeInteger(value.roster_id) ||
    value.roster_id < 1 ||
    value.roster_id > 1_000_000
  ) {
    return invalidResponse()
  }

  const sourcePlayerIds = normalizeExactArray(value, "players")
  if (sourcePlayerIds?.includes(verifiedStarterPlaceholder)) {
    return invalidResponse()
  }
  const sourceStarterIds = normalizeExactArray(value, "starters", {
    allowRepeatedPlaceholder: true,
  })
  const sourceReserveIds = normalizeExactArray(value, "reserve")
  const sourceTaxiIds = normalizeExactArray(value, "taxi")
  const sourceKeeperIds = normalizeExactArray(value, "keepers")
  assertAnnotationsBelongToPlayers(
    sourcePlayerIds,
    sourceStarterIds,
    sourceReserveIds,
    sourceTaxiIds,
    sourceKeeperIds
  )

  return {
    externalRosterId: value.roster_id,
    ownerExternalUserId: nullableExactId(value.owner_id),
    coOwnerExternalUserIds: normalizeExactArray(value, "co_owners"),
    sourcePlayerIds,
    sourceStarterIds,
    sourceReserveIds,
    sourceTaxiIds,
    sourceKeeperIds,
    settings: requireBoundedObject(value.settings, maximumSettingsBytes),
    metadata: augmentMetadata(readOptionalMetadata(value, "metadata")),
    memberships: normalizeMemberships(
      sourcePlayerIds,
      sourceStarterIds,
      sourceReserveIds,
      sourceTaxiIds,
      sourceKeeperIds,
      rosterPositions,
      warnings
    ),
  }
}

function normalizeRosters(
  value: unknown,
  expectedLeagueId: string,
  rosterPositions: readonly string[],
  warnings: Set<string>
): NormalizedSleeperRoster[] {
  if (!Array.isArray(value) || value.length > maximumCollectionItems) {
    return invalidResponse()
  }

  const rosters = value.map((roster) =>
    normalizeRoster(roster, expectedLeagueId, rosterPositions, warnings)
  )
  const ids = new Set<number>()
  for (const roster of rosters) {
    if (ids.has(roster.externalRosterId)) return invalidResponse()
    ids.add(roster.externalRosterId)
  }
  return rosters.sort(
    (left, right) => left.externalRosterId - right.externalRosterId
  )
}

function validateRosterPositions(value: readonly string[]): string[] {
  if (value.length > maximumCollectionItems) return invalidResponse()
  return value.map((position) => {
    if (typeof position !== "string" || !/^[A-Z0-9_]{1,64}$/u.test(position)) {
      return invalidResponse()
    }
    return position
  })
}

export function normalizeSleeperRosterLeagueBundle(
  input: NormalizeRosterLeagueBundleInput
): NormalizedRosterLeagueBundle {
  const externalLeagueId = exactId(input.externalLeagueId)
  if (
    !Number.isInteger(input.leagueSeason) ||
    input.leagueSeason < 1900 ||
    input.leagueSeason > 2999
  ) {
    return invalidResponse()
  }
  const fetchedAt = new Date(input.bundleFetchedAt)
  if (
    Number.isNaN(fetchedAt.getTime()) ||
    fetchedAt.toISOString() !== input.bundleFetchedAt
  ) {
    return invalidResponse()
  }

  const sourceMetadata = requireBoundedObject(
    input.sourceMetadata,
    maximumMetadataBytes
  )
  const rosterPositions = validateRosterPositions(input.rosterPositions)
  const warnings = new Set<string>()
  const bundle: NormalizedRosterLeagueBundle = {
    externalLeagueId,
    leagueSeason: input.leagueSeason,
    bundleFetchedAt: input.bundleFetchedAt,
    users: normalizeLeagueUsers(input.users, externalLeagueId, warnings),
    rosters: normalizeRosters(
      input.rosters,
      externalLeagueId,
      rosterPositions,
      warnings
    ),
    sourceMetadata: {
      ...sourceMetadata,
      normalization_warning_count: warnings.size,
      normalization_warning_fields: [...warnings].sort(),
    },
  }

  if (jsonByteLength(bundle) > maximumBundleBytes) return invalidResponse()
  return bundle
}

export function validateCompleteRosterBundleCollection(
  bundles: readonly NormalizedRosterLeagueBundle[],
  expectedExternalLeagueIds: readonly string[],
  leagueSeason: number
): NormalizedRosterLeagueBundle[] {
  if (
    expectedExternalLeagueIds.length < 1 ||
    expectedExternalLeagueIds.length > 250 ||
    bundles.length !== expectedExternalLeagueIds.length
  ) {
    return invalidResponse()
  }

  const expected = [...expectedExternalLeagueIds]
    .map(exactId)
    .sort(compareExact)
  if (new Set(expected).size !== expected.length) return invalidResponse()

  const sorted = [...bundles].sort((left, right) =>
    compareExact(left.externalLeagueId, right.externalLeagueId)
  )
  let normalizedObjectCount = 0
  for (const [index, bundle] of sorted.entries()) {
    if (
      bundle.externalLeagueId !== expected[index] ||
      bundle.leagueSeason !== leagueSeason
    ) {
      return invalidResponse()
    }
    normalizedObjectCount +=
      bundle.users.length +
      bundle.rosters.length +
      bundle.rosters.reduce(
        (total, roster) => total + (roster.memberships?.length ?? 0),
        0
      )
    if (normalizedObjectCount > 500_000) return invalidResponse()
  }
  return sorted
}

export const sleeperRosterStarterPlaceholder = verifiedStarterPlaceholder
