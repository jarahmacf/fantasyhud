import { research, profile } from "./research-fixture"
import { expect, test } from "@playwright/test"
const league = {
  token: "a".repeat(24),
  name: "Kickoff fixture",
  season: 2026,
  teams: 2,
  bestBall: true,
  format: "ppr",
  management: "redraft",
  scoring: { rec: 1, rush_yd: 0.1 },
  positions: ["RB"],
  rosters: [
    { id: "1", owned: true, players: ["p1"], wins: 0, losses: 0, ties: 0 },
    { id: "2", owned: false, players: ["p2"], wins: 0, losses: 0, ties: 0 },
  ],
  matchups: [
    {
      rosterId: "1",
      matchupId: 1,
      points: 10,
      customPoints: null,
      players: ["p1"],
      starters: ["p1"],
      playerPoints: { p1: 10 },
    },
    {
      rosterId: "2",
      matchupId: 1,
      points: 20,
      customPoints: null,
      players: ["p2"],
      starters: ["p2"],
      playerPoints: { p2: 20 },
    },
  ],
  error: null,
  fetchedAt: "2026-09-09T23:00:00Z",
}
const overview = {
  season: 2026,
  week: 1,
  seasonType: "regular",
  fetchedAt: league.fetchedAt,
  leagues: [league],
  players: [{ id: "p1", name: "Fixture Runner", position: "RB", team: "BUF" }],
}
const detail = {
  league,
  drafts: [
    {
      id: "board",
      type: "snake",
      complete: true,
      teams: 2,
      error: null,
      picks: [1, 2].map((n) => ({
        id: `p${n}`,
        name: `Runner ${n}`,
        position: "RB",
        team: "BUF",
        pick: n,
        round: 1,
        slot: n,
        own: n === 1,
        keeper: null,
        amount: null,
      })),
    },
  ],
  weeks: [
    {
      week: 1,
      fetchedAt: league.fetchedAt,
      matchups: league.matchups,
      error: null,
    },
  ],
  fetchedAt: league.fetchedAt,
}
test("tracks league matchups, whole draft portfolio and price comparisons without login", async ({
  page,
}, info) => {
  await page.route("**/api/research**", (route) =>
    route.fulfill({
      json: new URL(route.request().url()).searchParams.has("player")
        ? profile
        : research,
    })
  )
  await page.route("**/api/tracker**", (route) =>
    route.fulfill({
      json: new URL(route.request().url()).searchParams.has("league")
        ? detail
        : overview,
    })
  )
  await page.goto("/tracker")
  await expect(
    page.getByRole("heading", { name: "Your season, live" })
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Kickoff fixture" })
  ).toBeVisible()
  await page.getByRole("button", { name: "Player exposure" }).click()
  await expect(page.getByText("Fixture Runner", { exact: true })).toBeVisible()
  await page
    .getByRole("button", { name: "Draft portfolio", exact: true })
    .click()
  await page
    .getByRole("combobox", { name: "Draft type", exact: true })
    .selectOption("auction")
  await expect(
    page.getByRole("cell", { name: "$30", exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("cell", { name: "≈ 52", exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("cell", { name: "+12", exact: true })
  ).toBeVisible()
  await page.getByRole("link", { name: "Fixture Runner" }).click()
  await expect(
    page.getByRole("heading", { name: "Fixture Runner", exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("img", {
      name: "Weekly cumulative positional rank compared with price-implied rank",
    })
  ).toBeVisible()
  await expect(
    page.getByRole("table", { name: "Player weekly results" })
  ).toBeVisible()
  await page.setViewportSize({ width: 1440, height: 1000 })
  await page.screenshot({
    path: info.outputPath("tracker-player-desktop.png"),
    animations: "disabled",
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({
    path: info.outputPath("tracker-player-mobile.png"),
    animations: "disabled",
  })
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth
    )
  ).toBe(true)
  await page.getByRole("button", { name: "All acquisitions (1)" }).click()
  await expect(
    page.getByRole("cell", { name: "$30", exact: true })
  ).toBeVisible()
  await page
    .getByRole("button", { name: "Research notes", exact: true })
    .click()
  await page.getByLabel("Your notes").fill("Watch the weekly workload.")
  await page.getByRole("button", { name: "Save notes" }).click()
  await page.reload()
  await page
    .getByRole("button", { name: "Research notes", exact: true })
    .click()
  await expect(page.getByLabel("Your notes")).toHaveValue(
    "Watch the weekly workload."
  )
  await page.goto("/tracker")
  await page.getByRole("button", { name: "Leagues & matchups" }).click()
  await page.getByRole("button", { name: "Kickoff fixture" }).click()
  await expect(page.getByRole("dialog")).toBeVisible()
  await expect(
    page.getByText("Draft value tracker", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("cell", { name: "Unknown", exact: true })
  ).toBeVisible()
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.setViewportSize({ width: 1440, height: 1000 })
  await page.screenshot({
    path: info.outputPath("tracker-desktop.png"),
    animations: "disabled",
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({
    path: info.outputPath("tracker-mobile.png"),
    animations: "disabled",
  })
  await expect(
    page.getByRole("button", { name: "Close", exact: true })
  ).toBeVisible()
})
