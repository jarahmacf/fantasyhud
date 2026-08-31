import { spawnSync } from "node:child_process"
import { join } from "node:path"

import { createClient } from "@supabase/supabase-js"

const projectRoot = process.cwd()
const supabaseExecutable = join(projectRoot, "node_modules", ".bin", "supabase")
const status = spawnSync(supabaseExecutable, ["status", "-o", "json"], {
  cwd: projectRoot,
  encoding: "utf8",
  stdio: ["ignore", "pipe", "inherit"],
})

if (status.error) throw status.error
if (status.status !== 0) {
  throw new Error("Local Supabase must be running before the concurrency test.")
}

const local = JSON.parse(status.stdout)
const supabaseUrl = local.API_URL
const publishableKey = local.PUBLISHABLE_KEY ?? local.ANON_KEY
const secretKey = local.SECRET_KEY ?? local.SERVICE_ROLE_KEY

if (
  typeof supabaseUrl !== "string" ||
  typeof publishableKey !== "string" ||
  typeof secretKey !== "string"
) {
  throw new Error("Local Supabase did not report the required test values.")
}

const admin = createClient(supabaseUrl, secretKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})
const password = "league-concurrency-fixture-password"
const suffix = Date.now().toString()

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function assertSucceeded(result, label) {
  if (result.error) {
    throw new Error(`${label} failed: ${result.error.message}`)
  }
  return result.data
}

function withTimeout(promise, timeoutMs) {
  let timeout
  const deadline = new Promise((_, reject) => {
    timeout = setTimeout(
      () => reject(new Error(`Concurrent completion exceeded ${timeoutMs}ms.`)),
      timeoutMs
    )
  })

  return Promise.race([promise, deadline]).finally(() => clearTimeout(timeout))
}

async function createFixtureIdentity(label) {
  const email = `task006-concurrency-${label}-${suffix}@example.test`
  const created = assertSucceeded(
    await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: `Concurrency ${label}` },
    }),
    `create user ${label}`
  )
  assert(created.user, `User ${label} was not created.`)

  const account = assertSucceeded(
    await admin.rpc("connect_sleeper_account", {
      p_avatar_url: null,
      p_display_name: `Concurrency ${label}`,
      p_external_user_id: `concurrency-user-${label}-${suffix}`,
      p_provider_metadata: { fixture: "league-concurrency" },
      p_user_id: created.user.id,
      p_username: `Concurrency${label}${suffix}`,
    }),
    `connect account ${label}`
  )?.[0]
  assert(account, `Account ${label} was not connected.`)

  const client = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const signedIn = await client.auth.signInWithPassword({ email, password })
  assertSucceeded(signedIn, `sign in ${label}`)

  return {
    accountId: account.fantasy_account_id,
    client,
    userId: created.user.id,
  }
}

function state(fetchedAt, week, freshness) {
  return {
    season: 2026,
    league_season: 2026,
    league_create_season: 2027,
    previous_season: 2025,
    season_type: "regular",
    week,
    leg: week,
    display_week: week,
    season_start_date: "2026-09-10",
    provider_metadata: { freshness },
    fetched_at: fetchedAt,
  }
}

function league(externalLeagueId, fetchedAt, freshness) {
  return {
    external_league_id: externalLeagueId,
    sport: "nfl",
    season: 2026,
    name: `${freshness} ${externalLeagueId}`,
    status: freshness === "newer" ? "in_season" : "pre_draft",
    season_type: "regular",
    team_count: 12,
    roster_size: 2,
    roster_management_type: "redraft",
    is_best_ball: false,
    has_superflex: false,
    has_idp: false,
    scoring_format: "ppr",
    avatar_id: null,
    avatar_url: null,
    previous_external_league_id: null,
    settings: { type: 0, freshness },
    scoring_settings: { rec: 1 },
    roster_positions: ["QB", "BN"],
    provider_metadata: { freshness },
    provider_updated_at:
      freshness === "newer" ? "2099-01-02T00:00:00.000Z" : null,
    fetched_at: fetchedAt,
  }
}

const [identityA, identityB] = await Promise.all([
  createFixtureIdentity("A"),
  createFixtureIdentity("B"),
])

async function start(identity, label) {
  const rows = assertSucceeded(
    await admin.rpc("start_sleeper_league_discovery", {
      p_fantasy_account_id: identity.accountId,
      p_user_id: identity.userId,
    }),
    `start discovery ${label}`
  )
  const run = rows?.[0]
  assert(run?.created_run, `Discovery ${label} did not create a run.`)
  return run.sync_run_id
}

const [runA, runB] = await Promise.all([
  start(identityA, "A"),
  start(identityB, "B"),
])

const ids = ["concurrency-league-a", "concurrency-league-b"]
const newerFetchedAt = "2099-01-02T00:00:01.000Z"
const olderFetchedAt = "2099-01-01T00:00:01.000Z"
const newerCollection = ids.map((id) => league(id, newerFetchedAt, "newer"))
const olderCollection = [...ids]
  .reverse()
  .map((id) => league(id, olderFetchedAt, "older"))

const completionResults = await withTimeout(
  Promise.all([
    admin.rpc("complete_sleeper_league_discovery", {
      p_fantasy_account_id: identityA.accountId,
      p_leagues: newerCollection,
      p_state: state("2099-01-02T00:00:00.000Z", 9, "newer"),
      p_sync_run_id: runA,
      p_user_id: identityA.userId,
    }),
    admin.rpc("complete_sleeper_league_discovery", {
      p_fantasy_account_id: identityB.accountId,
      p_leagues: olderCollection,
      p_state: state("2099-01-01T00:00:00.000Z", 8, "older"),
      p_sync_run_id: runB,
      p_user_id: identityB.userId,
    }),
  ]),
  15_000
)

const completionA = assertSucceeded(
  completionResults[0],
  "complete discovery A"
)?.[0]
const completionB = assertSucceeded(
  completionResults[1],
  "complete discovery B"
)?.[0]
assert(completionA, "Discovery A returned no completion result.")
assert(completionB, "Discovery B returned no completion result.")
assert(
  completionA.observed_leagues === 2 &&
    completionA.active_associations === 2 &&
    completionB.observed_leagues === 2 &&
    completionB.active_associations === 2,
  "A concurrent completion returned incorrect observed or active counts."
)

async function readReachableRows(identity, label) {
  const rows = assertSucceeded(
    await identity.client
      .from("fantasy_account_leagues")
      .select(
        "league_id, removed_at, leagues!inner(id, external_league_id, name, fetched_at, provider_updated_at, settings, provider_metadata)"
      )
      .eq("fantasy_account_id", identity.accountId)
      .is("removed_at", null)
      .in("leagues.external_league_id", ids),
    `read associations ${label}`
  )
  assert(
    rows.length === 2,
    `Account ${label} did not receive two associations.`
  )
  return [...rows].sort((left, right) =>
    left.leagues.external_league_id.localeCompare(
      right.leagues.external_league_id
    )
  )
}

const [rowsA, rowsB] = await Promise.all([
  readReachableRows(identityA, "A"),
  readReachableRows(identityB, "B"),
])

assert(
  rowsA.every((row, index) => row.league_id === rowsB[index]?.league_id),
  "The two accounts did not resolve the same canonical league IDs."
)
assert(
  rowsA.every(
    (row) =>
      row.leagues.name.startsWith("newer ") &&
      Date.parse(row.leagues.fetched_at) === Date.parse(newerFetchedAt) &&
      Date.parse(row.leagues.provider_updated_at) ===
        Date.parse("2099-01-02T00:00:00.000Z") &&
      row.leagues.settings.freshness === "newer" &&
      row.leagues.provider_metadata.freshness === "newer"
  ),
  "An older completion regressed a shared league representation."
)

const providerState = assertSucceeded(
  await identityA.client
    .from("provider_season_states")
    .select("fetched_at, league_season, provider_metadata, week")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .single(),
  "read provider state"
)
assert(
  providerState.league_season === 2026 &&
    providerState.week === 9 &&
    Date.parse(providerState.fetched_at) ===
      Date.parse("2099-01-02T00:00:00.000Z") &&
    providerState.provider_metadata.freshness === "newer",
  "An older completion regressed shared provider state."
)

async function readRun(identity, runId, label) {
  const run = assertSucceeded(
    await identity.client
      .from("sync_runs")
      .select("status")
      .eq("id", runId)
      .single(),
    `read sync run ${label}`
  )
  assert(run.status === "succeeded", `Sync run ${label} did not succeed.`)
}

await Promise.all([
  readRun(identityA, runA, "A"),
  readRun(identityB, runB, "B"),
])

console.log(
  "League discovery concurrency test passed: 2 accounts, 2 canonical leagues, 2 succeeded runs."
)
