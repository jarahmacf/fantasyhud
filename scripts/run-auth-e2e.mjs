import { spawnSync } from "node:child_process"
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

if (typeof supabaseUrl !== "string" || typeof publishableKey !== "string") {
  throw new Error("Local Supabase did not report the required public values.")
}

const result = spawnSync(
  playwrightExecutable,
  ["test", "--config", "playwright.auth.config.ts", ...process.argv.slice(2)],
  {
    cwd: projectRoot,
    env: {
      ...process.env,
      NEXT_PUBLIC_SUPABASE_URL: supabaseUrl,
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publishableKey,
      NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:3101",
    },
    stdio: "inherit",
  }
)

if (result.error) {
  throw result.error
}
process.exitCode = result.status ?? 1
