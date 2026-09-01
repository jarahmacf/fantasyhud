import { fireEvent, render, screen, within } from "@testing-library/react"
import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("next/server", () => ({ connection: vi.fn() }))
vi.mock("@/lib/auth/current-user", () => ({
  getCurrentAuthIdentity: vi.fn(),
}))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))

import FoundationPage from "@/app/foundation/page"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

const mockedIdentity = vi.mocked(getCurrentAuthIdentity)
const mockedServerClient = vi.mocked(createServerSupabaseClient)

describe("foundation page", () => {
  beforeEach(() => {
    mockedIdentity.mockReset()
    mockedIdentity.mockResolvedValue(null)
    mockedServerClient.mockReset()
  })

  it("renders the canonical shell and repository heading", async () => {
    render(await FoundationPage())

    expect(screen.getByText("FANTASY HUD")).toBeInTheDocument()
    expect(screen.getByText("Portfolio Command Center")).toBeInTheDocument()
    expect(
      screen.getByRole("heading", { level: 1, name: "Repository foundation" })
    ).toBeInTheDocument()
    expect(screen.getByText("Local workspace")).toBeInTheDocument()
    expect(screen.getByText("No signed-in user")).toBeInTheDocument()
  })

  it("renders four cards with the canonical composition", async () => {
    const { container } = render(await FoundationPage())
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

  it("renders thirteen truthful foundation rows", async () => {
    render(await FoundationPage())

    const table = screen.getByRole("table", { name: "Foundation status" })
    expect(within(table).getAllByRole("row")).toHaveLength(14)
    expect(
      within(table).getByRole("row", {
        name: /Hosted development Configured Supabase GitHub integration/i,
      })
    ).toBeInTheDocument()
    expect(
      within(table).getByRole("row", {
        name: /Account identity model Ready Shared provider identity/i,
      })
    ).toBeInTheDocument()
  })

  it("filters every foundation field and clearing restores all rows", async () => {
    render(await FoundationPage())

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
      "1 of 13 systems matching “pgTAP”"
    )

    fireEvent.click(screen.getByRole("button", { name: "Clear search" }))
    expect(search).toHaveValue("")
    expect(within(table).getAllByRole("row")).toHaveLength(14)
  })

  it("focuses search with the platform keyboard shortcut", async () => {
    render(await FoundationPage())

    const search = screen.getByRole("searchbox", {
      name: "Search foundation status",
    })
    fireEvent.keyDown(document, { key: "k", ctrlKey: true })
    expect(search).toHaveFocus()
  })

  it("exposes no fake navigation or excluded template controls", async () => {
    render(await FoundationPage())

    expect(screen.getAllByRole("link")).toHaveLength(2)
    expect(screen.getByRole("link", { name: /Foundation/i })).toHaveAttribute(
      "href",
      "/foundation"
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

  it("retains signed-in navigation, account label, and sign-out", async () => {
    mockedIdentity.mockResolvedValue({
      id: "user-id",
      email: "signed-in@example.test",
    })
    const builder = {
      select: vi.fn(),
      eq: vi.fn(),
      order: vi.fn(),
      limit: vi.fn(),
      maybeSingle: vi.fn().mockResolvedValue({
        data: {
          fantasy_accounts: { provider: "sleeper", username: "fixture" },
        },
        error: null,
      }),
    }
    builder.select.mockReturnValue(builder)
    builder.eq.mockReturnValue(builder)
    builder.order.mockReturnValue(builder)
    builder.limit.mockReturnValue(builder)
    mockedServerClient.mockResolvedValue({
      from: vi.fn().mockReturnValue(builder),
    } as never)

    render(await FoundationPage())

    expect(screen.getByRole("link", { name: /Leagues/i })).toHaveAttribute(
      "href",
      "/"
    )
    expect(screen.getByRole("link", { name: /Players/i })).toHaveAttribute(
      "href",
      "/players"
    )
    expect(screen.getByText("@fixture")).toBeInTheDocument()
    expect(
      screen.getByRole("button", { name: /Sign out/i })
    ).toBeInTheDocument()
  })
})
