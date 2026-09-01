import { expect, test, type Page } from "@playwright/test"
import { createClient } from "@supabase/supabase-js"

const password = "correct horse battery staple"
const email = "task007a-player-catalog@example.test"

async function createConnectedAccount(page: Page) {
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Task 007A Test User")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByLabel("Confirm password").fill(password)
  await page.getByRole("button", { name: "Create account" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)

  await page.getByLabel("Sleeper username").fill("fixture-user")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
}

async function disableMotion(page: Page) {
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.addStyleTag({
    content:
      "*, *::before, *::after { animation-duration: 0s !important; animation-delay: 0s !important; transition-duration: 0s !important; caret-color: transparent !important; }",
  })
}

test.describe.configure({ mode: "serial" })

test("imports one shared canonical catalog and reuses its 24-hour freshness", async ({
  page,
}) => {
  await createConnectedAccount(page)
  await page.getByRole("link", { name: "Players" }).click()
  await expect(page).toHaveURL(/\/players$/)
  await expect(
    page.getByRole("heading", { name: "Player catalog" })
  ).toBeVisible()
  await expect(page.getByText("Not imported", { exact: true })).toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot(
    "player-catalog-before-import-desktop.png",
    {
      animations: "disabled",
      fullPage: true,
    }
  )

  await page.getByRole("button", { name: "Import player catalog" }).click()
  await expect(page.getByText("Player catalog refreshed.")).toBeVisible()
  await expect(page.getByText("Succeeded", { exact: true })).toBeVisible()
  await expect(page.getByText("600", { exact: true })).toBeVisible()
  await expect(page.getByText("4", { exact: true })).toBeVisible()
  await expect(page.getByText("1", { exact: true })).toBeVisible()
  await expect(page.getByText("603", { exact: true })).toBeVisible()
  await expect(page.getByText("Aaron Fixture", { exact: true })).toBeVisible()
  await expect(
    page.getByText("Arizona Fixture Defense", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("Dual Position Fixture", { exact: true })
  ).toBeVisible()
  await expect(page.getByText("catalog-0004", { exact: true })).toBeVisible()
  await expect(page.getByText("Out · Knee", { exact: true })).toBeVisible()

  await expect(page).toHaveScreenshot("player-catalog-imported-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("player-catalog-imported-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 1280, height: 720 })

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false } }
  )
  const authResult = await supabase.auth.signInWithPassword({ email, password })
  expect(authResult.error).toBeNull()

  const playerCount = await supabase
    .from("players")
    .select("id", { count: "exact", head: true })
  const primaryMappings = await supabase
    .from("player_external_ids")
    .select("player_id, external_id")
    .eq("namespace", "sleeper")
    .eq("sport", "nfl")
    .eq("is_primary", true)
    .is("removed_at", null)
  const allMappings = await supabase
    .from("player_external_ids")
    .select("namespace, sport, external_id, player_id")
    .is("removed_at", null)
  const activeIndividualPlayers = await supabase
    .from("players")
    .select("id, player_external_ids!inner(id)", {
      count: "exact",
      head: true,
    })
    .eq("entity_type", "player")
    .eq("active", true)
    .eq("player_external_ids.namespace", "sleeper")
    .eq("player_external_ids.sport", "nfl")
    .eq("player_external_ids.is_primary", true)
    .is("player_external_ids.removed_at", null)
  const currentTeamDefenses = await supabase
    .from("players")
    .select("id, player_external_ids!inner(id)", {
      count: "exact",
      head: true,
    })
    .eq("entity_type", "team_defense")
    .eq("player_external_ids.namespace", "sleeper")
    .eq("player_external_ids.sport", "nfl")
    .eq("player_external_ids.is_primary", true)
    .is("player_external_ids.removed_at", null)
  const activeNonPlayerSentinels = await supabase
    .from("players")
    .select(
      "entity_type, active, player_external_ids!inner(external_id, removed_at)"
    )
    .eq("player_external_ids.namespace", "sleeper")
    .eq("player_external_ids.sport", "nfl")
    .eq("player_external_ids.is_primary", true)
    .is("player_external_ids.removed_at", null)
    .in("player_external_ids.external_id", ["catalog-0001", "catalog-0004"])

  expect(playerCount.error).toBeNull()
  expect(playerCount.count).toBe(600)
  expect(primaryMappings.error).toBeNull()
  expect(primaryMappings.data).toHaveLength(600)
  expect(
    new Set(primaryMappings.data!.map((mapping) => mapping.player_id)).size
  ).toBe(600)
  expect(
    primaryMappings.data!.every(
      (mapping) => typeof mapping.external_id === "string"
    )
  ).toBe(true)
  expect(allMappings.error).toBeNull()
  expect(
    new Set(
      allMappings.data!.map(
        (mapping) =>
          `${mapping.namespace}:${mapping.sport}:${mapping.external_id}`
      )
    ).size
  ).toBe(allMappings.data!.length)
  expect(activeIndividualPlayers.error).toBeNull()
  expect(activeIndividualPlayers.count).toBe(4)
  expect(currentTeamDefenses.error).toBeNull()
  expect(currentTeamDefenses.count).toBe(1)
  expect(activeNonPlayerSentinels.error).toBeNull()
  expect(activeNonPlayerSentinels.data).toHaveLength(2)
  expect(
    activeNonPlayerSentinels.data!.map((player) => ({
      entityType: player.entity_type,
      active: player.active,
    }))
  ).toEqual(
    expect.arrayContaining([
      { entityType: "team_defense", active: true },
      { entityType: "unknown", active: true },
    ])
  )

  await page.getByRole("button", { name: "Check catalog freshness" }).click()
  await expect(page.getByText("Player catalog is current.")).toBeVisible()
  const catalogRuns = await supabase
    .from("provider_catalog_runs")
    .select("status")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .eq("catalog", "players")
  expect(catalogRuns.error).toBeNull()
  expect(catalogRuns.data).toEqual([{ status: "succeeded" }])
  const privateRunOwnership = await supabase
    .from("provider_catalog_runs")
    .select("triggered_by_user_id")
  expect(privateRunOwnership.error?.code).toBe("42501")
  expect(privateRunOwnership.data).toBeNull()

  const requestCountResponse = await fetch(
    `${process.env.SLEEPER_MOCK_CONTROL_URL}/player-request-count`
  )
  expect(requestCountResponse.ok).toBe(true)
  expect(await requestCountResponse.json()).toEqual({ count: 1 })

  await page.getByRole("button", { name: "Sign out" }).click()
  await expect(page).toHaveURL(/\/auth\/sign-in$/)
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await page.goto("/players")
  await expect(page.getByText("600", { exact: true })).toBeVisible()
  await expect(page.getByText("Aaron Fixture", { exact: true })).toBeVisible()

  await page.goto("/foundation")
  await expect(page.getByRole("link", { name: "Leagues" })).toBeVisible()
  await expect(page.getByRole("link", { name: "Players" })).toBeVisible()
  await expect(page.getByText("@CanonicalFixtureUser")).toBeVisible()
  await expect(page.getByRole("button", { name: "Sign out" })).toBeVisible()
  await disableMotion(page)
  await expect(page).toHaveScreenshot("foundation-signed-in-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
})
