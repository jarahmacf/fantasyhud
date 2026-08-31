import "server-only"

import { sleeperGetJson, type SleeperHttpOptions } from "./http.server"
import {
  normalizeSleeperLeagueCollection,
  type NormalizedSleeperLeague,
} from "./league-normalization"
import { SleeperClientError } from "./types"

interface SleeperLeagueOptions extends SleeperHttpOptions {
  now?: () => Date
}

export async function fetchSleeperLeagues(
  canonicalUserId: string,
  leagueSeason: number,
  options: SleeperLeagueOptions = {}
): Promise<NormalizedSleeperLeague[]> {
  if (
    canonicalUserId.length === 0 ||
    canonicalUserId !== canonicalUserId.trim() ||
    canonicalUserId.length > 255 ||
    /[\u0000-\u001f\u007f]/u.test(canonicalUserId) ||
    !Number.isInteger(leagueSeason) ||
    leagueSeason < 1900 ||
    leagueSeason > 2999
  ) {
    throw new SleeperClientError("invalid_response")
  }

  const { now = () => new Date(), ...httpOptions } = options
  const body = await sleeperGetJson(
    ["user", canonicalUserId, "leagues", "nfl", String(leagueSeason)],
    httpOptions
  )

  return normalizeSleeperLeagueCollection(
    body,
    leagueSeason,
    now().toISOString()
  )
}
