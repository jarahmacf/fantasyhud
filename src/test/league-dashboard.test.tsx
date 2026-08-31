import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { LeagueSummaryCards } from "@/components/leagues/league-summary-cards"
import { LeagueTable } from "@/components/leagues/league-table"

describe("league dashboard", () => {
  it("distinguishes not started from a confirmed empty collection", () => {
    const { rerender } = render(
      <LeagueTable leagues={[]} hasSuccessfulDiscovery={false} />
    )
    expect(
      screen.getByText(
        "Import current-season leagues to discover this account's leagues."
      )
    ).toBeInTheDocument()

    rerender(<LeagueTable leagues={[]} hasSuccessfulDiscovery />)
    expect(
      screen.getByText(
        "No current-season Sleeper leagues were returned for this account."
      )
    ).toBeInTheDocument()
  })

  it("renders the canonical league columns and classifications", () => {
    render(
      <LeagueTable
        hasSuccessfulDiscovery
        leagues={[
          {
            id: "fixture-league",
            name: "Fixture Dynasty",
            status: "in_season",
            teamCount: 12,
            rosterManagementType: "dynasty",
            isBestBall: true,
            scoringFormat: "half_ppr",
            hasSuperflex: true,
          },
        ]}
      />
    )

    const table = screen.getByRole("table", {
      name: "Current-season Sleeper leagues",
    })
    for (const heading of [
      "League",
      "Status",
      "Teams",
      "Management",
      "Best ball",
      "Scoring",
      "Superflex",
    ]) {
      expect(
        within(table).getByRole("columnheader", { name: heading })
      ).toBeInTheDocument()
    }
    expect(
      within(table).getByRole("row", {
        name: /Fixture Dynasty In season 12 Dynasty Yes Half PPR Yes/i,
      })
    ).toBeInTheDocument()
  })

  it("shows truthful league-discovery summary states", () => {
    render(
      <LeagueSummaryCards
        username="CanonicalFixtureUser"
        displayName="Fixture Sleeper User"
        leagueSeason={2026}
        activeLeagueCount={2}
        latestStatus="succeeded"
        latestSeason={2026}
      />
    )

    const summary = screen.getByRole("region", {
      name: "League discovery summary",
    })
    expect(within(summary).getByText("@CanonicalFixtureUser")).toBeVisible()
    expect(within(summary).getByText("2026")).toBeVisible()
    expect(within(summary).getByText("2")).toBeVisible()
    expect(within(summary).getByText("Succeeded")).toBeVisible()
    expect(
      within(summary).getByText("Latest attempt (all seasons)")
    ).toBeVisible()
    expect(within(summary).getByText("Run season 2026")).toBeVisible()
  })
})
