export interface ResolvedSleeperUser {
  userId: string
  username: string
  displayName: string | null
  avatarId: string | null
  avatarUrl: string | null
}

export type SleeperClientErrorKind =
  "not_found" | "unavailable" | "invalid_response" | "timeout"

const safeSleeperErrorMessages: Record<SleeperClientErrorKind, string> = {
  not_found: "Sleeper account not found.",
  unavailable: "Sleeper is temporarily unavailable.",
  invalid_response: "Sleeper returned an unexpected response.",
  timeout: "Sleeper request timed out.",
}

export class SleeperClientError extends Error {
  readonly kind: SleeperClientErrorKind

  constructor(kind: SleeperClientErrorKind) {
    super(safeSleeperErrorMessages[kind])
    this.name = "SleeperClientError"
    this.kind = kind
  }
}

export interface SleeperConnectionActionState {
  status: "idle" | "error"
  message?: string
  fieldErrors?: { username?: string }
}

export const initialSleeperConnectionActionState: SleeperConnectionActionState =
  { status: "idle" }

export interface LeagueDiscoveryActionState {
  status: "idle" | "running" | "success" | "error"
  message?: string
  activeLeagues?: number
  leagueSeason?: number
}

export const initialLeagueDiscoveryActionState: LeagueDiscoveryActionState = {
  status: "idle",
}
