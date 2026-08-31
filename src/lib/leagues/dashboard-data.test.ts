import { describe, expect, it } from "vitest"

import {
  loadCurrentSeasonLeagueDashboard,
  type LeagueDashboardReader,
  type LeagueDiscoveryAttempt,
} from "@/lib/leagues/dashboard-data"

const league2025 = {
  id: "league-2025",
  name: "Historical League",
  status: "complete",
  teamCount: 10,
  rosterManagementType: "redraft",
  isBestBall: false,
  scoringFormat: "ppr",
  hasSuperflex: false,
}

const league2026 = {
  id: "league-2026",
  name: "Current League",
  status: "in_season",
  teamCount: 12,
  rosterManagementType: "dynasty",
  isBestBall: false,
  scoringFormat: "half_ppr",
  hasSuperflex: true,
}

describe("current-season league dashboard data", () => {
  it("excludes prior-season associations and success at season rollover", async () => {
    const leaguesBySeason = new Map([[2025, [league2025]]])
    const attempts: LeagueDiscoveryAttempt[] = [
      { season: 2025, status: "succeeded" },
    ]
    const requestedSeasons: number[] = []
    const reader: LeagueDashboardReader = {
      async getCurrentLeagueSeason() {
        return 2026
      },
      async getLatestAttempt() {
        return attempts.at(-1) ?? null
      },
      async getCurrentSeasonLeagues(_accountId, season) {
        requestedSeasons.push(season)
        return leaguesBySeason.get(season) ?? []
      },
      async hasCurrentSeasonSuccess(_accountId, season) {
        requestedSeasons.push(season)
        return attempts.some(
          (attempt) =>
            attempt.season === season && attempt.status === "succeeded"
        )
      },
    }

    const beforeCurrentImport = await loadCurrentSeasonLeagueDashboard(
      reader,
      "account-a"
    )

    expect(beforeCurrentImport).toMatchObject({
      currentLeagueSeason: 2026,
      hasSuccessfulDiscovery: false,
      leagues: [],
      latestAttempt: { season: 2025, status: "succeeded" },
    })
    expect(requestedSeasons).toEqual([2026, 2026])
    expect(beforeCurrentImport.leagues).not.toContainEqual(league2025)

    leaguesBySeason.set(2026, [league2026])
    attempts.push({ season: 2026, status: "succeeded" })

    const afterCurrentImport = await loadCurrentSeasonLeagueDashboard(
      reader,
      "account-a"
    )

    expect(afterCurrentImport).toMatchObject({
      currentLeagueSeason: 2026,
      hasSuccessfulDiscovery: true,
      leagues: [league2026],
      latestAttempt: { season: 2026, status: "succeeded" },
    })
    expect(afterCurrentImport.leagues).not.toContainEqual(league2025)
  })

  it("does not query current-season rows or success before state exists", async () => {
    let currentSeasonRead = false
    const reader: LeagueDashboardReader = {
      async getCurrentLeagueSeason() {
        return null
      },
      async getLatestAttempt() {
        return { season: 2025, status: "succeeded" }
      },
      async getCurrentSeasonLeagues() {
        currentSeasonRead = true
        return [league2025]
      },
      async hasCurrentSeasonSuccess() {
        currentSeasonRead = true
        return true
      },
    }

    await expect(
      loadCurrentSeasonLeagueDashboard(reader, "account-a")
    ).resolves.toEqual({
      currentLeagueSeason: null,
      hasSuccessfulDiscovery: false,
      latestAttempt: { season: 2025, status: "succeeded" },
      leagues: [],
    })
    expect(currentSeasonRead).toBe(false)
  })
})
