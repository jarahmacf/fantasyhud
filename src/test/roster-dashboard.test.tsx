import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { CurrentHoldingsTable } from "@/components/rosters/current-holdings-table"
import { OwnedRosterTable } from "@/components/rosters/owned-roster-table"
import { RosterStatusNotice } from "@/components/rosters/roster-status-notice"
import { RosterSummaryCards } from "@/components/rosters/roster-summary-cards"
import type { RosterDashboard } from "@/lib/rosters/dashboard.server"

const dashboard: RosterDashboard = {
  prerequisite: "ready",
  currentLeagueSeason: 2026,
  currentSeasonLeagueCount: 2,
  latestStatus: "succeeded",
  hasSuccessfulImport: true,
  lastRefreshedAt: "2026-09-01T20:30:00.000Z",
  ownedRosterCount: 2,
  currentHoldingCount: 15,
  unresolvedLeagueCount: 0,
  ownedRosters: [
    {
      id: "ownership-a",
      leagueName: "Fixture Alpha",
      teamName: "Fixture Dynasty Team",
      ownershipRole: "owner",
      playerCount: 8,
      starterCount: 6,
      reserveCount: 1,
      taxiCount: 1,
      keeperCount: 1,
    },
    {
      id: "ownership-b",
      leagueName: "Fixture Beta",
      teamName: "Roster 2",
      ownershipRole: "co_owner",
      playerCount: 7,
      starterCount: 4,
      reserveCount: 0,
      taxiCount: 0,
      keeperCount: 0,
    },
  ],
  holdingPreview: [
    {
      id: "holding-a",
      playerLabel: "Aaron Fixture",
      leagueName: "Fixture Alpha",
      primaryPosition: "QB",
      nflTeam: "SEA",
      starterState: "yes",
      reserveState: "no",
      taxiState: "not_reported",
      keeperState: "yes",
    },
    {
      id: "holding-b",
      playerLabel: "roster-unknown-0001",
      leagueName: "Fixture Beta",
      primaryPosition: null,
      nflTeam: null,
      starterState: "not_reported",
      reserveState: "not_reported",
      taxiState: "not_reported",
      keeperState: "not_reported",
    },
  ],
}

describe("roster dashboard", () => {
  it("renders six truthful current-season summary cards", () => {
    render(<RosterSummaryCards dashboard={dashboard} />)
    const summary = screen.getByRole("region", {
      name: "Roster import summary",
    })
    expect(summary.querySelectorAll('[data-slot="card"]')).toHaveLength(6)
    for (const label of [
      "Roster sync",
      "Current-season leagues",
      "Owned rosters",
      "Last confirmed active memberships",
      "Unresolved leagues",
      "Last refreshed",
    ]) {
      expect(within(summary).getByText(label)).toBeInTheDocument()
    }
    expect(within(summary).getByText("Succeeded")).toBeInTheDocument()
    expect(within(summary).getByText("15")).toBeInTheDocument()
  })

  it("renders exact owned-roster columns, role labels, and counts", () => {
    render(<OwnedRosterTable rows={dashboard.ownedRosters} />)
    const table = screen.getByRole("table", {
      name: "Owned current-season Sleeper rosters",
    })
    for (const heading of [
      "League",
      "Team",
      "Role",
      "Players",
      "Starters",
      "Reserve",
      "Taxi",
      "Keepers",
    ]) {
      expect(
        within(table).getByRole("columnheader", { name: heading })
      ).toBeInTheDocument()
    }
    expect(
      within(table).getByRole("row", {
        name: /Fixture Alpha Fixture Dynasty Team Owner 8 6 1 1 1/i,
      })
    ).toBeInTheDocument()
    expect(within(table).getByText("Co-owner")).toBeInTheDocument()
  })

  it("distinguishes source-null roster arrays from explicit empty arrays", () => {
    render(
      <OwnedRosterTable
        rows={[
          {
            ...dashboard.ownedRosters[0]!,
            id: "source-null",
            teamName: "Source null",
            playerCount: null,
            starterCount: null,
            reserveCount: null,
            taxiCount: null,
            keeperCount: null,
          },
          {
            ...dashboard.ownedRosters[1]!,
            id: "explicit-empty",
            teamName: "Explicit empty",
            playerCount: 0,
            starterCount: 0,
            reserveCount: 0,
            taxiCount: 0,
            keeperCount: 0,
          },
        ]}
      />
    )

    expect(
      screen.getByRole("row", {
        name: /Fixture Alpha Source null Owner Not reported Not reported Not reported Not reported Not reported/i,
      })
    ).toBeInTheDocument()
    expect(
      screen.getByRole("row", {
        name: /Fixture Beta Explicit empty Co-owner 0 0 0 0 0/i,
      })
    ).toBeInTheDocument()
  })

  it("renders the bounded holdings preview with exact-ID fallback", () => {
    render(
      <CurrentHoldingsTable
        rows={dashboard.holdingPreview}
        totalCount={dashboard.currentHoldingCount}
      />
    )
    const table = screen.getByRole("table", {
      name: "Current holdings preview",
    })
    for (const heading of [
      "Player",
      "League",
      "Position",
      "NFL team",
      "Starter",
      "Reserve",
      "Taxi",
      "Keeper",
    ]) {
      expect(
        within(table).getByRole("columnheader", { name: heading })
      ).toBeInTheDocument()
    }
    expect(within(table).getByText("Aaron Fixture")).toBeInTheDocument()
    expect(within(table).getByText("roster-unknown-0001")).toBeInTheDocument()
    expect(
      within(table).getByRole("row", {
        name: /Aaron Fixture Fixture Alpha QB SEA Yes No Not reported Yes/i,
      })
    ).toBeInTheDocument()
    const unknownSourceRow = within(table).getByRole("row", {
      name: /roster-unknown-0001 Fixture Beta/i,
    })
    expect(within(unknownSourceRow).getAllByText("Not reported")).toHaveLength(
      4
    )
    expect(
      screen.getByText("Showing the first 2 of 15 current holdings.")
    ).toBeInTheDocument()
  })

  it("shows partial ownership as a restrained warning", () => {
    render(
      <RosterStatusNotice
        prerequisite="ready"
        status="partial"
        unresolvedLeagueCount={2}
      />
    )
    expect(screen.getByRole("alert")).toHaveTextContent(
      "Roster source import completed with unresolved ownership"
    )
    expect(screen.getByRole("alert")).toHaveTextContent(
      "2 leagues have unresolved ownership"
    )
  })

  it("distinguishes a valid zero-owned-roster result", () => {
    render(<OwnedRosterTable rows={[]} />)
    expect(
      screen.getByText("No owned roster was resolved for this account.")
    ).toBeInTheDocument()
  })
})
