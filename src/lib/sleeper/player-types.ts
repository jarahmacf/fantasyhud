export type SleeperPlayerEntityType = "player" | "team_defense" | "unknown"

export interface SleeperPlayerExternalIdCandidate {
  namespace:
    | "espn"
    | "yahoo"
    | "stats"
    | "sportradar"
    | "fantasy_data"
    | "rotowire"
    | "rotoworld"
  externalId: string
  reportedBy: "sleeper"
  sourceField: string
}

export interface NormalizedSleeperPlayerProfile {
  sport: "nfl"
  entityType: SleeperPlayerEntityType
  displayName: string | null
  firstName: string | null
  lastName: string | null
  fullName: string | null
  primaryPosition: string | null
  fantasyPositions: string[]
  nflTeam: string | null
  active: boolean | null
  status: string | null
  jerseyNumber: number | null
  age: number | null
  height: string | null
  weight: string | null
  yearsExperience: number | null
  college: string | null
  highSchool: string | null
  birthCountry: string | null
  depthChartPosition: number | null
  depthChartOrder: number | null
  injuryStatus: string | null
  injuryBodyPart: string | null
  injuryStartDate: string | null
  practiceParticipation: string | null
  newsUpdatedAt: string | null
  searchRank: number | null
  profileSource: "sleeper"
  sourceMetadata: Record<string, unknown>
  profileFetchedAt: string
}

export interface NormalizedSleeperPlayerRecord {
  sleeperPlayerId: string
  profile: NormalizedSleeperPlayerProfile
  externalIds: SleeperPlayerExternalIdCandidate[]
  normalizationWarningCount: number
}

export interface SleeperPlayerCatalogSource {
  records: NormalizedSleeperPlayerRecord[]
  sourceFetchedAt: string
  sourceBytes: number
  sourceRecordCount: number
}

export type PlayerCatalogActionState =
  | { status: "idle"; message: null }
  | { status: "running"; message: string }
  | { status: "success"; message: string; observedRecords?: number }
  | { status: "error"; message: string }
