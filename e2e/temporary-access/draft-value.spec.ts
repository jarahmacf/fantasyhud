import { expect, test } from "@playwright/test"

test("calculates, freezes and restores draft value without a login", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1536, height: 1024 })
  await page.goto("/draft-value")
  await expect(
    page.getByRole("heading", { name: "Draft value", exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("Portfolio tracking is not connected yet")
  ).toBeVisible()
  await expect(page.getByLabel("Positional market curve")).toHaveValue("")
  await page.getByRole("button", { name: "Load example" }).click()
  await page.getByRole("button", { name: "Freeze benchmark" }).click()
  const benchmark = page.getByLabel("Frozen price benchmark")
  await expect(benchmark.getByText("RB11", { exact: true })).toBeVisible()
  await expect(benchmark.getByText("RB14", { exact: true })).toBeVisible()
  await expect(page.getByLabel("Round.selection paid")).toBeDisabled()
  await page.getByLabel("Through week").fill("6")
  await page.getByLabel("Actual positional rank", { exact: true }).fill("7")
  await page.getByRole("button", { name: "Add or update week" }).click()
  await expect(
    page
      .getByRole("table", { name: "Manual weekly rank comparisons" })
      .getByText("+4", { exact: true })
  ).toBeVisible()
  await page.getByRole("button", { name: "Save on this device" }).click()
  await page.reload()
  await page.getByRole("button", { name: "Restore saved calculation" }).click()
  await expect(benchmark.getByText("RB11", { exact: true })).toBeVisible()
  await expect(
    page
      .getByRole("table", { name: "Manual weekly rank comparisons" })
      .getByText("+4", { exact: true })
  ).toBeVisible()
  await page.getByLabel("Through week").fill("7")
  await page.getByLabel("Actual positional rank", { exact: true }).fill("18")
  await page.getByRole("button", { name: "Add or update week" }).click()
  await expect(benchmark.getByText("RB11", { exact: true })).toBeVisible()
  await expect(
    page
      .getByRole("table", { name: "Manual weekly rank comparisons" })
      .getByText("-7", { exact: true })
  ).toBeVisible()
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await expect.soft(page).toHaveScreenshot("draft-value-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect.soft(page).toHaveScreenshot("draft-value-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth
    )
  ).toBe(true)
})

test("auction values use budget shares and PPG outcomes require qualification", async ({
  page,
}) => {
  await page.goto("/draft-value")
  await page.getByLabel("Draft price", { exact: true }).selectOption("auction")
  await page
    .getByLabel("Scoring and league format")
    .fill("Manual auction fixture · 12-team exact scoring · 200 budget")
  await page.getByLabel("Auction amount paid").fill("25")
  await page.getByLabel("Positional market curve").fill("10,40\n11,30\n12,20")
  await page.getByRole("button", { name: "Freeze benchmark" }).click()
  await expect(
    page
      .getByLabel("Frozen price benchmark")
      .getByText("RB11.5", { exact: true })
  ).toBeVisible()
  await page.getByLabel("Through week").fill("6")
  await page
    .getByLabel("Rank measure", { exact: true })
    .selectOption("season_points_per_game_rank")
  await page.getByLabel("Actual positional rank", { exact: true }).fill("7")
  await page.getByLabel("Minimum games for PPG rank").fill("4")
  await page.getByLabel("Player’s games played").fill("3")
  await page.getByRole("button", { name: "Add or update week" }).click()
  await expect(page.getByRole("alert")).toContainText("does not qualify")
  await page.getByLabel("Player’s games played").fill("4")
  await page.getByRole("button", { name: "Add or update week" }).click()
  await expect(
    page
      .getByRole("table", { name: "Manual weekly rank comparisons" })
      .getByText("+4.5", { exact: true })
  ).toBeVisible()
})
