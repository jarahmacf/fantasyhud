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
const mockSleeperServer = createServer((request, response) => {
  const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1")
  const segments = requestUrl.pathname.split("/").filter(Boolean)

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
