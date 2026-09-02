import { spawn, spawnSync } from "node:child_process"
import { once } from "node:events"
import { readFileSync } from "node:fs"
import { createServer } from "node:http"
import { join } from "node:path"

const projectRoot = process.cwd()
const supabaseExecutable = join(projectRoot, "node_modules", ".bin", "supabase")
const playwrightExecutable = join(
  projectRoot,
  "node_modules",
  ".bin",
  "playwright"
)

const status = spawnSync(supabaseExecutable, ["status", "-o", "json"], {
  cwd: projectRoot,
  encoding: "utf8",
  stdio: ["ignore", "pipe", "inherit"],
})

if (status.error) {
  throw status.error
}
if (status.status !== 0) {
  throw new Error("Local Supabase must be running before auth browser tests.")
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

const fixturesDirectory = join(projectRoot, "src", "lib", "sleeper", "fixtures")
const readFixture = (name) =>
  JSON.parse(readFileSync(join(fixturesDirectory, name), "utf8"))
const nflState = readFixture("nfl-state.json")
const normalLeagues = readFixture("league-collection-normal.json")
const emptyLeagues = readFixture("league-collection-empty.json")
const malformedLeagues = readFixture("league-collection-malformed.json")

const userFixtures = new Map([
  [
    "fixture-user",
    {
      user_id: "fixture-canonical-normal",
      username: "CanonicalFixtureUser",
      display_name: "Fixture Sleeper User",
      avatar: "fixture-avatar",
    },
  ],
  [
    "fixture-user-isolated",
    {
      user_id: "fixture-canonical-isolated",
      username: "CanonicalFixtureUser",
      display_name: "Fixture Sleeper User",
      avatar: "fixture-avatar",
    },
  ],
  [
    "empty-user",
    {
      user_id: "fixture-canonical-empty",
      username: "EmptyFixtureUser",
      display_name: "Empty Fixture User",
      avatar: null,
    },
  ],
  [
    "malformed-user",
    {
      user_id: "fixture-canonical-malformed",
      username: "MalformedFixtureUser",
      display_name: "Malformed Fixture User",
      avatar: null,
    },
  ],
  [
    "transient-league-user",
    {
      user_id: "fixture-canonical-transient",
      username: "TransientFixtureUser",
      display_name: "Transient Fixture User",
      avatar: null,
    },
  ],
  [
    "shrinking-user",
    {
      user_id: "fixture-canonical-shrinking",
      username: "ShrinkingFixtureUser",
      display_name: "Shrinking Fixture User",
      avatar: null,
    },
  ],
  [
    "running-user",
    {
      user_id: "fixture-canonical-running",
      username: "RunningFixtureUser",
      display_name: "Running Fixture User",
      avatar: null,
    },
  ],
])

let temporaryErrorAttempts = 0
let shrinkingCollectionRequests = 0
let malformedCollectionRequests = 0
let playerCatalogRequests = 0
let rosterScenario = "normal"
let rosterUserRequests = 0
let rosterRosterRequests = 0
const transientRosterAttempts = new Map()

const rosterScenarios = new Set([
  "normal",
  "same_collection",
  "shrinking_collection",
  "null_arrays",
  "empty_arrays",
  "co_owned",
  "unmatched",
  "unresolved_coowners",
  "unknown_player",
  "removed_player_mapping",
  "malformed_user",
  "malformed_roster",
  "transient_error",
])

function createPlayerCatalog() {
  const catalog = {}
  for (let index = 0; index < 600; index += 1) {
    const playerId = `catalog-${index.toString().padStart(4, "0")}`
    catalog[playerId] = {
      player_id: playerId,
      sport: "nfl",
      full_name: `Fixture Catalog Player ${index.toString().padStart(4, "0")}`,
      position: "WR",
      fantasy_positions: ["WR"],
      team: "SEA",
      active: index <= 6,
      status: index <= 6 ? "Active" : "Inactive",
      number: index % 99,
      age: 25,
      years_exp: 3,
      search_rank: index,
    }
  }

  catalog["catalog-0000"] = {
    ...catalog["catalog-0000"],
    first_name: "  Aaron  ",
    last_name: "Fixture",
    full_name: "  Aaron Fixture  ",
    espn_id: 100,
  }
  catalog["catalog-0001"] = {
    ...catalog["catalog-0001"],
    full_name: "Arizona Fixture Defense",
    position: "DEF",
    fantasy_positions: ["DEF"],
    team: "ARI",
    yahoo_id: "defense-yahoo-id",
  }
  catalog["catalog-0002"] = {
    ...catalog["catalog-0002"],
    full_name: "Dual Position Fixture",
    position: "WR",
    fantasy_positions: ["WR", "RB", "WR"],
    stats_id: "dual-stats-id",
  }
  catalog["catalog-0003"] = {
    ...catalog["catalog-0003"],
    full_name: "Injured Fixture",
    position: "TE",
    fantasy_positions: ["TE"],
    injury_status: "Out",
    injury_body_part: "Knee",
    injury_start_date: "2026-08-30",
  }
  catalog["catalog-0004"] = {
    player_id: "catalog-0004",
    sport: "nfl",
    active: true,
    status: null,
  }
  catalog["catalog-0005"] = {
    ...catalog["catalog-0005"],
    full_name: "Warning Fixture",
    active: "true",
    age: 900,
    news_updated: "not-an-epoch",
  }

  return catalog
}

const playerCatalog = createPlayerCatalog()

function leagueUsers(leagueId) {
  const users =
    leagueId === "fixture-league-best-ball"
      ? [
          {
            user_id: "fixture-canonical-normal",
            username: "CanonicalFixtureUser",
            display_name: "  Fixture Owner  ",
            avatar: "fixture-owner-avatar",
            league_id: leagueId,
            metadata: { team_name: "  Fixture Alpha  ", fixture: true },
            is_owner: true,
          },
          {
            user_id: "fixture-best-ball-member",
            username: "FixtureBestBallMember",
            display_name: "Fixture Best Ball Member",
            avatar: null,
            league_id: leagueId,
            metadata: null,
            is_owner: null,
          },
        ]
      : [
          {
            user_id: "fixture-dynasty-owner",
            username: "FixtureDynastyOwner",
            display_name: "Fixture Dynasty Owner",
            avatar: null,
            league_id: leagueId,
            metadata: { team_name: "Fixture Dynasty Team" },
            is_owner: true,
          },
          {
            user_id: "fixture-canonical-normal",
            username: "CanonicalFixtureUser",
            display_name: "Fixture Co-owner",
            avatar: "fixture-owner-avatar",
            league_id: leagueId,
            metadata: {},
            is_owner: null,
          },
        ]

  if (rosterScenario === "malformed_user" && leagueId.endsWith("dynasty")) {
    return [...users, { display_name: "Missing exact identity" }]
  }

  if (rosterScenario === "shrinking_collection") {
    return users.slice(0, 1)
  }

  return users
}

function normalRosters(leagueId) {
  if (leagueId === "fixture-league-best-ball") {
    return [
      {
        roster_id: 1,
        league_id: leagueId,
        owner_id: "fixture-canonical-normal",
        co_owners: null,
        players: [
          "catalog-0000",
          "catalog-0001",
          "catalog-0002",
          "catalog-0003",
          "catalog-0004",
          "catalog-0005",
          "catalog-0006",
          "catalog-0007",
          "roster-unknown-0001",
        ],
        starters: [
          "catalog-0000",
          "catalog-0001",
          "catalog-0002",
          "catalog-0003",
          "catalog-0004",
          "0",
          "0",
        ],
        reserve: ["catalog-0007"],
        taxi: null,
        keepers: ["catalog-0000"],
        settings: { wins: 4, losses: 1, ties: 0, fpts: 512 },
        metadata: { fixture: "best-ball-owner" },
      },
      {
        roster_id: 2,
        league_id: leagueId,
        owner_id: "fixture-best-ball-member",
        co_owners: null,
        players: ["catalog-0020", "catalog-0021"],
        starters: ["catalog-0020", "0", "0", "0", "0", "0", "0"],
        reserve: [],
        taxi: null,
        keepers: null,
        settings: { wins: 2, losses: 3, ties: 0 },
        metadata: null,
      },
    ]
  }

  return [
    {
      roster_id: 1,
      league_id: leagueId,
      owner_id: "fixture-dynasty-owner",
      co_owners: ["fixture-canonical-normal"],
      players: [
        "catalog-0008",
        "catalog-0009",
        "catalog-0010",
        "catalog-0011",
        "catalog-0012",
        "catalog-0013",
      ],
      starters: [
        "catalog-0008",
        "catalog-0009",
        "catalog-0010",
        "catalog-0011",
        "catalog-0012",
      ],
      reserve: [],
      taxi: ["catalog-0013"],
      keepers: [],
      settings: { wins: 5, losses: 0, ties: 0, fpts: 620 },
      metadata: { fixture: "dynasty-co-owner" },
    },
    {
      roster_id: 2,
      league_id: leagueId,
      owner_id: "fixture-dynasty-member",
      co_owners: null,
      players: ["catalog-0030", "catalog-0031"],
      starters: ["catalog-0030", "0", "0", "0", "0"],
      reserve: null,
      taxi: null,
      keepers: null,
      settings: { wins: 1, losses: 4, ties: 0 },
      metadata: null,
    },
  ]
}

function leagueRosters(leagueId) {
  const rosters = normalRosters(leagueId).map((roster) => ({ ...roster }))

  if (rosterScenario === "malformed_roster" && leagueId.endsWith("dynasty")) {
    return [...rosters, { roster_id: 3, league_id: leagueId, settings: null }]
  }

  if (rosterScenario === "shrinking_collection") {
    if (leagueId.endsWith("dynasty")) return []
    return [
      {
        ...rosters[0],
        players: rosters[0].players.slice(0, -2),
        reserve: [],
      },
    ]
  }

  if (rosterScenario === "null_arrays") {
    return rosters.map((roster) => ({
      ...roster,
      players: null,
      starters: null,
      reserve: null,
      taxi: null,
      keepers: null,
    }))
  }

  if (rosterScenario === "empty_arrays") {
    return rosters.map((roster) => ({
      ...roster,
      players: [],
      starters: [],
      reserve: [],
      taxi: [],
      keepers: [],
    }))
  }

  if (rosterScenario === "co_owned") {
    return rosters.map((roster, index) => ({
      ...roster,
      owner_id: `fixture-untracked-owner-${index + 1}`,
      co_owners: index === 0 ? ["fixture-canonical-normal"] : [],
    }))
  }

  if (rosterScenario === "unmatched") {
    return rosters.map((roster, index) => ({
      ...roster,
      owner_id: `fixture-untracked-owner-${index + 1}`,
      co_owners: [],
    }))
  }

  if (rosterScenario === "unresolved_coowners") {
    return rosters.map((roster, index) => ({
      ...roster,
      owner_id: `fixture-untracked-owner-${index + 1}`,
      co_owners: null,
    }))
  }

  if (rosterScenario === "unknown_player") {
    return rosters.map((roster, index) =>
      index === 0
        ? {
            ...roster,
            players: [...roster.players, "roster-unknown-0002"],
          }
        : roster
    )
  }

  if (rosterScenario === "removed_player_mapping") {
    return rosters.map((roster, index) =>
      index === 0
        ? {
            ...roster,
            players: [...roster.players, "roster-historical-0001"],
          }
        : roster
    )
  }

  return rosters
}

const mockSleeperServer = createServer((request, response) => {
  const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1")
  const segments = requestUrl.pathname.split("/").filter(Boolean)

  if (
    request.method === "GET" &&
    requestUrl.pathname === "/__test/player-request-count"
  ) {
    response.setHeader("content-type", "application/json")
    response.end(JSON.stringify({ count: playerCatalogRequests }))
    return
  }

  if (
    request.method === "GET" &&
    requestUrl.pathname === "/__test/roster-request-count"
  ) {
    response.setHeader("content-type", "application/json")
    response.end(
      JSON.stringify({
        users: rosterUserRequests,
        rosters: rosterRosterRequests,
        total: rosterUserRequests + rosterRosterRequests,
      })
    )
    return
  }

  if (
    request.method === "GET" &&
    requestUrl.pathname === "/__test/roster-scenario"
  ) {
    const nextScenario = requestUrl.searchParams.get("name")
    if (!nextScenario || !rosterScenarios.has(nextScenario)) {
      response.writeHead(400).end()
      return
    }
    rosterScenario = nextScenario
    transientRosterAttempts.clear()
    response.setHeader("content-type", "application/json")
    response.end(JSON.stringify({ scenario: rosterScenario }))
    return
  }

  if (
    request.method === "GET" &&
    requestUrl.pathname === "/__test/private-roster-state"
  ) {
    const runId = requestUrl.searchParams.get("run_id")
    if (
      !runId ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(
        runId
      )
    ) {
      response.writeHead(400).end()
      return
    }

    const privateDump = spawnSync(
      supabaseExecutable,
      ["db", "dump", "--local", "--data-only", "--schema", "app_private"],
      {
        cwd: projectRoot,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      }
    )
    if (privateDump.error || privateDump.status !== 0) {
      response.writeHead(500).end()
      return
    }

    response.setHeader("content-type", "application/json")
    response.end(JSON.stringify({ clean: !privateDump.stdout.includes(runId) }))
    return
  }

  if (request.method !== "GET" || segments[0] !== "v1") {
    response.writeHead(404).end()
    return
  }

  response.setHeader("content-type", "application/json")

  if (
    segments.length === 3 &&
    segments[1] === "state" &&
    segments[2] === "nfl"
  ) {
    response.end(JSON.stringify(nflState))
    return
  }

  if (
    segments.length === 4 &&
    segments[1] === "league" &&
    (segments[3] === "users" || segments[3] === "rosters")
  ) {
    const leagueId = decodeURIComponent(segments[2])
    if (
      leagueId !== "fixture-league-best-ball" &&
      leagueId !== "fixture-league-dynasty"
    ) {
      response.writeHead(404).end("null")
      return
    }

    if (segments[3] === "users") rosterUserRequests += 1
    else rosterRosterRequests += 1

    if (rosterScenario === "transient_error") {
      const attemptKey = `${leagueId}:${segments[3]}`
      const attempts = transientRosterAttempts.get(attemptKey) ?? 0
      transientRosterAttempts.set(attemptKey, attempts + 1)
      if (attempts === 0) {
        response.writeHead(503).end(JSON.stringify({ error: "temporary" }))
        return
      }
    }

    response.end(
      JSON.stringify(
        segments[3] === "users"
          ? leagueUsers(leagueId)
          : leagueRosters(leagueId)
      )
    )
    return
  }

  if (
    segments.length === 3 &&
    segments[1] === "players" &&
    segments[2] === "nfl"
  ) {
    playerCatalogRequests += 1
    response.end(JSON.stringify(playerCatalog))
    return
  }

  if (segments[1] === "user" && segments.length === 3) {
    const username = decodeURIComponent(segments[2])
    const user = userFixtures.get(username)
    if (user) {
      response.end(JSON.stringify(user))
      return
    }

    if (username === "missing-user") {
      response.writeHead(404).end("null")
      return
    }

    if (username === "bad-shape") {
      response.end(JSON.stringify({ username: "missing-canonical-id" }))
      return
    }

    if (username === "temporary-error") {
      temporaryErrorAttempts += 1
      if (temporaryErrorAttempts === 1) {
        response.writeHead(503).end(JSON.stringify({ error: "temporary" }))
        return
      }
      response.end(
        JSON.stringify({
          user_id: "temporary-user-id",
          username: "RecoveredFixtureUser",
          display_name: null,
          avatar: null,
        })
      )
      return
    }
  }

  if (
    segments.length === 6 &&
    segments[1] === "user" &&
    segments[3] === "leagues" &&
    segments[4] === "nfl" &&
    segments[5] === "2026"
  ) {
    const canonicalUserId = decodeURIComponent(segments[2])
    if (canonicalUserId === "fixture-canonical-normal") {
      response.end(JSON.stringify(normalLeagues))
      return
    }
    if (canonicalUserId === "fixture-canonical-empty") {
      response.end(JSON.stringify(emptyLeagues))
      return
    }
    if (canonicalUserId === "fixture-canonical-malformed") {
      malformedCollectionRequests += 1
      response.end(
        JSON.stringify(
          malformedCollectionRequests === 1 ? normalLeagues : malformedLeagues
        )
      )
      return
    }
    if (canonicalUserId === "fixture-canonical-transient") {
      response.writeHead(503).end(JSON.stringify({ error: "temporary" }))
      return
    }
    if (canonicalUserId === "fixture-canonical-shrinking") {
      shrinkingCollectionRequests += 1
      response.end(
        JSON.stringify(
          shrinkingCollectionRequests <= 2
            ? normalLeagues
            : normalLeagues.slice(0, 1)
        )
      )
      return
    }
    if (canonicalUserId === "fixture-canonical-running") {
      setTimeout(() => response.end(JSON.stringify(normalLeagues)), 250)
      return
    }
  }

  response.writeHead(404).end("null")
})

mockSleeperServer.listen(0, "127.0.0.1")
await once(mockSleeperServer, "listening")

const address = mockSleeperServer.address()
if (!address || typeof address === "string") {
  mockSleeperServer.close()
  throw new Error("The local Sleeper test server did not start.")
}

const playwright = spawn(
  playwrightExecutable,
  ["test", "--config", "playwright.auth.config.ts", ...process.argv.slice(2)],
  {
    cwd: projectRoot,
    env: {
      ...process.env,
      NEXT_PUBLIC_SUPABASE_URL: supabaseUrl,
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publishableKey,
      NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:3101",
      SUPABASE_SECRET_KEY: secretKey,
      SLEEPER_API_BASE_URL: `http://127.0.0.1:${address.port}/v1`,
      SLEEPER_MOCK_CONTROL_URL: `http://127.0.0.1:${address.port}/__test`,
      SLEEPER_LOCAL_TEST_MODE: "1",
    },
    stdio: "inherit",
  }
)

const [exitCode, signal] = await once(playwright, "exit")
await new Promise((resolve, reject) => {
  mockSleeperServer.close((error) => {
    if (error) reject(error)
    else resolve()
  })
})

if (signal) {
  process.kill(process.pid, signal)
} else {
  process.exitCode = typeof exitCode === "number" ? exitCode : 1
}
