import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { PlayerCatalogSummary } from "@/components/players/player-catalog-summary"
import { PlayerCatalogTable } from "@/components/players/player-catalog-table"
import type { PlayerCatalogDashboard } from "@/lib/players/dashboard.server"

const dashboard: PlayerCatalogDashboard = {
  latestStatus: "succeeded",
  lastRefreshedAt: "2026-08-31T12:00:00.000Z",
  canonicalEntities: 600,
  activePlayers: 590,
  teamDefenses: 2,
  externalIdMappings: 650,
  preview: [
    {
      id: "one",
      sleeperExternalId: "sleeper-one",
      displayName: "Fixture Player",
      primaryPosition: "WR",
      fantasyPositions: ["WR"],
      nflTeam: "SEA",
      active: true,
      status: "Active",
      injuryStatus: null,
      injuryBodyPart: null,
    },
    {
      id: "two",
      sleeperExternalId: "exact-fallback-id",
      displayName: null,
      primaryPosition: null,
      fantasyPositions: [],
      nflTeam: null,
      active: true,
      status: null,
      injuryStatus: "Out",
      injuryBodyPart: "Knee",
    },
  ],
}

describe("player catalog dashboard", () => {
  it("renders all six truthful catalog summary cards", () => {
    render(<PlayerCatalogSummary dashboard={dashboard} />)
    const summary = screen.getByRole("region", {
      name: "Player catalog summary",
    })
    expect(summary.querySelectorAll('[data-slot="card"]')).toHaveLength(6)
    for (const label of [
      "Catalog status",
      "Last refreshed",
      "Canonical entities",
      "Active players",
      "Team defenses",
      "External ID mappings",
    ]) {
      expect(within(summary).getByText(label)).toBeInTheDocument()
    }
    expect(within(summary).getByText("600")).toBeInTheDocument()
    for (const detail of [
      "Retained canonical identities across catalog history",
      "Current active individual player entities",
      "Current Sleeper DEF identities",
    ]) {
      expect(within(summary).getByText(detail)).toBeInTheDocument()
    }
  })

  it("renders only canonical preview columns and exact-ID fallback", () => {
    render(<PlayerCatalogTable players={dashboard.preview} hasImported />)
    const table = screen.getByRole("table", {
      name: "Canonical player catalog preview",
    })
    for (const heading of [
      "Player",
      "Position",
      "Team",
      "Active",
      "Status",
      "Injury",
    ]) {
      expect(
        within(table).getByRole("columnheader", { name: heading })
      ).toBeInTheDocument()
    }
    expect(within(table).getByText("Fixture Player")).toBeInTheDocument()
    expect(within(table).getByText("exact-fallback-id")).toBeInTheDocument()
    expect(within(table).getByText("Out · Knee")).toBeInTheDocument()
    expect(
      screen.queryByText(/ADP|Exposure|Search rank/i)
    ).not.toBeInTheDocument()
  })

  it("distinguishes an imported catalog with no preview entities", () => {
    render(<PlayerCatalogTable players={[]} hasImported />)
    expect(
      screen.getByText(
        "Catalog imported with zero preview-eligible active entities."
      )
    ).toBeInTheDocument()
  })
})
