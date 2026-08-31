import { spawn, spawnSync } from "node:child_process"
import { once } from "node:events"
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

let temporaryErrorAttempts = 0
const mockSleeperServer = createServer((request, response) => {
  const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1")
  const prefix = "/v1/user/"

  if (request.method !== "GET" || !requestUrl.pathname.startsWith(prefix)) {
    response.writeHead(404).end()
    return
  }

  const username = decodeURIComponent(requestUrl.pathname.slice(prefix.length))
  response.setHeader("content-type", "application/json")

  if (username === "fixture-user") {
    response.end(
      JSON.stringify({
        user_id: "900719925474099312345",
        username: "CanonicalFixtureUser",
        display_name: "Fixture Sleeper User",
        avatar: "fixture-avatar",
      })
    )
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
