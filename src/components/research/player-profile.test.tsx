import { afterEach, it, expect, vi } from "vitest"
import { render, screen, waitFor, within } from "@testing-library/react"
import { profile } from "../../../e2e/temporary-access/research-fixture"
import { PlayerProfile } from "./player-profile"
afterEach(() => vi.unstubAllGlobals())
it("plots an out-of-range purchase bound without silently substituting the player's own ADP rank", async () => {
  const bounded = {
    ...profile,
    acquisitions: profile.acquisitions.map((a) => ({
      ...a,
      impliedRank: null,
      rankBound: { value: 1, direction: "at_most" as const },
      adpBound: { value: 2, direction: "at_most" as const },
      equivalentAdp: null,
    })),
  }
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue({ ok: true, json: async () => bounded })
  )
  render(<PlayerProfile token={profile.player.token} initialContext={null} />)
  await waitFor(() =>
    expect(
      screen.getByRole("heading", { name: "Fixture Runner" })
    ).toBeInTheDocument()
  )
  const chart = screen.getByRole("img", {
    name: "Weekly cumulative positional rank compared with price-implied rank",
  })
  expect(within(chart).getByText("Price bound ≤ 1")).toBeInTheDocument()
  expect(within(chart).queryByText("Price 6")).not.toBeInTheDocument()
})
