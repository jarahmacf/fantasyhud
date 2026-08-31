import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import Home from "@/app/page"

describe("foundation page", () => {
  it("renders the FANTASY HUD shell and backend heading", () => {
    render(<Home />)

    expect(screen.getByText("FANTASY HUD")).toBeInTheDocument()
    expect(
      screen.getByRole("heading", { level: 1, name: "Backend foundation" })
    ).toBeInTheDocument()
  })

  it("renders four compact status cards", () => {
    render(<Home />)

    const cards = screen.getAllByTestId("status-card")
    expect(cards).toHaveLength(4)
    for (const label of [
      "Application",
      "TypeScript",
      "Unit tests",
      "Browser tests",
    ]) {
      expect(
        cards.some((card) => within(card).queryByText(label) !== null)
      ).toBe(true)
    }
  })

  it("renders ten truthful foundation rows", () => {
    render(<Home />)

    const table = screen.getByRole("table", { name: "Foundation status" })
    expect(within(table).getAllByRole("row")).toHaveLength(11)

    const hostedDevelopmentRow = within(table).getByRole("row", {
      name: /Hosted development Configured Supabase GitHub integration/i,
    })
    expect(
      within(hostedDevelopmentRow).getByText("Configured")
    ).toBeInTheDocument()

    expect(
      within(table).getByRole("row", {
        name: /Product database Not modeled Deferred to Task 003/i,
      })
    ).toBeInTheDocument()
  })

  it("does not expose removed template controls", () => {
    render(<Home />)

    expect(
      screen.queryByRole("button", { name: /theme customizer/i })
    ).not.toBeInTheDocument()
    expect(
      screen.queryByRole("button", { name: /customize columns/i })
    ).not.toBeInTheDocument()
    expect(
      screen.queryByRole("button", { name: /add section/i })
    ).not.toBeInTheDocument()
  })
})
