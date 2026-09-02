import { expect, test, type Page } from "@playwright/test"
import { createClient } from "@supabase/supabase-js"

const email = "task007b2-roster-import@example.test"
const password = "correct horse battery staple"

async function setRosterScenario(name: string) {
  const response = await fetch(
    `${process.env.SLEEPER_MOCK_CONTROL_URL}/roster-scenario?name=${encodeURIComponent(name)}`
  )
  expect(response.ok).toBe(true)
  expect(await response.json()).toEqual({ scenario: name })
}

async function getRosterRequestCount() {
  const response = await fetch(
    `${process.env.SLEEPER_MOCK_CONTROL_URL}/roster-request-count`
  )
  expect(response.ok).toBe(true)
  return (await response.json()) as {
    users: number
    rosters: number
    total: number
  }
}

async function privateRosterStateIsClean(runId: string) {
  const response = await fetch(
    `${process.env.SLEEPER_MOCK_CONTROL_URL}/private-roster-state?run_id=${encodeURIComponent(runId)}`
  )
  expect(response.ok).toBe(true)
  return (await response.json()) as { clean: boolean }
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

async function importRosters(page: Page) {
  const actionResponse = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/rosters"
  )
  await page
    .getByRole("button", {
      name: /^(Import|Refresh) current-season rosters$/,
    })
    .click()
  await actionResponse
  await expect(
    page.getByRole("button", {
      name: /^(Import|Refresh) current-season rosters$/,
    })
  ).toBeEnabled()
}

function rosterSummaryCard(page: Page, label: string) {
  return page
    .getByLabel("Roster import summary")
    .locator('[data-slot="card"]')
    .filter({ has: page.getByText(label, { exact: true }) })
}

test.describe.configure({ mode: "serial" })

test("imports, refreshes, reconciles, and persists current-season rosters", async ({
  page,
}) => {
  test.setTimeout(180_000)
  await setRosterScenario("normal")
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Task 007B.2 Test User")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByLabel("Confirm password").fill(password)
  await page.getByRole("button", { name: "Create account" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)

  await page.getByLabel("Sleeper username").fill("fixture-user")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)

  await page
    .getByRole("button", { name: "Import current-season leagues" })
    .click()
  await expect(page.getByText("League discovery complete.")).toBeVisible()
  await expect(page.getByText("2 leagues", { exact: true })).toBeVisible()

  await page.getByRole("link", { name: "Players" }).click()
  await page
    .getByRole("button", {
      name: /^(Import player catalog|Check catalog freshness)$/,
    })
    .click()
  await expect(
    page.getByText(/^(Player catalog refreshed|Player catalog is current)\.$/)
  ).toBeVisible()

  await page.getByRole("link", { name: "Rosters" }).click()
  await expect(page).toHaveURL(/\/rosters$/)
  await expect(
    page.getByRole("heading", { name: "Sleeper rosters" })
  ).toBeVisible()
  await expect(page.getByText("Not started", { exact: true })).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Import current-season rosters" })
  ).toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot("rosters-before-import-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })

  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()
  await expect(page.getByText("Succeeded", { exact: true })).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Current-season leagues").getByText("2", {
      exact: true,
    })
  ).toBeVisible()
  await expect(
    page.getByLabel("Roster import summary").getByText("Sleeper NFL 2026")
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Owned rosters").getByText("2", { exact: true })
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Last confirmed active memberships").getByText(
      "15",
      { exact: true }
    )
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Unresolved leagues").getByText("0", {
      exact: true,
    })
  ).toBeVisible()
  await expect(page.getByText("Fixture Alpha", { exact: true })).toBeVisible()
  await expect(
    page.getByText("Fixture Dynasty Team", { exact: true })
  ).toBeVisible()
  await expect(page.getByText("Owner", { exact: true })).toBeVisible()
  await expect(page.getByText("Co-owner", { exact: true })).toBeVisible()
  await expect(page.getByText("Aaron Fixture", { exact: true })).toBeVisible()
  await expect(
    page.getByText("Arizona Fixture Defense", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("roster-unknown-0001", { exact: true })
  ).toBeVisible()

  const ownedRosterTable = page.getByRole("table", {
    name: "Owned current-season Sleeper rosters",
  })
  const bestBallRow = ownedRosterTable
    .getByRole("row")
    .filter({ hasText: "Fixture Best Ball" })
  const dynastyRow = ownedRosterTable
    .getByRole("row")
    .filter({ hasText: "Fixture Dynasty Superflex" })
  await expect(bestBallRow.getByRole("cell")).toHaveText([
    "Fixture Best Ball",
    "Fixture Alpha",
    "Owner",
    "9",
    "5",
    "1",
    "Not reported",
    "1",
  ])
  await expect(dynastyRow.getByRole("cell")).toHaveText([
    "Fixture Dynasty Superflex",
    "Fixture Dynasty Team",
    "Co-owner",
    "6",
    "5",
    "0",
    "1",
    "0",
  ])
  await expect(
    page
      .getByRole("table", { name: "Current holdings preview" })
      .locator("tbody tr")
  ).toHaveCount(15)

  await expect(page).toHaveScreenshot("rosters-imported-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("rosters-imported-mobile.png", {
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

  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select("fantasy_account_id")
    .eq("is_primary", true)
    .single()
  expect(accountResult.error).toBeNull()
  const fantasyAccountId = accountResult.data!.fantasy_account_id

  const leagueLinks = await supabase
    .from("fantasy_account_leagues")
    .select("league_id")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  expect(leagueLinks.error).toBeNull()
  expect(leagueLinks.data).toHaveLength(2)
  const leagueIds = leagueLinks.data!.map((row) => row.league_id)

  const leagueUserResult = await supabase
    .from("league_users")
    .select("id, league_id, external_user_id, first_seen_at, removed_at")
    .in("league_id", leagueIds)
    .is("removed_at", null)
  const allRosterResult = await supabase
    .from("rosters")
    .select("id, league_id, external_roster_id, first_seen_at, removed_at")
    .in("league_id", leagueIds)
    .is("removed_at", null)
  expect(leagueUserResult.error).toBeNull()
  expect(allRosterResult.error).toBeNull()
  expect(leagueUserResult.data).toHaveLength(4)
  expect(allRosterResult.data).toHaveLength(4)
  expect(
    new Set(
      leagueUserResult.data!.map(
        (row) => `${row.league_id}:${row.external_user_id}`
      )
    ).size
  ).toBe(leagueUserResult.data!.length)
  expect(
    new Set(
      allRosterResult.data!.map(
        (row) => `${row.league_id}:${row.external_roster_id}`
      )
    ).size
  ).toBe(allRosterResult.data!.length)
  const originalLeagueUserFirstSeen = new Map(
    leagueUserResult.data!.map((row) => [row.id, row.first_seen_at])
  )
  const originalAllRosterFirstSeen = new Map(
    allRosterResult.data!.map((row) => [row.id, row.first_seen_at])
  )
  const allRosterIds = allRosterResult.data!.map((row) => row.id)

  const ownershipResult = await supabase
    .from("fantasy_account_rosters")
    .select(
      "id, league_id, roster_id, ownership_role, first_seen_at, removed_at"
    )
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  expect(ownershipResult.error).toBeNull()
  expect(ownershipResult.data).toHaveLength(2)
  expect(ownershipResult.data!.map((row) => row.ownership_role).sort()).toEqual(
    ["co_owner", "owner"]
  )
  const originalOwnershipFirstSeen = new Map(
    ownershipResult.data!.map((row) => [row.id, row.first_seen_at])
  )
  const ownedRosterIds = ownershipResult.data!.map((row) => row.roster_id)

  const rosterResult = await supabase
    .from("rosters")
    .select(
      "id, source_player_ids, source_starter_ids, source_reserve_ids, source_taxi_ids, source_keeper_ids, first_seen_at, removed_at"
    )
    .in("id", ownedRosterIds)
  expect(rosterResult.error).toBeNull()
  expect(rosterResult.data).toHaveLength(2)
  expect(
    rosterResult.data!.some(
      (row) =>
        (row.source_starter_ids as string[] | null)?.filter(
          (value: string) => value === "0"
        ).length === 2
    )
  ).toBe(true)
  expect(rosterResult.data!.some((row) => row.source_taxi_ids === null)).toBe(
    true
  )
  expect(
    rosterResult.data!.some(
      (row) =>
        Array.isArray(row.source_reserve_ids) &&
        row.source_reserve_ids.length === 0
    )
  ).toBe(true)
  const membershipResult = await supabase
    .from("roster_players")
    .select(
      "id, roster_id, player_id, source_player_external_id_id, source_order, starter_order, starter_slot, is_starter, is_reserve, is_taxi, is_keeper, first_seen_at, removed_at"
    )
    .in("roster_id", ownedRosterIds)
    .is("removed_at", null)
  expect(membershipResult.error).toBeNull()
  expect(membershipResult.data).toHaveLength(15)
  expect(membershipResult.data!.filter((row) => row.is_starter)).toHaveLength(
    10
  )
  expect(membershipResult.data!.filter((row) => row.is_reserve)).toHaveLength(1)
  expect(membershipResult.data!.filter((row) => row.is_taxi)).toHaveLength(1)
  expect(membershipResult.data!.filter((row) => row.is_keeper)).toHaveLength(1)
  expect(
    membershipResult.data!.every(
      (row) => row.player_id && row.source_player_external_id_id
    )
  ).toBe(true)
  for (const rosterId of ownedRosterIds) {
    const rows = membershipResult.data!.filter(
      (membership) => membership.roster_id === rosterId
    )
    expect(new Set(rows.map((row) => row.source_order)).size).toBe(rows.length)
    expect(rows.map((row) => row.source_order).sort((a, b) => a - b)).toEqual(
      Array.from({ length: rows.length }, (_value, index) => index + 1)
    )
    const starterOrders = rows
      .map((row) => row.starter_order)
      .filter((order): order is number => order !== null)
    expect(new Set(starterOrders).size).toBe(starterOrders.length)
    expect(starterOrders.sort((a, b) => a - b)).toEqual([1, 2, 3, 4, 5])
    expect(
      rows.filter((row) => row.is_starter).every((row) => row.starter_slot)
    ).toBe(true)
  }
  const originalMembershipState = new Map(
    membershipResult.data!.map((row) => [
      row.id,
      {
        sourceOrder: row.source_order,
        starterOrder: row.starter_order,
        isStarter: row.is_starter,
        isReserve: row.is_reserve,
        isTaxi: row.is_taxi,
        isKeeper: row.is_keeper,
      },
    ])
  )

  const allMembershipResult = await supabase
    .from("roster_players")
    .select(
      "id, roster_id, player_id, source_player_external_id_id, first_seen_at, removed_at"
    )
    .in("roster_id", allRosterIds)
    .is("removed_at", null)
  expect(allMembershipResult.error).toBeNull()
  expect(allMembershipResult.data).toHaveLength(19)
  expect(
    new Set(
      allMembershipResult.data!.map(
        (row) => `${row.roster_id}:${row.player_id}`
      )
    ).size
  ).toBe(allMembershipResult.data!.length)
  expect(
    new Set(
      allMembershipResult.data!.map(
        (row) => `${row.roster_id}:${row.source_player_external_id_id}`
      )
    ).size
  ).toBe(allMembershipResult.data!.length)
  const originalAllMembershipFirstSeen = new Map(
    allMembershipResult.data!.map((row) => [row.id, row.first_seen_at])
  )

  const placeholderMapping = await supabase
    .from("player_external_ids")
    .select("id")
    .eq("namespace", "sleeper")
    .eq("sport", "nfl")
    .eq("external_id", "0")
  expect(placeholderMapping.error).toBeNull()
  expect(placeholderMapping.data).toHaveLength(0)

  const referenceMapping = await supabase
    .from("player_external_ids")
    .select("external_id, player_id, is_primary, removed_at")
    .eq("namespace", "sleeper")
    .eq("sport", "nfl")
    .eq("external_id", "roster-unknown-0001")
    .single()
  expect(referenceMapping.error).toBeNull()
  expect(referenceMapping.data).toMatchObject({
    external_id: "roster-unknown-0001",
    is_primary: true,
    removed_at: null,
  })
  const referencePlayer = await supabase
    .from("players")
    .select("entity_type, display_name, primary_position, nfl_team, active")
    .eq("id", referenceMapping.data!.player_id)
    .single()
  expect(referencePlayer.error).toBeNull()
  expect(referencePlayer.data).toEqual({
    entity_type: "unknown",
    display_name: null,
    primary_position: null,
    nfl_team: null,
    active: null,
  })

  expect(await getRosterRequestCount()).toEqual({
    users: 2,
    rosters: 2,
    total: 4,
  })

  await setRosterScenario("same_collection")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()

  const replayOwnership = await supabase
    .from("fantasy_account_rosters")
    .select("id, first_seen_at")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  const replayLeagueUsers = await supabase
    .from("league_users")
    .select("id, first_seen_at")
    .in("league_id", leagueIds)
    .is("removed_at", null)
  const replayRosters = await supabase
    .from("rosters")
    .select("id, first_seen_at")
    .in("id", allRosterIds)
    .is("removed_at", null)
  const replayMemberships = await supabase
    .from("roster_players")
    .select("id, first_seen_at")
    .in("roster_id", allRosterIds)
    .is("removed_at", null)
  expect(replayOwnership.error).toBeNull()
  expect(replayLeagueUsers.error).toBeNull()
  expect(replayRosters.error).toBeNull()
  expect(replayMemberships.error).toBeNull()
  expect(replayOwnership.data).toHaveLength(2)
  expect(replayLeagueUsers.data).toHaveLength(4)
  expect(replayRosters.data).toHaveLength(4)
  expect(replayMemberships.data).toHaveLength(19)
  for (const row of replayOwnership.data!) {
    expect(row.first_seen_at).toBe(originalOwnershipFirstSeen.get(row.id))
  }
  for (const row of replayLeagueUsers.data!) {
    expect(row.first_seen_at).toBe(originalLeagueUserFirstSeen.get(row.id))
  }
  for (const row of replayRosters.data!) {
    expect(row.first_seen_at).toBe(originalAllRosterFirstSeen.get(row.id))
  }
  for (const row of replayMemberships.data!) {
    expect(row.first_seen_at).toBe(originalAllMembershipFirstSeen.get(row.id))
  }

  await setRosterScenario("unresolved_coowners")
  await importRosters(page)
  await expect(
    page.getByText(
      "Roster data imported, but some league ownership could not be resolved."
    )
  ).toBeVisible()
  await expect(page.getByText("Partial", { exact: true })).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Unresolved leagues").getByText("2", {
      exact: true,
    })
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Owned rosters").getByText("0", { exact: true })
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Last confirmed active memberships").getByText(
      "0",
      { exact: true }
    )
  ).toBeVisible()
  await expect(
    page
      .getByRole("table", { name: "Owned current-season Sleeper rosters" })
      .locator("tbody tr")
  ).toHaveCount(1)
  await expect(
    page
      .getByRole("table", { name: "Current holdings preview" })
      .locator("tbody tr")
  ).toHaveCount(1)
  await expect(
    page.getByText("No owned roster was resolved for this account.")
  ).toBeVisible()
  await expect(
    page.getByText(
      "No last-confirmed active memberships were resolved for confirmed-owned rosters."
    )
  ).toBeVisible()
  await expect(page.getByText("Fixture Alpha", { exact: true })).toHaveCount(0)
  await expect(
    page.getByText("Fixture Dynasty Team", { exact: true })
  ).toHaveCount(0)
  await expect(page).toHaveScreenshot("rosters-partial-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })

  const preservedOwnership = await supabase
    .from("fantasy_account_rosters")
    .select("id")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  expect(preservedOwnership.error).toBeNull()
  expect(preservedOwnership.data).toHaveLength(2)

  const unresolvedLeagueLinks = await supabase
    .from("fantasy_account_leagues")
    .select("league_id, roster_ownership_status")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  expect(unresolvedLeagueLinks.error).toBeNull()
  expect(unresolvedLeagueLinks.data).toHaveLength(2)
  expect(
    unresolvedLeagueLinks.data!.every(
      (row) => row.roster_ownership_status === "unresolved"
    )
  ).toBe(true)

  await setRosterScenario("normal")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Owned rosters").getByText("2", { exact: true })
  ).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Last confirmed active memberships").getByText(
      "15",
      { exact: true }
    )
  ).toBeVisible()
  await expect(
    page
      .getByRole("table", { name: "Owned current-season Sleeper rosters" })
      .locator("tbody tr")
  ).toHaveCount(2)
  await expect(
    page
      .getByRole("table", { name: "Current holdings preview" })
      .locator("tbody tr")
  ).toHaveCount(15)

  const restoredOwnership = await supabase
    .from("fantasy_account_rosters")
    .select("id, removed_at")
    .eq("fantasy_account_id", fantasyAccountId)
  const restoredLeagueLinks = await supabase
    .from("fantasy_account_leagues")
    .select("league_id, roster_ownership_status")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  expect(restoredOwnership.error).toBeNull()
  expect(restoredOwnership.data).toHaveLength(2)
  expect(restoredOwnership.data!.every((row) => row.removed_at === null)).toBe(
    true
  )
  expect(restoredLeagueLinks.error).toBeNull()
  expect(restoredLeagueLinks.data).toHaveLength(2)
  expect(
    restoredLeagueLinks.data!.every(
      (row) => row.roster_ownership_status === "owned"
    )
  ).toBe(true)

  await setRosterScenario("null_arrays")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()
  const nullRosters = await supabase
    .from("rosters")
    .select(
      "source_player_ids, source_starter_ids, source_reserve_ids, source_taxi_ids, source_keeper_ids"
    )
    .in("id", ownedRosterIds)
  const preservedMemberships = await supabase
    .from("roster_players")
    .select(
      "id, roster_id, source_order, starter_order, is_starter, is_reserve, is_taxi, is_keeper, last_seen_at"
    )
    .in("roster_id", ownedRosterIds)
    .is("removed_at", null)
  expect(nullRosters.error).toBeNull()
  expect(
    nullRosters.data!.every(
      (row) =>
        row.source_player_ids === null &&
        row.source_starter_ids === null &&
        row.source_reserve_ids === null &&
        row.source_taxi_ids === null &&
        row.source_keeper_ids === null
    )
  ).toBe(true)
  expect(preservedMemberships.error).toBeNull()
  expect(preservedMemberships.data).toHaveLength(15)
  for (const row of preservedMemberships.data!) {
    expect({
      sourceOrder: row.source_order,
      starterOrder: row.starter_order,
      isStarter: row.is_starter,
      isReserve: row.is_reserve,
      isTaxi: row.is_taxi,
      isKeeper: row.is_keeper,
    }).toEqual(originalMembershipState.get(row.id))
  }
  await expect(
    rosterSummaryCard(page, "Last confirmed active memberships").getByText(
      "15",
      { exact: true }
    )
  ).toBeVisible()
  const nullSourceRosterRows = page
    .getByRole("table", { name: "Owned current-season Sleeper rosters" })
    .locator("tbody tr")
  await expect(nullSourceRosterRows).toHaveCount(2)
  for (const row of await nullSourceRosterRows.all()) {
    await expect(row.getByText("Not reported", { exact: true })).toHaveCount(5)
  }
  const nullSourceHoldingRows = page
    .getByRole("table", { name: "Current holdings preview" })
    .locator("tbody tr")
  await expect(nullSourceHoldingRows).toHaveCount(15)
  for (const row of await nullSourceHoldingRows.all()) {
    await expect(row.getByText("Not reported", { exact: true })).toHaveCount(4)
  }

  await setRosterScenario("empty_arrays")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()
  await expect(
    rosterSummaryCard(page, "Last confirmed active memberships").getByText(
      "0",
      { exact: true }
    )
  ).toBeVisible()
  const emptySourceRosterRows = page
    .getByRole("table", { name: "Owned current-season Sleeper rosters" })
    .locator("tbody tr")
  await expect(emptySourceRosterRows).toHaveCount(2)
  for (const row of await emptySourceRosterRows.all()) {
    const cells = row.getByRole("cell")
    for (let index = 3; index <= 7; index += 1) {
      await expect(cells.nth(index)).toHaveText("0")
    }
  }
  await expect(
    page
      .getByRole("table", { name: "Current holdings preview" })
      .locator("tbody tr")
  ).toHaveCount(1)
  await expect(
    page.getByText(
      "No last-confirmed active memberships were resolved for confirmed-owned rosters."
    )
  ).toBeVisible()
  const emptyRosters = await supabase
    .from("rosters")
    .select(
      "id, source_player_ids, source_starter_ids, source_reserve_ids, source_taxi_ids, source_keeper_ids"
    )
    .in("id", ownedRosterIds)
  const clearedMemberships = await supabase
    .from("roster_players")
    .select("id, roster_id, last_seen_at, removed_at")
    .in("roster_id", ownedRosterIds)
  expect(emptyRosters.error).toBeNull()
  expect(emptyRosters.data).toHaveLength(2)
  expect(
    emptyRosters.data!.every(
      (row) =>
        row.source_player_ids?.length === 0 &&
        row.source_starter_ids?.length === 0 &&
        row.source_reserve_ids?.length === 0 &&
        row.source_taxi_ids?.length === 0 &&
        row.source_keeper_ids?.length === 0
    )
  ).toBe(true)
  expect(clearedMemberships.error).toBeNull()
  expect(clearedMemberships.data).toHaveLength(15)
  for (const membership of clearedMemberships.data!) {
    expect(membership.removed_at).not.toBeNull()
    expect(Date.parse(membership.removed_at!)).toBeGreaterThanOrEqual(
      Date.parse(membership.last_seen_at)
    )
  }

  await setRosterScenario("normal")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()

  await setRosterScenario("shrinking_collection")
  await importRosters(page)
  await expect(page.getByText("Roster import complete.")).toBeVisible()
  const shrunkenOwnership = await supabase
    .from("fantasy_account_rosters")
    .select("id, removed_at")
    .eq("fantasy_account_id", fantasyAccountId)
  expect(shrunkenOwnership.error).toBeNull()
  expect(shrunkenOwnership.data).toHaveLength(2)
  expect(
    shrunkenOwnership.data!.filter((row) => row.removed_at === null)
  ).toHaveLength(1)
  expect(
    shrunkenOwnership.data!.filter((row) => row.removed_at !== null)
  ).toHaveLength(1)
  const usersAfterShrink = await supabase
    .from("league_users")
    .select("id, removed_at")
    .in("league_id", leagueIds)
  const rostersAfterShrink = await supabase
    .from("rosters")
    .select("id, removed_at")
    .in("league_id", leagueIds)
  const activeAfterShrink = await supabase
    .from("roster_players")
    .select("id, removed_at")
    .in("roster_id", allRosterIds)
  expect(usersAfterShrink.error).toBeNull()
  expect(rostersAfterShrink.error).toBeNull()
  expect(activeAfterShrink.error).toBeNull()
  expect(usersAfterShrink.data).toHaveLength(4)
  expect(
    usersAfterShrink.data!.filter((row) => row.removed_at === null)
  ).toHaveLength(2)
  expect(rostersAfterShrink.data).toHaveLength(4)
  expect(
    rostersAfterShrink.data!.filter((row) => row.removed_at === null)
  ).toHaveLength(1)
  expect(activeAfterShrink.data).toHaveLength(19)
  expect(
    activeAfterShrink.data!.filter((row) => row.removed_at === null)
  ).toHaveLength(7)
  await expect(
    page.getByText("Fixture Dynasty Team", { exact: true })
  ).toHaveCount(0)

  await setRosterScenario("malformed_roster")
  await importRosters(page)
  await expect(
    page.getByText("Sleeper returned an unexpected roster response. Try again.")
  ).toBeVisible()
  const afterFailureOwnership = await supabase
    .from("fantasy_account_rosters")
    .select("id")
    .eq("fantasy_account_id", fantasyAccountId)
    .is("removed_at", null)
  const afterFailureMemberships = await supabase
    .from("roster_players")
    .select("id", { count: "exact", head: true })
    .in("roster_id", ownedRosterIds)
    .is("removed_at", null)
  const latestRun = await supabase
    .from("sync_runs")
    .select("id, status, progress_current")
    .eq("fantasy_account_id", fantasyAccountId)
    .eq("scope", "roster_sync")
    .order("started_at", { ascending: false })
    .limit(1)
    .single()
  expect(afterFailureOwnership.error).toBeNull()
  expect(afterFailureOwnership.data).toHaveLength(1)
  expect(afterFailureMemberships.error).toBeNull()
  expect(afterFailureMemberships.count).toBe(7)
  expect(latestRun.error).toBeNull()
  expect(latestRun.data!.status).toBe("failed")
  expect(latestRun.data!.progress_current).toBe(0)
  expect(await privateRosterStateIsClean(latestRun.data!.id)).toEqual({
    clean: true,
  })

  await page.getByRole("link", { name: "Leagues" }).click()
  await expect(
    page.getByText("Rosters imported. Drafts not imported.")
  ).toBeVisible()

  await page.getByRole("button", { name: "Sign out" }).click()
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await expect(page.getByRole("button", { name: "Sign out" })).toBeVisible()
  await page.goto("/rosters")
  await expect(
    page.getByRole("heading", { name: "Sleeper rosters" })
  ).toBeVisible()
  await expect(page.getByText("Fixture Alpha", { exact: true })).toBeVisible()

  const accountSync = await supabase
    .from("fantasy_accounts")
    .select("last_synced_at")
    .eq("id", fantasyAccountId)
    .single()
  expect(accountSync.error).toBeNull()
  expect(accountSync.data!.last_synced_at).toBeNull()
})
