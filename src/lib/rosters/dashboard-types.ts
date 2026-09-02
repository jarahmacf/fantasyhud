export type OwnedRosterRow = {
  id: string
  leagueName: string
  teamName: string
  ownershipRole: "owner" | "co_owner"
  playerCount: number | null
  starterCount: number | null
  reserveCount: number | null
  taxiCount: number | null
  keeperCount: number | null
}

export type RosterAnnotationDisplayState = "yes" | "no" | "not_reported"

export type CurrentHoldingPreviewRow = {
  id: string
  playerLabel: string
  leagueName: string
  primaryPosition: string | null
  nflTeam: string | null
  starterState: RosterAnnotationDisplayState
  reserveState: RosterAnnotationDisplayState
  taxiState: RosterAnnotationDisplayState
  keeperState: RosterAnnotationDisplayState
}
