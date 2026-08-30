import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import Home from "@/app/page"

describe("foundation page", () => {
  it("renders the FANTASY HUD shell and repository heading", () => {
    render(<Home />)

    expect(screen.getByText("FANTASY HUD")).toBeInTheDocument()
    expect(
      screen.getByRole("heading", { level: 1, name: "Repository foundation" })
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

  it("renders six foundation rows and the deferred backend state", () => {
    render(<Home />)

    const table = screen.getByRole("table", { name: "Foundation status" })
    expect(within(table).getAllByRole("row")).toHaveLength(7)

    const backendRow = within(table).getByRole("row", {
      name: /Backend Not connected Deferred to Task 002/i,
    })
    expect(within(backendRow).getByText("Not connected")).toBeInTheDocument()
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
