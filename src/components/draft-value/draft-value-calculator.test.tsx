import { fireEvent, render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"
import { DraftValueCalculator } from "./draft-value-calculator"

function loadAndFreezeExample() {
  fireEvent.click(screen.getByRole("button", { name: "Load example" }))
  fireEvent.click(screen.getByRole("button", { name: "Freeze benchmark" }))
}
describe("DraftValueCalculator", () => {
  it("starts empty and does not present an example as imported portfolio data", () => {
    render(<DraftValueCalculator accountId="example-account" />)
    expect(screen.getByLabelText("Positional market curve")).toHaveValue("")
    expect(screen.getByText(/manual calculations, separate/i)).toBeVisible()
    expect(
      screen.queryByLabelText("Frozen price benchmark")
    ).not.toBeInTheDocument()
  })
  it("keeps RB11 fixed while the user records both +4 and −7 weekly outcomes", () => {
    render(<DraftValueCalculator accountId="example-account" />)
    loadAndFreezeExample()
    expect(screen.getByLabelText("Positional market curve")).toBeDisabled()
    expect(
      within(screen.getByLabelText("Frozen price benchmark")).getByText("RB11")
    ).toBeVisible()
    expect(
      within(screen.getByLabelText("Frozen price benchmark")).getByText("RB14")
    ).toBeVisible()
    fireEvent.change(screen.getByLabelText("Through week"), {
      target: { value: "6" },
    })
    fireEvent.change(screen.getByLabelText("Actual positional rank"), {
      target: { value: "7" },
    })
    fireEvent.click(screen.getByRole("button", { name: "Add or update week" }))
    fireEvent.change(screen.getByLabelText("Through week"), {
      target: { value: "7" },
    })
    fireEvent.change(screen.getByLabelText("Actual positional rank"), {
      target: { value: "18" },
    })
    fireEvent.click(screen.getByRole("button", { name: "Add or update week" }))
    const table = screen.getByRole("table", {
      name: "Manual weekly rank comparisons",
    })
    expect(within(table).getByText("+4")).toBeVisible()
    expect(within(table).getByText("-7")).toBeVisible()
    expect(
      within(screen.getByLabelText("Frozen price benchmark")).getByText("RB11")
    ).toBeVisible()
  })
  it("saves only on explicit request and isolates saved calculations by account", () => {
    localStorage.clear()
    const { unmount } = render(<DraftValueCalculator accountId="account-a" />)
    loadAndFreezeExample()
    expect(localStorage.length).toBe(0)
    fireEvent.click(screen.getByRole("button", { name: "Save on this device" }))
    expect(localStorage.length).toBe(1)
    unmount()
    const other = render(<DraftValueCalculator accountId="account-b" />)
    fireEvent.click(
      screen.getByRole("button", { name: "Restore saved calculation" })
    )
    expect(screen.getByRole("alert")).toHaveTextContent(
      "No calculation is saved"
    )
    other.unmount()
    render(<DraftValueCalculator accountId="account-a" />)
    fireEvent.click(
      screen.getByRole("button", { name: "Restore saved calculation" })
    )
    expect(
      within(screen.getByLabelText("Frozen price benchmark")).getByText("RB11")
    ).toBeVisible()
    localStorage.clear()
  })
  it("shows input errors and leaves the benchmark editable", () => {
    render(<DraftValueCalculator accountId="example-account" />)
    fireEvent.click(screen.getByRole("button", { name: "Freeze benchmark" }))
    expect(screen.getByRole("alert")).toHaveTextContent("Name the scoring")
    expect(screen.getByLabelText("Positional market curve")).toBeEnabled()
  })
})
