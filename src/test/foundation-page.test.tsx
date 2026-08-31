import { fireEvent, render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import Home from "@/app/page"

describe("foundation page", () => {
  it("renders the canonical shell and repository heading", () => {
    render(<Home />)

    expect(screen.getByText("FANTASY HUD")).toBeInTheDocument()
    expect(screen.getByText("Portfolio Command Center")).toBeInTheDocument()
    expect(
      screen.getByRole("heading", { level: 1, name: "Repository foundation" })
    ).toBeInTheDocument()
    expect(screen.getByText("Local workspace")).toBeInTheDocument()
    expect(screen.getByText("No signed-in user")).toBeInTheDocument()
  })

  it("renders four cards with the canonical composition", () => {
    const { container } = render(<Home />)
    const summary = screen.getByRole("region", { name: "Foundation summary" })
    const cards = summary.querySelectorAll('[data-slot="card"]')

    expect(cards).toHaveLength(4)
    expect(
      container.querySelectorAll('[data-slot="card-header"]')
    ).toHaveLength(4)
    expect(
      container.querySelectorAll('[data-slot="card-action"]')
    ).toHaveLength(4)
    expect(
      container.querySelectorAll('[data-slot="card-footer"]')
    ).toHaveLength(4)

    for (const label of [
      "Application",
      "TypeScript",
      "Test suite",
      "Delivery",
    ]) {
      expect(within(summary).getByText(label)).toBeInTheDocument()
    }
  })

  it("renders ten truthful foundation rows", () => {
    render(<Home />)

    const table = screen.getByRole("table", { name: "Foundation status" })
    expect(within(table).getAllByRole("row")).toHaveLength(11)
    expect(
      within(table).getByRole("row", {
        name: /Hosted development Configured Supabase GitHub integration/i,
      })
    ).toBeInTheDocument()
    expect(
      within(table).getByRole("row", {
        name: /Product database Not modeled Deferred to Task 003/i,
      })
    ).toBeInTheDocument()
  })

  it("filters every foundation field and clearing restores all rows", () => {
    render(<Home />)

    const search = screen.getByRole("searchbox", {
      name: "Search foundation status",
    })
    const table = screen.getByRole("table", { name: "Foundation status" })

    fireEvent.change(search, { target: { value: "pgTAP" } })
    expect(within(table).getAllByRole("row")).toHaveLength(2)
    expect(
      within(table).getByRole("row", { name: /Database tests Ready pgTAP/i })
    ).toBeInTheDocument()
    expect(screen.getByRole("status")).toHaveTextContent(
      "1 of 10 systems matching “pgTAP”"
    )

    fireEvent.click(screen.getByRole("button", { name: "Clear search" }))
    expect(search).toHaveValue("")
    expect(within(table).getAllByRole("row")).toHaveLength(11)
  })

  it("focuses search with the platform keyboard shortcut", () => {
    render(<Home />)

    const search = screen.getByRole("searchbox", {
      name: "Search foundation status",
    })
    fireEvent.keyDown(document, { key: "k", ctrlKey: true })
    expect(search).toHaveFocus()
  })

  it("exposes no fake navigation or excluded template controls", () => {
    render(<Home />)

    expect(screen.getAllByRole("link")).toHaveLength(2)
    expect(screen.getByRole("link", { name: /Foundation/i })).toHaveAttribute(
      "href",
      "/"
    )

    for (const excluded of [
      /theme customizer/i,
      /customize columns/i,
      /add section/i,
      /blocks/i,
      /landing page/i,
    ]) {
      expect(
        screen.queryByRole("button", { name: excluded })
      ).not.toBeInTheDocument()
      expect(
        screen.queryByRole("link", { name: excluded })
      ).not.toBeInTheDocument()
    }
  })
})
