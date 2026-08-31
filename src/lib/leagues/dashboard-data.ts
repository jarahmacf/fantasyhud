import type { LeagueTableRow } from "@/components/leagues/league-table"

export type LeagueDiscoveryAttempt = {
  season: number | null
  status: string
}

export type LeagueDashboardData = {
  currentLeagueSeason: number | null
  hasSuccessfulDiscovery: boolean
  latestAttempt: LeagueDiscoveryAttempt | null
  leagues: LeagueTableRow[]
}

export type LeagueDashboardReader = {
  getCurrentLeagueSeason: () => Promise<number | null>
  getLatestAttempt: (
    fantasyAccountId: string
  ) => Promise<LeagueDiscoveryAttempt | null>
  getCurrentSeasonLeagues: (
    fantasyAccountId: string,
    season: number
  ) => Promise<LeagueTableRow[]>
  hasCurrentSeasonSuccess: (
    fantasyAccountId: string,
    season: number
  ) => Promise<boolean>
}

export async function loadCurrentSeasonLeagueDashboard(
  reader: LeagueDashboardReader,
  fantasyAccountId: string
): Promise<LeagueDashboardData> {
  const currentLeagueSeason = await reader.getCurrentLeagueSeason()
  const latestAttempt = await reader.getLatestAttempt(fantasyAccountId)

  if (currentLeagueSeason === null) {
    return {
      currentLeagueSeason: null,
      hasSuccessfulDiscovery: false,
      latestAttempt,
      leagues: [],
    }
  }

  const [leagues, hasSuccessfulDiscovery] = await Promise.all([
    reader.getCurrentSeasonLeagues(fantasyAccountId, currentLeagueSeason),
    reader.hasCurrentSeasonSuccess(fantasyAccountId, currentLeagueSeason),
  ])

  return {
    currentLeagueSeason,
    hasSuccessfulDiscovery,
    latestAttempt,
    leagues: [...leagues].sort((left, right) =>
      left.name.localeCompare(right.name)
    ),
  }
}
