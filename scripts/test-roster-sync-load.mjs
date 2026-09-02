import { spawnSync } from "node:child_process"
import { join } from "node:path"

import { createClient } from "@supabase/supabase-js"

const projectRoot = process.cwd()
const supabaseExecutable = join(projectRoot, "node_modules", ".bin", "supabase")
const overallTimeoutMs = 180_000
const leagueCount = 30
const rostersPerLeague = 12
const playersPerRoster = 20
const password = "roster-load-fixture-password"

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function assertSucceeded(result, label) {
  if (result.error) throw new Error(`${label} failed: ${result.error.message}`)
  return result.data
}

function withTimeout(promise, timeoutMs, label) {
  let timeout
  const deadline = new Promise((_, reject) => {
    timeout = setTimeout(
      () => reject(new Error(`${label} exceeded ${timeoutMs}ms.`)),
      timeoutMs
    )
  })
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timeout))
}

function normalizedPlayer(index, sourceFetchedAt) {
  const externalPlayerId = `roster-load-${index.toString().padStart(4, "0")}`
  return {
    external_player_id: externalPlayerId,
    profile: {
      sport: "nfl",
      entity_type: "player",
      display_name: `Roster Load Player ${index}`,
      first_name: "Roster",
      last_name: `Load ${index}`,
      full_name: `Roster Load Player ${index}`,
      primary_position: "WR",
      fantasy_positions: ["WR"],
      nfl_team: null,
      active: true,
      status: "Active",
      jersey_number: index % 99,
      age: 25,
      height: "6-1",
      weight: "205",
      years_experience: 3,
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

function seasonState(fetchedAt) {
  return {
    season: 2026,
    league_season: 2026,
    league_create_season: 2027,
    previous_season: 2025,
    season_type: "regular",
    week: 1,
    leg: 1,
    display_week: 1,
    season_start_date: "2026-09-10",
    provider_metadata: { fixture: "roster-load" },
    fetched_at: fetchedAt,
  }
}

function league(externalLeagueId, fetchedAt) {
  return {
    external_league_id: externalLeagueId,
    sport: "nfl",
    season: 2026,
    name: "Roster load league",
    status: "in_season",
    season_type: "regular",
    team_count: rostersPerLeague,
    roster_size: 3,
    roster_management_type: "dynasty",
    is_best_ball: false,
    has_superflex: false,
    has_idp: false,
    scoring_format: "ppr",
    avatar_id: null,
    avatar_url: null,
    previous_external_league_id: null,
    settings: { type: 2, fixture: "roster-load" },
    scoring_settings: { rec: 1 },
    roster_positions: ["QB", "RB", "BN"],
    provider_metadata: { fixture: "roster-load" },
    provider_updated_at: fetchedAt,
    fetched_at: fetchedAt,
  }
}

function normalizedMembership(externalPlayerId, sourceOrder, annotationMode) {
  const hasAnnotations = annotationMode === "nonempty"
  const annotationSourceState = annotationMode === "null" ? "unknown" : "known"
  return {
    external_player_id: externalPlayerId,
    source_order: sourceOrder,
    is_starter: hasAnnotations && sourceOrder === 1,
    starter_order: hasAnnotations && sourceOrder === 1 ? 1 : null,
    starter_slot: hasAnnotations && sourceOrder === 1 ? "QB" : null,
    is_reserve: hasAnnotations && sourceOrder === 2,
    is_taxi: hasAnnotations && sourceOrder === 3,
    is_keeper: hasAnnotations && sourceOrder === 4,
    source_metadata: {
      annotation_source_state: {
        starters: annotationSourceState,
        reserve: annotationSourceState,
        taxi: annotationSourceState,
        keepers: annotationSourceState,
      },
      normalization_warning_fields: [],
    },
  }
}

function rosterPlayerIds(leagueIndex, rosterIndex) {
  const ids = Array.from({ length: playersPerRoster }, (_, playerIndex) => {
    const index =
      ((leagueIndex * rostersPerLeague * playersPerRoster +
        rosterIndex * playersPerRoster +
        playerIndex) %
        500) +
      1
    return `roster-load-${index.toString().padStart(4, "0")}`
  })
  if (leagueIndex === 0 && rosterIndex === 0) {
    ids[playersPerRoster - 1] = "roster-load-reference-only"
  }
  return ids
}

function rosterBundle(
  externalLeagueId,
  leagueIndex,
  accountExternalUserId,
  fetchedAt
) {
  const users = Array.from({ length: rostersPerLeague }, (_, rosterIndex) => {
    const externalUserId =
      rosterIndex === 0
        ? accountExternalUserId
        : `roster-load-user-${leagueIndex + 1}-${rosterIndex + 1}`
    return {
      external_user_id: externalUserId,
      username: `RosterLoad${leagueIndex + 1}${rosterIndex + 1}`,
      display_name: `Roster Load User ${rosterIndex + 1}`,
      team_name: `Roster Load Team ${rosterIndex + 1}`,
      avatar_id: null,
      avatar_url: null,
      is_commissioner: rosterIndex === 0,
      metadata: {
        _fantasyhud: {
          metadata_source_state: "object",
          is_owner_source_state: "boolean",
          normalization_warning_fields: [],
        },
      },
    }
  })
  const rosters = Array.from({ length: rostersPerLeague }, (_, rosterIndex) => {
    const playerIds = rosterPlayerIds(leagueIndex, rosterIndex)
    const annotationMode = ["nonempty", "null", "empty"][rosterIndex % 3]
    const sourceStarterIds =
      annotationMode === "nonempty"
        ? [playerIds[0], "0"]
        : annotationMode === "null"
          ? null
          : []
    const sourceReserveIds =
      annotationMode === "nonempty"
        ? [playerIds[1]]
        : annotationMode === "null"
          ? null
          : []
    const sourceTaxiIds =
      annotationMode === "nonempty"
        ? [playerIds[2]]
        : annotationMode === "null"
          ? null
          : []
    const sourceKeeperIds =
      annotationMode === "nonempty"
        ? [playerIds[3]]
        : annotationMode === "null"
          ? null
          : []
    return {
      external_roster_id: rosterIndex + 1,
      owner_external_user_id: users[rosterIndex].external_user_id,
      co_owner_external_user_ids: [],
      source_player_ids: playerIds,
      source_starter_ids: sourceStarterIds,
      source_reserve_ids: sourceReserveIds,
      source_taxi_ids: sourceTaxiIds,
      source_keeper_ids: sourceKeeperIds,
      settings: { roster_index: rosterIndex + 1 },
      metadata: {
        _fantasyhud: { metadata_source_state: "object" },
      },
      memberships: playerIds.map((playerId, playerIndex) =>
        normalizedMembership(playerId, playerIndex + 1, annotationMode)
      ),
    }
  })
  return {
    external_league_id: externalLeagueId,
    league_season: 2026,
    bundle_fetched_at: fetchedAt,
    users,
    rosters,
    source_metadata: {
      fixture: "roster-load",
      normalization_warning_count: 0,
      users_endpoint_succeeded: 1,
      rosters_endpoint_succeeded: 1,
      users_response_bytes: 10_000,
      rosters_response_bytes: 100_000,
      source_fetch_duration_ms: 50,
    },
  }
}

async function readAll(client, table, columns, configure = (query) => query) {
  const pageSize = 1_000
  const rows = []
  for (let from = 0; ; from += pageSize) {
    let query = client
      .from(table)
      .select(columns)
      .order("id")
      .range(from, from + pageSize - 1)
    query = configure(query)
    const page = assertSucceeded(
      await query,
      `read ${table} page ${from / pageSize}`
    )
    rows.push(...page)
    if (page.length < pageSize) return rows
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
  assert(status.status === 0, "Local Supabase must be running.")

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
  const suffix = Date.now().toString()
  const created = assertSucceeded(
    await admin.auth.admin.createUser({
      email: `task007b2-load-${suffix}@example.test`,
      password,
      email_confirm: true,
    }),
    "create roster load identity"
  )
  assert(created.user, "Roster load identity was not created.")
  const accountExternalUserId = `roster-load-account-${suffix}`
  const connected = assertSucceeded(
    await admin.rpc("connect_sleeper_account", {
      p_avatar_url: null,
      p_display_name: "Roster load identity",
      p_external_user_id: accountExternalUserId,
      p_provider_metadata: { fixture: "roster-load" },
      p_user_id: created.user.id,
      p_username: `RosterLoad${suffix}`,
    }),
    "connect roster load identity"
  )?.[0]
  assert(connected, "Roster load identity was not connected.")
  const client = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  assertSucceeded(
    await client.auth.signInWithPassword({
      email: created.user.email,
      password,
    }),
    "sign in roster load identity"
  )

  const catalogStart = assertSucceeded(
    await admin.rpc("start_sleeper_player_catalog_sync", {
      p_user_id: created.user.id,
    }),
    "start roster load catalog prerequisite"
  )?.[0]
  assert(catalogStart?.created_run, "Roster load catalog did not start.")
  const catalogFetchedAt = "2098-12-31T00:00:00.000Z"
  const catalogRecords = Array.from({ length: 500 }, (_, index) =>
    normalizedPlayer(index + 1, catalogFetchedAt)
  )
  assertSucceeded(
    await admin.rpc("stage_sleeper_player_catalog_batch", {
      p_batch_index: 0,
      p_catalog_run_id: catalogStart.catalog_run_id,
      p_expected_total: catalogRecords.length,
      p_records: catalogRecords,
      p_source_bytes: new TextEncoder().encode(JSON.stringify(catalogRecords))
        .byteLength,
      p_source_fetched_at: catalogFetchedAt,
      p_user_id: created.user.id,
    }),
    "stage roster load catalog prerequisite"
  )
  const catalogCompletion = assertSucceeded(
    await admin.rpc("complete_sleeper_player_catalog_sync", {
      p_catalog_run_id: catalogStart.catalog_run_id,
      p_user_id: created.user.id,
    }),
    "complete roster load catalog prerequisite"
  )?.[0]
  assert(
    catalogCompletion?.created_sleeper_ids === 500,
    "Roster load catalog did not publish 500 mappings."
  )

  const leagueFetchedAt = "2099-01-01T00:00:00.000Z"
  const externalLeagueIds = Array.from(
    { length: leagueCount },
    (_, index) =>
      `roster-load-league-${(index + 1).toString().padStart(2, "0")}`
  )
  const discoveryStart = assertSucceeded(
    await admin.rpc("start_sleeper_league_discovery", {
      p_fantasy_account_id: connected.fantasy_account_id,
      p_user_id: created.user.id,
    }),
    "start roster load discovery prerequisite"
  )?.[0]
  assert(discoveryStart?.created_run, "Roster load discovery did not start.")
  const discoveryCompletion = assertSucceeded(
    await admin.rpc("complete_sleeper_league_discovery", {
      p_fantasy_account_id: connected.fantasy_account_id,
      p_leagues: externalLeagueIds.map((id) => league(id, leagueFetchedAt)),
      p_state: seasonState(leagueFetchedAt),
      p_sync_run_id: discoveryStart.sync_run_id,
      p_user_id: created.user.id,
    }),
    "complete roster load discovery prerequisite"
  )?.[0]
  assert(
    discoveryCompletion?.active_associations === leagueCount,
    "Roster load discovery did not publish 30 associations."
  )

  const rosterFetchedAt = "2099-01-02T00:00:00.000Z"
  const bundles = externalLeagueIds.map((id, index) =>
    rosterBundle(id, index, accountExternalUserId, rosterFetchedAt)
  )
  assert(
    bundles.every(
      (value) =>
        new TextEncoder().encode(JSON.stringify(value)).byteLength < 2_000_000
    ),
    "A generated roster load bundle exceeded the stage limit."
  )

  async function publishRosterRun(label) {
    const start = assertSucceeded(
      await admin.rpc("start_sleeper_roster_sync", {
        p_fantasy_account_id: connected.fantasy_account_id,
        p_user_id: created.user.id,
      }),
      `start roster load ${label}`
    )?.[0]
    assert(
      start?.created_run &&
        start.expected_external_league_ids.length === leagueCount,
      `Roster load ${label} did not freeze 30 leagues.`
    )
    for (const value of bundles) {
      const staged = assertSucceeded(
        await admin.rpc("stage_sleeper_roster_league_bundle", {
          p_bundle: value,
          p_external_league_id: value.external_league_id,
          p_fantasy_account_id: connected.fantasy_account_id,
          p_sync_run_id: start.sync_run_id,
          p_user_id: created.user.id,
        }),
        `stage roster load ${label}`
      )?.[0]
      assert(staged, `Roster load ${label} returned no stage result.`)
    }
    const completionStartedAt = Date.now()
    const completionResult = await withTimeout(
      admin.rpc("complete_sleeper_roster_sync", {
        p_fantasy_account_id: connected.fantasy_account_id,
        p_sync_run_id: start.sync_run_id,
        p_user_id: created.user.id,
      }),
      59_000,
      `Roster load ${label} completion`
    )
    const completionDurationMs = Date.now() - completionStartedAt
    const completion = assertSucceeded(
      completionResult,
      `complete roster load ${label}`
    )?.[0]
    assert(completion, `Roster load ${label} returned no completion result.`)
    assert(
      completionDurationMs < 60_000,
      `Roster load ${label} completion exceeded the 60-second RPC ceiling.`
    )
    return { completion, completionDurationMs, runId: start.sync_run_id }
  }

  const first = await publishRosterRun("first publication")
  const expectedUsers = leagueCount * rostersPerLeague
  const expectedRosters = leagueCount * rostersPerLeague
  const expectedMemberships = expectedRosters * playersPerRoster
  const expectedOwnedMemberships = leagueCount * playersPerRoster
  assert(
    first.completion.final_status === "succeeded" &&
      first.completion.observed_leagues === leagueCount &&
      first.completion.applied_shared_league_bundles === leagueCount &&
      first.completion.stale_shared_league_bundles_skipped === 0 &&
      first.completion.observed_league_users === expectedUsers &&
      first.completion.observed_rosters === expectedRosters &&
      first.completion.observed_memberships === expectedMemberships &&
      first.completion.active_owned_rosters === leagueCount &&
      first.completion.active_owned_memberships === expectedOwnedMemberships &&
      first.completion.owned_leagues === leagueCount &&
      first.completion.confirmed_not_owned_leagues === 0 &&
      first.completion.unresolved_ownership_leagues === 0 &&
      first.completion.stale_ownership_resolutions_skipped === 0 &&
      first.completion.created_reference_players === 1,
    "The first roster load completion returned incorrect aggregate counts."
  )

  const [
    userRows,
    rosterRows,
    membershipRows,
    ownershipRows,
    leagueRows,
    accountLeagueRows,
  ] = await Promise.all([
    readAll(client, "league_users", "id, league_id, external_user_id"),
    readAll(
      client,
      "rosters",
      "id, league_id, external_roster_id, source_starter_ids, source_reserve_ids, source_taxi_ids, source_keeper_ids, first_seen_at, removed_at"
    ),
    readAll(
      client,
      "roster_players",
      "id, roster_id, player_id, source_order, is_starter, starter_order, is_reserve, is_taxi, is_keeper, first_seen_at, removed_at"
    ),
    readAll(
      client,
      "fantasy_account_rosters",
      "id, league_id, roster_id, ownership_role, first_seen_at, removed_at",
      (query) => query.eq("fantasy_account_id", connected.fantasy_account_id)
    ),
    client
      .from("leagues")
      .select("id, external_league_id, roster_bundle_fetched_at")
      .in("external_league_id", externalLeagueIds),
    client
      .from("fantasy_account_leagues")
      .select(
        "league_id, roster_ownership_status, roster_ownership_observed_at"
      )
      .eq("fantasy_account_id", connected.fantasy_account_id)
      .is("removed_at", null),
  ])
  assertSucceeded(leagueRows, "read roster load collection watermarks")
  assertSucceeded(accountLeagueRows, "read roster load ownership states")
  assert(userRows.length === expectedUsers, "League-user load count was wrong.")
  assert(rosterRows.length === expectedRosters, "Roster load count was wrong.")
  assert(
    membershipRows.length === expectedMemberships,
    "Roster-membership load count was wrong."
  )
  assert(
    ownershipRows.length === leagueCount &&
      ownershipRows.every(
        (row) => row.removed_at === null && row.ownership_role === "owner"
      ),
    "Owned-roster load count or role was wrong."
  )
  assert(
    leagueRows.data.length === leagueCount &&
      leagueRows.data.every(
        (row) =>
          Date.parse(row.roster_bundle_fetched_at) ===
          Date.parse(rosterFetchedAt)
      ),
    "The roster load did not persist the complete-bundle watermarks."
  )
  assert(
    accountLeagueRows.data.length === leagueCount &&
      accountLeagueRows.data.every(
        (row) =>
          row.roster_ownership_status === "owned" &&
          Date.parse(row.roster_ownership_observed_at) ===
            Date.parse(rosterFetchedAt)
      ),
    "The roster load did not persist confirmed-owned account-league state."
  )
  assert(
    new Set(userRows.map((row) => `${row.league_id}:${row.external_user_id}`))
      .size === expectedUsers &&
      new Set(
        rosterRows.map((row) => `${row.league_id}:${row.external_roster_id}`)
      ).size === expectedRosters &&
      new Set(membershipRows.map((row) => `${row.roster_id}:${row.player_id}`))
        .size === expectedMemberships,
    "The roster load created duplicate canonical identities."
  )
  const nullAnnotationRosters = rosterRows.filter(
    (row) => row.source_reserve_ids === null
  )
  const emptyAnnotationRosters = rosterRows.filter(
    (row) =>
      Array.isArray(row.source_reserve_ids) &&
      row.source_reserve_ids.length === 0
  )
  const nonemptyAnnotationRosters = rosterRows.filter(
    (row) =>
      Array.isArray(row.source_reserve_ids) && row.source_reserve_ids.length > 0
  )
  assert(
    nullAnnotationRosters.length === expectedRosters / 3 &&
      emptyAnnotationRosters.length === expectedRosters / 3 &&
      nonemptyAnnotationRosters.length === expectedRosters / 3 &&
      nullAnnotationRosters.every(
        (row) =>
          row.source_starter_ids === null &&
          row.source_taxi_ids === null &&
          row.source_keeper_ids === null
      ) &&
      emptyAnnotationRosters.every(
        (row) =>
          row.source_starter_ids.length === 0 &&
          row.source_taxi_ids.length === 0 &&
          row.source_keeper_ids.length === 0
      ),
    "The load fixture did not preserve balanced null, empty, and nonempty annotation arrays."
  )
  const rosterById = new Map(rosterRows.map((row) => [row.id, row]))
  const expectedAnnotatedRosters = nonemptyAnnotationRosters.length
  assert(
    membershipRows.filter((row) => row.is_starter).length ===
      expectedAnnotatedRosters &&
      membershipRows.every((row) => {
        const roster = rosterById.get(row.roster_id)
        const hasAnnotations = roster.source_reserve_ids?.length > 0
        return hasAnnotations
          ? (row.is_starter &&
              row.source_order === 1 &&
              row.starter_order === 1) ||
              (!row.is_starter && row.starter_order === null)
          : !row.is_starter && row.starter_order === null
      }),
    "Starter flags and orders were not exact at load scale."
  )
  assert(
    membershipRows.filter((row) => row.is_reserve).length ===
      expectedAnnotatedRosters &&
      membershipRows.filter((row) => row.is_taxi).length ===
        expectedAnnotatedRosters &&
      membershipRows.filter((row) => row.is_keeper).length ===
        expectedAnnotatedRosters &&
      membershipRows.every((row) => {
        const roster = rosterById.get(row.roster_id)
        const hasAnnotations = roster.source_reserve_ids?.length > 0
        return hasAnnotations
          ? row.is_reserve === (row.source_order === 2) &&
              row.is_taxi === (row.source_order === 3) &&
              row.is_keeper === (row.source_order === 4)
          : !row.is_reserve && !row.is_taxi && !row.is_keeper
      }),
    "Reserve, taxi, and keeper flags were not exact at load scale."
  )

  const firstSeenRoster = rosterRows[0]
  const firstSeenMembership = membershipRows[0]
  const second = await publishRosterRun("idempotent publication")
  assert(
    second.completion.final_status === "succeeded" &&
      second.completion.applied_shared_league_bundles === leagueCount &&
      second.completion.stale_shared_league_bundles_skipped === 0 &&
      second.completion.created_league_users === 0 &&
      second.completion.created_rosters === 0 &&
      second.completion.created_memberships === 0 &&
      second.completion.created_ownerships === 0 &&
      second.completion.owned_leagues === leagueCount &&
      second.completion.confirmed_not_owned_leagues === 0 &&
      second.completion.unresolved_ownership_leagues === 0 &&
      second.completion.stale_ownership_resolutions_skipped === 0 &&
      second.completion.active_owned_rosters === leagueCount &&
      second.completion.active_owned_memberships === expectedOwnedMemberships,
    "The identical second load was not idempotent."
  )
  const [rosterAfter, membershipAfter, account, run] = await Promise.all([
    client
      .from("rosters")
      .select("first_seen_at")
      .eq("id", firstSeenRoster.id)
      .single(),
    client
      .from("roster_players")
      .select("first_seen_at")
      .eq("id", firstSeenMembership.id)
      .single(),
    client
      .from("fantasy_accounts")
      .select("last_synced_at")
      .eq("id", connected.fantasy_account_id)
      .single(),
    client
      .from("sync_runs")
      .select("status, progress_current, progress_total, result_counts")
      .eq("id", second.runId)
      .single(),
  ])
  assertSucceeded(rosterAfter, "read idempotent roster")
  assertSucceeded(membershipAfter, "read idempotent membership")
  assertSucceeded(account, "read roster load account")
  assertSucceeded(run, "read roster load run")
  assert(
    rosterAfter.data.first_seen_at === firstSeenRoster.first_seen_at &&
      membershipAfter.data.first_seen_at === firstSeenMembership.first_seen_at,
    "Idempotent roster publication changed first-seen history."
  )
  assert(
    account.data.last_synced_at === null,
    "Roster load changed last_synced_at."
  )
  assert(
    run.data.status === "succeeded" &&
      run.data.progress_current === leagueCount &&
      run.data.progress_total === leagueCount,
    "The idempotent roster run was not terminal and complete."
  )
  assert(
    run.data.result_counts.source_user_endpoint_successes === leagueCount &&
      run.data.result_counts.source_roster_endpoint_successes === leagueCount &&
      run.data.result_counts.source_endpoint_successes === leagueCount * 2 &&
      run.data.result_counts.source_response_bytes === leagueCount * 110_000 &&
      run.data.result_counts.source_fetch_duration_ms_total ===
        leagueCount * 50 &&
      run.data.result_counts.source_fetch_duration_ms_max === 50 &&
      run.data.result_counts.applied_shared_league_bundles === leagueCount &&
      run.data.result_counts.stale_shared_league_bundles_skipped === 0 &&
      run.data.result_counts.owned_leagues === leagueCount &&
      run.data.result_counts.confirmed_not_owned_leagues === 0 &&
      run.data.result_counts.unresolved_ownership_leagues === 0 &&
      run.data.result_counts.stale_ownership_resolutions_skipped === 0 &&
      run.data.result_counts.stage_insert_window_ms >= 0 &&
      run.data.result_counts.stage_to_completion_ms >= 0 &&
      run.data.result_counts.completion_duration_ms >= 0 &&
      run.data.result_counts.completion_duration_ms < 60_000,
    "The terminal roster run did not retain bounded source and timing observability."
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
  assert(privateDump.status === 0, "Private roster load staging check failed.")
  assert(
    !privateDump.stdout.includes(first.runId) &&
      !privateDump.stdout.includes(second.runId),
    "A completed roster load retained private stage state."
  )

  console.log(
    `Roster load test passed: ${leagueCount} leagues, ${expectedUsers} users, ${expectedRosters} rosters, ${expectedMemberships} memberships, ${leagueCount} ownerships, 2 succeeded runs, completions ${first.completionDurationMs}ms/${second.completionDurationMs}ms, total ${Date.now() - startedAt}ms.`
  )
}

await withTimeout(run(), overallTimeoutMs, "Roster load test")
