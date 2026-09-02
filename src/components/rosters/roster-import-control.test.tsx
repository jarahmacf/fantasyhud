import { fireEvent, render, screen, waitFor } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"

vi.mock("@/app/rosters/actions", () => ({
  importCurrentSleeperRostersAction: vi.fn(),
}))

import { RosterImportControl } from "./roster-import-control"
import { importCurrentSleeperRostersAction } from "@/app/rosters/actions"

const mockedAction = vi.mocked(importCurrentSleeperRostersAction)

describe("RosterImportControl", () => {
  it("uses the first-import and refresh labels truthfully", () => {
    const { unmount } = render(<RosterImportControl hasImported={false} />)
    expect(
      screen.getByRole("button", { name: "Import current-season rosters" })
    ).toBeEnabled()

    unmount()
    render(<RosterImportControl hasImported />)
    expect(
      screen.getByRole("button", { name: "Refresh current-season rosters" })
    ).toBeEnabled()
  })

  it("shows and disables the running state", () => {
    render(<RosterImportControl hasImported={false} isRunning />)
    expect(
      screen.getByRole("button", { name: "Importing rosters…" })
    ).toBeDisabled()
  })

  it("keeps a reused-run response busy before parent revalidation", async () => {
    mockedAction.mockResolvedValue({
      status: "running",
      message: "Roster import is already running.",
    })
    render(<RosterImportControl hasImported={false} />)

    fireEvent.click(
      screen.getByRole("button", { name: "Import current-season rosters" })
    )

    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Importing rosters…" })
      ).toBeDisabled()
    )
    expect(screen.getByRole("status")).toHaveTextContent(
      "Roster import is already running."
    )
  })
})
