import { spawnSync } from "node:child_process"
import { join } from "node:path"

import { createClient } from "@supabase/supabase-js"

const projectRoot = process.cwd()
const supabaseExecutable = join(projectRoot, "node_modules", ".bin", "supabase")
const overallTimeoutMs = 120_000
const recordCount = 5_000
const batchSize = 500
const responseHeadroomBytes = 25_000_000
const stagedSourceEnvelopeBytes = 20_000_000

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function assertSucceeded(result, label) {
  if (result.error) throw new Error(`${label} failed: ${result.error.message}`)
  return result.data
}

function withTimeout(promise, timeoutMs) {
  let timeout
  const deadline = new Promise((_, reject) => {
    timeout = setTimeout(
      () =>
        reject(new Error(`Player catalog load test exceeded ${timeoutMs}ms.`)),
      timeoutMs
    )
  })
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timeout))
}

function normalizedRecord(index, sourceFetchedAt) {
  const externalPlayerId = `load-${index.toString().padStart(5, "0")}`
  const isDefense = index % 100 === 0
  return {
    external_player_id: externalPlayerId,
    profile: {
      sport: "nfl",
      entity_type: isDefense ? "team_defense" : "player",
      display_name: isDefense
        ? `Load Defense ${index}`
        : `Load Player ${index}`,
      first_name: isDefense ? null : "Load",
      last_name: isDefense ? null : `Player ${index}`,
      full_name: isDefense ? `Load Defense ${index}` : `Load Player ${index}`,
      primary_position: isDefense ? "DEF" : "WR",
      fantasy_positions: isDefense ? ["DEF"] : ["WR"],
      nfl_team: isDefense ? "SEA" : null,
      active: index < 4_500,
      status: index < 4_500 ? "Active" : "Inactive",
      jersey_number: isDefense ? null : index % 99,
      age: isDefense ? null : 25,
      height: isDefense ? null : "6-1",
      weight: isDefense ? null : "205",
      years_experience: isDefense ? null : 3,
      college: null,
      high_school: null,
      birth_country: null,
      depth_chart_position: null,
      depth_chart_order: null,
      injury_status: null,
      injury_body_part: null,
      injury_start_date: null,
      practice_participation: null,
      news_updated_at: null,
      search_rank: index,
      profile_source: "sleeper",
      source_metadata: {
        unmodeled_fields: {},
        normalization_warning_fields: [],
      },
      profile_fetched_at: sourceFetchedAt,
    },
    external_ids: [],
    normalization_warning_count: 0,
  }
}

async function readAllActivePrimaryMappings(client) {
  const pageSize = 1_000
  const mappings = []

  for (let from = 0; ; from += pageSize) {
    const page = assertSucceeded(
      await client
        .from("player_external_ids")
        .select("namespace, sport, external_id, player_id")
        .eq("namespace", "sleeper")
        .eq("sport", "nfl")
        .eq("is_primary", true)
        .is("removed_at", null)
        .order("external_id")
        .range(from, from + pageSize - 1),
      `read load primary ID page ${from / pageSize}`
    )

    mappings.push(...page)
    if (page.length < pageSize) return mappings
  }
}

async function run() {
  const startedAt = Date.now()
  const status = spawnSync(supabaseExecutable, ["status", "-o", "json"], {
    cwd: projectRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  })
  if (status.error) throw status.error
  if (status.status !== 0) {
    throw new Error(
      "Local Supabase must be running before the player load test."
    )
  }

  const local = JSON.parse(status.stdout)
  const supabaseUrl = local.API_URL
  const publishableKey = local.PUBLISHABLE_KEY ?? local.ANON_KEY
  const secretKey = local.SECRET_KEY ?? local.SERVICE_ROLE_KEY
  assert(
    typeof supabaseUrl === "string" &&
      typeof publishableKey === "string" &&
      typeof secretKey === "string",
    "Local Supabase did not report the required test values."
  )

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const password = "player-catalog-load-fixture-password"
  const suffix = Date.now().toString()

  async function createIdentity(label) {
    const created = assertSucceeded(
      await admin.auth.admin.createUser({
        email: `task007a-load-${label}-${suffix}@example.test`,
        password,
        email_confirm: true,
      }),
      `create load identity ${label}`
    )
    assert(created.user, `Load identity ${label} was not created.`)
    const connected = assertSucceeded(
      await admin.rpc("connect_sleeper_account", {
        p_avatar_url: null,
        p_display_name: `Load ${label}`,
        p_external_user_id: `load-user-${label}-${suffix}`,
        p_provider_metadata: { fixture: "player-catalog-load" },
        p_user_id: created.user.id,
        p_username: `Load${label}${suffix}`,
      }),
      `connect load identity ${label}`
    )?.[0]
    assert(connected, `Load identity ${label} was not connected.`)

    const client = createClient(supabaseUrl, publishableKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    assertSucceeded(
      await client.auth.signInWithPassword({
        email: created.user.email,
        password,
      }),
      `sign in load identity ${label}`
    )
    return { client, userId: created.user.id }
  }

  const identityA = await createIdentity("a")
  const start = assertSucceeded(
    await admin.rpc("start_sleeper_player_catalog_sync", {
      p_user_id: identityA.userId,
    }),
    "start player catalog load"
  )?.[0]
  assert(
    start?.created_run,
    "The load test did not create a global catalog run."
  )

  const sourceFetchedAt = new Date().toISOString()
  const records = Array.from({ length: recordCount }, (_, index) =>
    normalizedRecord(index, sourceFetchedAt)
  )
  const generatedPayloadBytes = new TextEncoder().encode(
    JSON.stringify(records)
  ).byteLength
  assert(
    generatedPayloadBytes < stagedSourceEnvelopeBytes,
    "The generated fixture must remain smaller than its staged test envelope."
  )
  assert(
    stagedSourceEnvelopeBytes > 15_000_000 &&
      stagedSourceEnvelopeBytes < responseHeadroomBytes,
    "The staged source envelope must exercise the new response-size headroom."
  )

  for (let offset = 0; offset < records.length; offset += batchSize) {
    const staged = assertSucceeded(
      await admin.rpc("stage_sleeper_player_catalog_batch", {
        p_user_id: identityA.userId,
        p_catalog_run_id: start.catalog_run_id,
        p_batch_index: Math.floor(offset / batchSize),
        p_expected_total: recordCount,
        p_source_fetched_at: sourceFetchedAt,
        p_source_bytes: stagedSourceEnvelopeBytes,
        p_records: records.slice(offset, offset + batchSize),
      }),
      `stage player batch ${offset / batchSize}`
    )?.[0]
    assert(staged, "A load-test batch returned no result.")
    assert(
      staged.total_staged_records === Math.min(offset + batchSize, recordCount),
      "Staged load-test progress was not exact."
    )
  }

  const completed = assertSucceeded(
    await admin.rpc("complete_sleeper_player_catalog_sync", {
      p_user_id: identityA.userId,
      p_catalog_run_id: start.catalog_run_id,
    }),
    "complete player catalog load"
  )?.[0]
  assert(completed, "The load test returned no completion result.")
  assert(
    completed.observed_records === recordCount,
    "Observed count was wrong."
  )
  assert(completed.created_players === recordCount, "Created count was wrong.")
  assert(
    completed.created_sleeper_ids === recordCount,
    "Primary Sleeper mapping count was wrong."
  )
  assert(
    completed.active_players === 4_455,
    "Completion did not report 4,455 active individual players."
  )
  assert(
    completed.team_defenses === 50,
    "Completion did not report 50 current team defenses."
  )

  const [
    players,
    primaryIds,
    allPrimaryMappings,
    activeIndividualPlayers,
    currentTeamDefenses,
    run,
    sample,
  ] = await Promise.all([
    identityA.client
      .from("players")
      .select("id", { count: "exact", head: true }),
    identityA.client
      .from("player_external_ids")
      .select("id", { count: "exact", head: true })
      .eq("namespace", "sleeper")
      .eq("sport", "nfl")
      .eq("is_primary", true)
      .is("removed_at", null),
    readAllActivePrimaryMappings(identityA.client),
    identityA.client
      .from("players")
      .select("id, player_external_ids!inner(id)", {
        count: "exact",
        head: true,
      })
      .eq("entity_type", "player")
      .eq("active", true)
      .eq("player_external_ids.namespace", "sleeper")
      .eq("player_external_ids.sport", "nfl")
      .eq("player_external_ids.is_primary", true)
      .is("player_external_ids.removed_at", null),
    identityA.client
      .from("players")
      .select("id, player_external_ids!inner(id)", {
        count: "exact",
        head: true,
      })
      .eq("entity_type", "team_defense")
      .eq("player_external_ids.namespace", "sleeper")
      .eq("player_external_ids.sport", "nfl")
      .eq("player_external_ids.is_primary", true)
      .is("player_external_ids.removed_at", null),
    identityA.client
      .from("provider_catalog_runs")
      .select("status, progress_current, progress_total, source_bytes")
      .eq("id", start.catalog_run_id)
      .single(),
    identityA.client
      .from("players")
      .select("display_name, profile_fetched_at")
      .eq("display_name", "Load Player 4999")
      .single(),
  ])
  assertSucceeded(players, "count load players")
  assertSucceeded(primaryIds, "count load primary IDs")
  assertSucceeded(activeIndividualPlayers, "count active individual players")
  assertSucceeded(currentTeamDefenses, "count current team defenses")
  assertSucceeded(run, "read load run")
  assertSucceeded(sample, "read load profile")
  assert(players.count === recordCount, "Canonical load count was wrong.")
  assert(primaryIds.count === recordCount, "Primary ID load count was wrong.")
  assert(
    activeIndividualPlayers.count === 4_455,
    "Dashboard-style query did not return 4,455 active individual players."
  )
  assert(
    currentTeamDefenses.count === 50,
    "Dashboard-style query did not return 50 current team defenses."
  )
  assert(
    new Set(
      allPrimaryMappings.map(
        (row) => `${row.namespace}:${row.sport}:${row.external_id}`
      )
    ).size === recordCount &&
      new Set(allPrimaryMappings.map((row) => row.player_id)).size ===
        recordCount,
    "The load catalog contained duplicate identity mappings."
  )
  assert(
    run.data.status === "succeeded" &&
      run.data.progress_current === recordCount &&
      run.data.progress_total === recordCount &&
      run.data.source_bytes === stagedSourceEnvelopeBytes,
    "The load catalog run was not succeeded, complete, and staged above 15 MB."
  )
  assert(
    sample.data.display_name === "Load Player 4999" &&
      new Date(sample.data.profile_fetched_at).getTime() ===
        new Date(sourceFetchedAt).getTime(),
    "A canonical load profile was not queryable."
  )

  const privateDump = spawnSync(
    supabaseExecutable,
    ["db", "dump", "--local", "--data-only", "--schema", "app_private"],
    {
      cwd: projectRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "inherit"],
    }
  )
  if (privateDump.error) throw privateDump.error
  assert(privateDump.status === 0, "Private staging verification failed.")
  assert(
    !privateDump.stdout.includes(start.catalog_run_id),
    "Private staging still contained the completed catalog run."
  )

  const identityB = await createIdentity("b")
  const fresh = assertSucceeded(
    await admin.rpc("start_sleeper_player_catalog_sync", {
      p_user_id: identityB.userId,
    }),
    "reuse fresh player catalog"
  )?.[0]
  assert(
    fresh?.catalog_fresh && !fresh.created_run && !fresh.reused_run,
    "A second user did not receive the fresh global catalog state."
  )

  console.log(
    `Player catalog load test passed: ${recordCount} records, ${generatedPayloadBytes} generated fixture bytes, ${stagedSourceEnvelopeBytes} staged source-envelope bytes, ${recordCount} players, ${recordCount} primary mappings, 4455 active individual players, 50 current team defenses, ${Date.now() - startedAt}ms.`
  )
}

await withTimeout(run(), overallTimeoutMs)
