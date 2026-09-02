export interface SleeperLeagueEndpointSource {
  data: unknown
  responseBytes: number
  fetchedAt: string
}

export interface NormalizedSleeperLeagueUser {
  externalUserId: string
  username: string | null
  displayName: string | null
  teamName: string | null
  avatarId: string | null
  avatarUrl: string | null
  isCommissioner: boolean
  metadata: Record<string, unknown>
}

export type RosterAnnotationSourceState = "known" | "unknown"

export interface NormalizedSleeperRosterMembership {
  externalPlayerId: string
  sourceOrder: number
  isStarter: boolean
  starterOrder: number | null
  starterSlot: string | null
  isReserve: boolean
  isTaxi: boolean
  isKeeper: boolean
  sourceMetadata: {
    annotation_source_state: {
      starters: RosterAnnotationSourceState
      reserve: RosterAnnotationSourceState
      taxi: RosterAnnotationSourceState
      keepers: RosterAnnotationSourceState
    }
    normalization_warning_fields: string[]
  }
}

export interface NormalizedSleeperRoster {
  externalRosterId: number
  ownerExternalUserId: string | null
  coOwnerExternalUserIds: string[] | null
  sourcePlayerIds: string[] | null
  sourceStarterIds: string[] | null
  sourceReserveIds: string[] | null
  sourceTaxiIds: string[] | null
  sourceKeeperIds: string[] | null
  settings: Record<string, unknown>
  metadata: Record<string, unknown>
  memberships: NormalizedSleeperRosterMembership[] | null
}

export interface NormalizedRosterLeagueBundle {
  externalLeagueId: string
  leagueSeason: number
  bundleFetchedAt: string
  users: NormalizedSleeperLeagueUser[]
  rosters: NormalizedSleeperRoster[]
  sourceMetadata: Record<string, unknown>
}

export type RosterImportActionState =
  | { status: "idle"; message: null }
  | { status: "running"; message: string }
  | {
      status: "success"
      message: string
      activeOwnedRosters?: number
      activeOwnedMemberships?: number
    }
  | {
      status: "partial"
      message: string
      unresolvedOwnershipLeagues: number
      activeOwnedRosters?: number
      activeOwnedMemberships?: number
    }
  | { status: "error"; message: string }

export const initialRosterImportActionState: RosterImportActionState = {
  status: "idle",
  message: null,
}
