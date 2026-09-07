import { spawn, spawnSync } from "node:child_process"
import { once } from "node:events"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const root = process.cwd()
const cli = join(root, "node_modules", ".bin", "supabase")
function localCommand(args) {
  const result = spawnSync(cli, args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  })
  if (result.error || result.status !== 0) {
    throw new Error(`Local database command failed: ${result.stderr}`)
  }
  return result.stdout
}
const local = JSON.parse(localCommand(["status", "-o", "json"]))
const url = new URL(local.API_URL)
if (
  url.protocol !== "http:" ||
  !["localhost", "127.0.0.1"].includes(url.hostname)
) {
  throw new Error("Temporary-access tests require isolated local Supabase.")
}
const testSql = readFileSync(
  join(root, "supabase/tests/database/012_temporary_workspace_access.test.sql"),
  "utf8"
)
const fixture = testSql
  .split("-- BEGIN TEMPORARY ACCESS FIXTURE\n")[1]
  ?.split("-- END TEMPORARY ACCESS FIXTURE")[0]
if (!fixture) throw new Error("The tested workspace fixture is missing.")
const directory = mkdtempSync(join(tmpdir(), "fantasyhud-access-"))
const file = join(directory, "fixture.sql")
try {
  writeFileSync(file, fixture)
  localCommand(["db", "query", "--local", "--file", file])
  const child = spawn(
    join(root, "node_modules", ".bin", "playwright"),
    ["test", "--config", "playwright.temporary-access.config.ts"],
    {
      cwd: root,
      env: {
        ...process.env,
        NEXT_PUBLIC_SUPABASE_URL: local.API_URL,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
          local.PUBLISHABLE_KEY ?? local.ANON_KEY,
        NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:3102",
        FANTASYHUD_TEMPORARY_ACCESS: "on",
        SUPABASE_SECRET_KEY: "",
      },
      stdio: "inherit",
    }
  )
  const [code] = await once(child, "exit")
  process.exitCode = typeof code === "number" ? code : 1
} finally {
  localCommand([
    "db",
    "query",
    "--local",
    "update app_private.temporary_workspace_access set enabled=false;",
  ])
  rmSync(directory, { recursive: true, force: true })
}
