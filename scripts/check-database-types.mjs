import { spawnSync } from "node:child_process"
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { format, resolveConfig } from "prettier"

const projectRoot = process.cwd()
const committedPath = join(
  projectRoot,
  "src",
  "lib",
  "supabase",
  "database.types.ts"
)
const temporaryDirectory = await mkdtemp(
  join(tmpdir(), "fantasyhud-database-types-check-")
)

function runTypeGenerator() {
  const executable = join(
    projectRoot,
    "node_modules",
    ".bin",
    process.platform === "win32" ? "supabase.cmd" : "supabase"
  )
  const result = spawnSync(
    executable,
    ["gen", "types", "typescript", "--local", "--schema", "public"],
    {
      cwd: projectRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "inherit"],
    }
  )

  if (result.error) {
    throw result.error
  }

  if (result.status !== 0) {
    if (result.stdout) {
      process.stderr.write(result.stdout)
    }
    process.exitCode = result.status ?? 1
    throw new Error("Supabase type generation failed.")
  }

  return `${result.stdout.replace(/\r\n/g, "\n").trimEnd()}\n`
}

try {
  const temporaryPath = join(temporaryDirectory, "database.types.ts")
  const prettierOptions = (await resolveConfig(committedPath)) ?? {}
  const generatedTypes = await format(runTypeGenerator(), {
    ...prettierOptions,
    filepath: committedPath,
  })
  await writeFile(temporaryPath, generatedTypes, "utf8")

  let committedTypes
  try {
    committedTypes = await readFile(committedPath, "utf8")
  } catch {
    console.error(
      "Generated database types are missing. Run `npm run db:types` with local Supabase running."
    )
    process.exitCode = 1
    committedTypes = null
  }

  if (
    committedTypes !== null &&
    committedTypes.replace(/\r\n/g, "\n") !== generatedTypes
  ) {
    console.error(
      "Generated database types are stale. Run `npm run db:types` and commit the result."
    )
    console.error("\nGenerated output:\n")
    console.error(generatedTypes)
    process.exitCode = 1
  } else if (committedTypes !== null) {
    console.log("Generated database types are current.")
  }
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true })
}
