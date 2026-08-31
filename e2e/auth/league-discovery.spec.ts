import { expect, test, type Page } from "@playwright/test"
import { createClient } from "@supabase/supabase-js"

const password = "correct horse battery staple"

async function createConnectedAccount(
  page: Page,
  email: string,
  sleeperUsername: string
) {
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Task 006 Test User")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByLabel("Confirm password").fill(password)
  await page.getByRole("button", { name: "Create account" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)

  await page.getByLabel("Sleeper username").fill(sleeperUsername)
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await expect(
    page.getByRole("heading", { name: "Sleeper leagues" })
  ).toBeVisible()
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

async function importLeagues(page: Page) {
  await page
    .getByRole("button", {
      name: /^(Import|Refresh) current-season leagues$/,
    })
    .click()
}

test.describe.configure({ mode: "serial" })

test("imports, refreshes, reconciles, and persists current-season leagues", async ({
  page,
}) => {
  const email = "task006-shrinking@example.test"
  await createConnectedAccount(page, email, "shrinking-user")

  await expect(page.getByText("Not fetched", { exact: true })).toBeVisible()
  await expect(page.getByText("Not started", { exact: true })).toBeVisible()
  await expect(page.getByText("0", { exact: true })).toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot(
    "league-discovery-before-import-desktop.png",
    { animations: "disabled", fullPage: true }
  )

  await importLeagues(page)
  await expect(page.getByText("League discovery complete.")).toBeVisible()
  await expect(page.getByText("2026", { exact: true })).toBeVisible()
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()
  await expect(page.getByText("Fixture Best Ball")).toBeVisible()
  await expect(page.getByText("Fixture Dynasty Superflex")).toBeVisible()
  await expect(page.getByText("Dynasty", { exact: true })).toBeVisible()
  await expect(page.getByText("Half PPR", { exact: true })).toBeVisible()
  await expect(page.getByText("Yes", { exact: true }).first()).toBeVisible()

  await expect(page).toHaveScreenshot("league-discovery-imported-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("league-discovery-imported-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 1280, height: 720 })

  await importLeagues(page)
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()
  await expect(page.getByText("Fixture Best Ball")).toBeVisible()
  await expect(page.getByText("Fixture Dynasty Superflex")).toBeVisible()

  await importLeagues(page)
  await expect(page.getByText("1 league", { exact: true })).toBeVisible()
  await expect(page.getByText("Fixture Best Ball")).toBeVisible()
  await expect(page.getByText("Fixture Dynasty Superflex")).not.toBeVisible()

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false } }
  )
  const authResult = await supabase.auth.signInWithPassword({ email, password })
  expect(authResult.error).toBeNull()
  const linkResult = await supabase
    .from("user_fantasy_accounts")
    .select("fantasy_account_id")
    .eq("is_primary", true)
    .single()
  expect(linkResult.error).toBeNull()
  const associationResult = await supabase
    .from("fantasy_account_leagues")
    .select("removed_at, leagues!inner(external_league_id)")
    .eq("fantasy_account_id", linkResult.data!.fantasy_account_id)
  expect(associationResult.error).toBeNull()
  expect(associationResult.data).toHaveLength(2)
  const storedLeagueResult = await supabase
    .from("leagues")
    .select("name")
    .in("external_league_id", [
      "fixture-league-best-ball",
      "fixture-league-dynasty",
    ])
    .order("name")
  expect(storedLeagueResult.error).toBeNull()
  expect(storedLeagueResult.data!.map((league) => league.name)).toEqual([
    "Fixture Best Ball",
    "Fixture Dynasty Superflex",
  ])
  expect(
    associationResult.data!.filter((association) => !association.removed_at)
  ).toHaveLength(1)

  await page.getByRole("button", { name: "Sign out" }).click()
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await expect(page.getByText("1 league", { exact: true })).toBeVisible()
  await expect(page.getByText("Fixture Best Ball")).toBeVisible()
})

test("renders a successful empty collection as zero, not an error", async ({
  page,
}) => {
  await createConnectedAccount(page, "task006-empty@example.test", "empty-user")
  await importLeagues(page)

  await expect(page.getByText("League discovery complete.")).toBeVisible()
  await expect(
    page.getByText(
      "No current-season Sleeper leagues were returned for this account."
    )
  ).toBeVisible()
  await expect(page.getByText("Failed", { exact: true })).not.toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot("league-discovery-empty-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
})

test("fails malformed and exhausted transient responses safely", async ({
  page,
}) => {
  await createConnectedAccount(
    page,
    "task006-malformed@example.test",
    "malformed-user"
  )
  await importLeagues(page)
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()

  await importLeagues(page)
  await expect(
    page.getByRole("alert").filter({
      hasText: "Sleeper returned an unexpected league response. Try again.",
    })
  ).toBeVisible()
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()
  await expect(page.getByText("Fixture Best Ball")).toBeVisible()

  await page.getByRole("button", { name: "Sign out" }).click()
  await createConnectedAccount(
    page,
    "task006-transient@example.test",
    "transient-league-user"
  )
  await importLeagues(page)
  await expect(
    page
      .getByRole("alert")
      .filter({ hasText: "Sleeper is temporarily unavailable. Try again." })
  ).toBeVisible()
  await expect(page.getByText("Failed", { exact: true })).toBeVisible()
})

test("reuses a fresh running discovery without a second source read", async ({
  context,
  page,
}) => {
  await createConnectedAccount(
    page,
    "task006-running@example.test",
    "running-user"
  )
  const secondPage = await context.newPage()
  await secondPage.goto("/")

  await page
    .getByRole("button", { name: "Import current-season leagues" })
    .click({ noWaitAfter: true })
  await secondPage
    .getByRole("button", { name: "Import current-season leagues" })
    .click({ noWaitAfter: true })

  await expect
    .poll(async () => {
      const first = await page
        .getByText("League discovery is already running.")
        .count()
      const second = await secondPage
        .getByText("League discovery is already running.")
        .count()
      return first + second
    })
    .toBe(1)
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()
})
