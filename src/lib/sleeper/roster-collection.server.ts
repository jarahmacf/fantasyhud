import "server-only"

import { mapWithBoundedConcurrency } from "./bounded-concurrency"
import { fetchSleeperLeagueUsers } from "./league-users.server"
import {
  normalizeSleeperRosterLeagueBundle,
  validateCompleteRosterBundleCollection,
} from "./roster-normalization"
import type { NormalizedRosterLeagueBundle } from "./roster-types"
import { fetchSleeperLeagueRosters } from "./rosters.server"

export const sleeperRosterLeagueConcurrency = 4

export type FrozenRosterLeague = {
  externalLeagueId: string
  rosterPositions: string[]
}

type CollectionOptions = {
  now?: () => Date
  monotonicNow?: () => number
}

export async function fetchNormalizedSleeperRosterBundles(
  leagues: readonly FrozenRosterLeague[],
  leagueSeason: number,
  options: CollectionOptions = {}
): Promise<NormalizedRosterLeagueBundle[]> {
  const now = options.now ?? (() => new Date())
  const monotonicNow = options.monotonicNow ?? (() => performance.now())
  const sortedLeagues = [...leagues].sort((left, right) =>
    left.externalLeagueId < right.externalLeagueId
      ? -1
      : left.externalLeagueId > right.externalLeagueId
        ? 1
        : 0
  )

  const bundles = await mapWithBoundedConcurrency(
    sortedLeagues,
    sleeperRosterLeagueConcurrency,
    async (league) => {
      const startedAt = monotonicNow()
      const [users, rosters] = await Promise.all([
        fetchSleeperLeagueUsers(league.externalLeagueId),
        fetchSleeperLeagueRosters(league.externalLeagueId),
      ])
      const sourceFetchDurationMs = Math.max(
        0,
        Math.round(monotonicNow() - startedAt)
      )

      return normalizeSleeperRosterLeagueBundle({
        externalLeagueId: league.externalLeagueId,
        leagueSeason,
        rosterPositions: league.rosterPositions,
        bundleFetchedAt: now().toISOString(),
        users: users.data,
        rosters: rosters.data,
        sourceMetadata: {
          users_endpoint_succeeded: 1,
          rosters_endpoint_succeeded: 1,
          users_response_bytes: users.responseBytes,
          rosters_response_bytes: rosters.responseBytes,
          users_fetched_at: users.fetchedAt,
          rosters_fetched_at: rosters.fetchedAt,
          source_fetch_duration_ms: sourceFetchDurationMs,
        },
      })
    }
  )

  return validateCompleteRosterBundleCollection(
    bundles,
    sortedLeagues.map((league) => league.externalLeagueId),
    leagueSeason
  )
}
