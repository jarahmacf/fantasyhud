import "server-only"

import {
  sleeperGetJsonWithMetadata,
  type SleeperHttpOptions,
} from "./http.server"
import type { SleeperLeagueEndpointSource } from "./roster-types"
import { SleeperClientError } from "./types"

export const sleeperLeagueUsersTimeoutMs = 10_000
export const sleeperLeagueUsersMaximumBytes = 5_000_000

function assertExternalLeagueId(value: string): void {
  if (
    value.length === 0 ||
    value.length > 255 ||
    value !== value.trim() ||
    /[\u0000-\u001f\u007f]/u.test(value)
  ) {
    throw new SleeperClientError("invalid_response")
  }
}

export async function fetchSleeperLeagueUsers(
  externalLeagueId: string,
  options: SleeperHttpOptions = {}
): Promise<SleeperLeagueEndpointSource> {
  assertExternalLeagueId(externalLeagueId)
  return sleeperGetJsonWithMetadata(["league", externalLeagueId, "users"], {
    ...options,
    timeoutMs: sleeperLeagueUsersTimeoutMs,
    maxResponseBytes: sleeperLeagueUsersMaximumBytes,
  })
}
