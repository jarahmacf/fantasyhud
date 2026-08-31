import { spawnSync } from "node:child_process"
import { copyFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { format, resolveConfig } from "prettier"

const projectRoot = process.cwd()
const outputPath = join(
  projectRoot,
  "src",
  "lib",
  "supabase",
  "database.types.ts"
)
const temporaryDirectory = await mkdtemp(
  join(tmpdir(), "fantasyhud-database-types-")
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

  const generatedTypes = result.stdout.replace(/\r\n/g, "\n").trimEnd()
  if (generatedTypes.length === 0) {
    throw new Error("Supabase type generation produced no output.")
  }

  return `${generatedTypes}\n`
}

try {
  const temporaryPath = join(temporaryDirectory, "database.types.ts")
  const prettierOptions = (await resolveConfig(outputPath)) ?? {}
  const generatedTypes = await format(runTypeGenerator(), {
    ...prettierOptions,
    filepath: outputPath,
  })
  await writeFile(temporaryPath, generatedTypes, "utf8")
  await mkdir(dirname(outputPath), { recursive: true })
  await copyFile(temporaryPath, outputPath)
  console.log(`Generated ${outputPath}`)
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true })
}
