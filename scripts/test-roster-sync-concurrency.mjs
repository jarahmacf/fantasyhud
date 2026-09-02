import { spawnSync } from "node:child_process"
import { join } from "node:path"

import { createClient } from "@supabase/supabase-js"

const projectRoot = process.cwd()
const supabaseExecutable = join(projectRoot, "node_modules", ".bin", "supabase")
const overallTimeoutMs = 180_000
const password = "roster-concurrency-fixture-password"
const suffix = Date.now().toString()

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
  const externalPlayerId = `roster-${index.toString().padStart(4, "0")}`
  return {
    external_player_id: externalPlayerId,
    profile: {
      sport: "nfl",
      entity_type: "player",
      display_name: `Roster Player ${index}`,
      first_name: "Roster",
      last_name: `Player ${index}`,
      full_name: `Roster Player ${index}`,
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

function seasonState(fetchedAt, freshness) {
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
    provider_metadata: { freshness },
    fetched_at: fetchedAt,
  }
}

function league(externalLeagueId, fetchedAt, freshness) {
  return {
    external_league_id: externalLeagueId,
    sport: "nfl",
    season: 2026,
    name: `Concurrency ${freshness}`,
    status: "in_season",
    season_type: "regular",
    team_count: 2,
    roster_size: 3,
    roster_management_type: "dynasty",
    is_best_ball: false,
    has_superflex: false,
    has_idp: false,
    scoring_format: "ppr",
    avatar_id: null,
    avatar_url: null,
    previous_external_league_id: null,
    settings: { type: 2, freshness },
    scoring_settings: { rec: 1 },
    roster_positions: ["QB", "RB", "BN"],
    provider_metadata: { freshness },
    provider_updated_at: fetchedAt,
    fetched_at: fetchedAt,
  }
}

function membership(
  externalPlayerId,
  sourceOrder,
  starterPlayerId,
  reservePlayerId,
  keeperPlayerId
) {
  const isStarter = externalPlayerId === starterPlayerId
  return {
    external_player_id: externalPlayerId,
    source_order: sourceOrder,
    is_starter: isStarter,
    starter_order: isStarter ? 1 : null,
    starter_slot: isStarter ? "QB" : null,
    is_reserve: externalPlayerId === reservePlayerId,
    is_taxi: false,
    is_keeper: externalPlayerId === keeperPlayerId,
    source_metadata: {
      annotation_source_state: {
        starters: "known",
        reserve: "known",
        taxi: "known",
        keepers: "known",
      },
      normalization_warning_fields: [],
    },
  }
}

function bundle(
  externalLeagueId,
  bundleFetchedAt,
  freshness,
  accountExternalIds
) {
  const playerIds = ["roster-0001", "roster-0002"]
  const starterPlayerId = freshness === "newer" ? playerIds[0] : playerIds[1]
  const reservePlayerId = freshness === "newer" ? playerIds[1] : playerIds[0]
  const users = accountExternalIds.map((externalUserId, index) => ({
    external_user_id: externalUserId,
    username: `ConcurrencyUser${index + 1}`,
    display_name: `${freshness} user ${index + 1}`,
    team_name: `${freshness} team ${index + 1}`,
    avatar_id: null,
    avatar_url: null,
    is_commissioner: index === 0,
    metadata: {
      freshness,
      _fantasyhud: {
        metadata_source_state: "object",
        is_owner_source_state: "boolean",
        normalization_warning_fields: [],
      },
    },
  }))
  const rosters = accountExternalIds.map((externalUserId, index) => ({
    external_roster_id: index + 1,
    owner_external_user_id: externalUserId,
    co_owner_external_user_ids: [],
    source_player_ids: [...playerIds],
    source_starter_ids: [starterPlayerId, "0"],
    source_reserve_ids: [reservePlayerId],
    source_taxi_ids: [],
    source_keeper_ids: [starterPlayerId],
    settings: { freshness, roster_index: index + 1 },
    metadata: {
      freshness,
      _fantasyhud: { metadata_source_state: "object" },
    },
    memberships: playerIds.map((playerId, playerIndex) =>
      membership(
        playerId,
        playerIndex + 1,
        starterPlayerId,
        reservePlayerId,
        starterPlayerId
      )
    ),
  }))

  return {
    external_league_id: externalLeagueId,
    league_season: 2026,
    bundle_fetched_at: bundleFetchedAt,
    users,
    rosters,
    source_metadata: {
      freshness,
      normalization_warning_count: 0,
      users_endpoint_succeeded: 1,
      rosters_endpoint_succeeded: 1,
      users_response_bytes: 1_000,
      rosters_response_bytes: 2_000,
      source_fetch_duration_ms: 25,
    },
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

  async function createIdentity(label) {
    const externalUserId = `roster-concurrency-user-${label}-${suffix}`
    const created = assertSucceeded(
      await admin.auth.admin.createUser({
        email: `task007b2-concurrency-${label}-${suffix}@example.test`,
        password,
        email_confirm: true,
      }),
      `create identity ${label}`
    )
    assert(created.user, `Identity ${label} was not created.`)
    const connected = assertSucceeded(
      await admin.rpc("connect_sleeper_account", {
        p_avatar_url: null,
        p_display_name: `Roster concurrency ${label}`,
        p_external_user_id: externalUserId,
        p_provider_metadata: { fixture: "roster-concurrency" },
        p_user_id: created.user.id,
        p_username: `RosterConcurrency${label}${suffix}`,
      }),
      `connect identity ${label}`
    )?.[0]
    assert(connected, `Identity ${label} was not connected.`)
    const client = createClient(supabaseUrl, publishableKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    assertSucceeded(
      await client.auth.signInWithPassword({
        email: created.user.email,
        password,
      }),
      `sign in identity ${label}`
    )
    return {
      accountId: connected.fantasy_account_id,
      client,
      externalUserId,
      userId: created.user.id,
    }
  }

  const [identityA, identityB] = await Promise.all([
    createIdentity("a"),
    createIdentity("b"),
  ])

  const catalogStart = assertSucceeded(
    await admin.rpc("start_sleeper_player_catalog_sync", {
      p_user_id: identityA.userId,
    }),
    "start catalog prerequisite"
  )?.[0]
  assert(catalogStart?.created_run, "Catalog prerequisite did not start.")
  const sourceFetchedAt = "2098-12-31T00:00:00.000Z"
  const catalogRecords = Array.from({ length: 500 }, (_, index) =>
    normalizedPlayer(index + 1, sourceFetchedAt)
  )
  assertSucceeded(
    await admin.rpc("stage_sleeper_player_catalog_batch", {
      p_batch_index: 0,
      p_catalog_run_id: catalogStart.catalog_run_id,
      p_expected_total: catalogRecords.length,
      p_records: catalogRecords,
      p_source_bytes: new TextEncoder().encode(JSON.stringify(catalogRecords))
        .byteLength,
      p_source_fetched_at: sourceFetchedAt,
      p_user_id: identityA.userId,
    }),
    "stage catalog prerequisite"
  )
  const catalogCompletion = assertSucceeded(
    await admin.rpc("complete_sleeper_player_catalog_sync", {
      p_catalog_run_id: catalogStart.catalog_run_id,
      p_user_id: identityA.userId,
    }),
    "complete catalog prerequisite"
  )?.[0]
  assert(
    catalogCompletion?.created_sleeper_ids === 500,
    "Catalog prerequisite did not publish 500 mappings."
  )

  const externalLeagueIds = [
    `roster-concurrency-a-${suffix}`,
    `roster-concurrency-b-${suffix}`,
  ]
  const newerFetchedAt = "2099-02-02T00:00:00.000Z"
  const olderFetchedAt = "2099-02-01T00:00:00.000Z"

  async function discover(identity, fetchedAt, freshness, orderedIds) {
    const start = assertSucceeded(
      await admin.rpc("start_sleeper_league_discovery", {
        p_fantasy_account_id: identity.accountId,
        p_user_id: identity.userId,
      }),
      `start ${freshness} discovery`
    )?.[0]
    assert(start?.created_run, `${freshness} discovery did not start.`)
    const completion = assertSucceeded(
      await admin.rpc("complete_sleeper_league_discovery", {
        p_fantasy_account_id: identity.accountId,
        p_leagues: orderedIds.map((id) => league(id, fetchedAt, freshness)),
        p_state: seasonState(fetchedAt, freshness),
        p_sync_run_id: start.sync_run_id,
        p_user_id: identity.userId,
      }),
      `complete ${freshness} discovery`
    )?.[0]
    assert(
      completion?.active_associations === 2,
      `${freshness} discovery did not create two associations.`
    )
  }

  await Promise.all([
    discover(identityA, newerFetchedAt, "newer", externalLeagueIds),
    discover(
      identityB,
      olderFetchedAt,
      "older",
      [...externalLeagueIds].reverse()
    ),
  ])

  async function startRosterSync(identity, label) {
    const start = assertSucceeded(
      await admin.rpc("start_sleeper_roster_sync", {
        p_fantasy_account_id: identity.accountId,
        p_user_id: identity.userId,
      }),
      `start roster sync ${label}`
    )?.[0]
    assert(
      start?.created_run && start.expected_external_league_ids.length === 2,
      `Roster sync ${label} did not freeze two leagues.`
    )
    return start
  }

  const [startA, startB] = await Promise.all([
    startRosterSync(identityA, "A"),
    startRosterSync(identityB, "B"),
  ])
  const completedRunIds = [startA.sync_run_id, startB.sync_run_id]
  const accountExternalIds = [
    identityA.externalUserId,
    identityB.externalUserId,
  ]

  async function stageAll(identity, start, fetchedAt, freshness, ids) {
    for (const externalLeagueId of ids) {
      const staged = assertSucceeded(
        await admin.rpc("stage_sleeper_roster_league_bundle", {
          p_bundle: bundle(
            externalLeagueId,
            fetchedAt,
            freshness,
            accountExternalIds
          ),
          p_external_league_id: externalLeagueId,
          p_fantasy_account_id: identity.accountId,
          p_sync_run_id: start.sync_run_id,
          p_user_id: identity.userId,
        }),
        `stage roster bundle ${freshness}`
      )?.[0]
      assert(staged, `A ${freshness} roster bundle returned no stage result.`)
    }
  }

  async function startAndStage(identity, label, values) {
    const start = await withTimeout(
      startRosterSync(identity, label),
      15_000,
      `${label} start`
    )
    for (const value of values) {
      const staged = assertSucceeded(
        await withTimeout(
          admin.rpc("stage_sleeper_roster_league_bundle", {
            p_bundle: value,
            p_external_league_id: value.external_league_id,
            p_fantasy_account_id: identity.accountId,
            p_sync_run_id: start.sync_run_id,
            p_user_id: identity.userId,
          }),
          15_000,
          `${label} stage ${value.external_league_id}`
        ),
        `${label} stage ${value.external_league_id}`
      )?.[0]
      assert(staged, `${label} returned no stage result.`)
    }
    return start
  }

  async function completePrepared(identity, start, label) {
    const completion = assertSucceeded(
      await withTimeout(
        admin.rpc("complete_sleeper_roster_sync", {
          p_fantasy_account_id: identity.accountId,
          p_sync_run_id: start.sync_run_id,
          p_user_id: identity.userId,
        }),
        30_000,
        `${label} completion`
      ),
      `${label} completion`
    )?.[0]
    assert(completion, `${label} returned no completion result.`)
    completedRunIds.push(start.sync_run_id)
    return completion
  }

  function bundleSet(fetchedAt, freshness) {
    return externalLeagueIds.map((externalLeagueId) =>
      bundle(externalLeagueId, fetchedAt, freshness, accountExternalIds)
    )
  }

  await Promise.all([
    stageAll(identityA, startA, newerFetchedAt, "newer", externalLeagueIds),
    stageAll(
      identityB,
      startB,
      olderFetchedAt,
      "older",
      [...externalLeagueIds].reverse()
    ),
  ])

  const completions = await withTimeout(
    Promise.all([
      admin.rpc("complete_sleeper_roster_sync", {
        p_fantasy_account_id: identityA.accountId,
        p_sync_run_id: startA.sync_run_id,
        p_user_id: identityA.userId,
      }),
      admin.rpc("complete_sleeper_roster_sync", {
        p_fantasy_account_id: identityB.accountId,
        p_sync_run_id: startB.sync_run_id,
        p_user_id: identityB.userId,
      }),
    ]),
    30_000,
    "Concurrent roster completion"
  )
  const completionA = assertSucceeded(
    completions[0],
    "complete roster sync A"
  )?.[0]
  const completionB = assertSucceeded(
    completions[1],
    "complete roster sync B"
  )?.[0]
  assert(
    completionA?.final_status === "succeeded" &&
      completionB?.final_status === "succeeded",
    "Both concurrent roster runs must succeed."
  )

  const [users, rosters, memberships, ownershipA, ownershipB] =
    await Promise.all([
      identityA.client
        .from("league_users")
        .select(
          "league_id, external_user_id, display_name, team_name, fetched_at"
        ),
      identityA.client
        .from("rosters")
        .select(
          "id, league_id, external_roster_id, fetched_at, settings, metadata"
        )
        .is("removed_at", null),
      identityA.client
        .from("roster_players")
        .select(
          "roster_id, player_id, source_order, is_starter, starter_order, starter_slot, is_reserve, is_keeper"
        )
        .is("removed_at", null),
      identityA.client
        .from("fantasy_account_rosters")
        .select("league_id, roster_id, ownership_role")
        .eq("fantasy_account_id", identityA.accountId)
        .is("removed_at", null),
      identityB.client
        .from("fantasy_account_rosters")
        .select("league_id, roster_id, ownership_role")
        .eq("fantasy_account_id", identityB.accountId)
        .is("removed_at", null),
    ])
  const userRows = assertSucceeded(users, "read canonical league users")
  const rosterRows = assertSucceeded(rosters, "read canonical rosters")
  const membershipRows = assertSucceeded(
    memberships,
    "read canonical memberships"
  )
  const ownershipRowsA = assertSucceeded(ownershipA, "read ownership A")
  const ownershipRowsB = assertSucceeded(ownershipB, "read ownership B")
  assert(
    userRows.length === 4,
    "Concurrent publication duplicated league users."
  )
  assert(rosterRows.length === 4, "Concurrent publication duplicated rosters.")
  assert(
    membershipRows.length === 8,
    "Concurrent publication duplicated memberships."
  )
  assert(
    new Set(userRows.map((row) => `${row.league_id}:${row.external_user_id}`))
      .size === 4 &&
      new Set(
        rosterRows.map((row) => `${row.league_id}:${row.external_roster_id}`)
      ).size === 4 &&
      new Set(membershipRows.map((row) => `${row.roster_id}:${row.player_id}`))
        .size === 8,
    "Concurrent publication violated canonical identity uniqueness."
  )
  assert(
    rosterRows.every(
      (row) =>
        Date.parse(row.fetched_at) === Date.parse(newerFetchedAt) &&
        row.settings.freshness === "newer" &&
        row.metadata.freshness === "newer"
    ),
    "The older completion regressed a newer shared roster representation."
  )
  assert(
    userRows.every(
      (row) =>
        row.display_name.startsWith("newer ") &&
        row.team_name.startsWith("newer ") &&
        Date.parse(row.fetched_at) === Date.parse(newerFetchedAt)
    ),
    "The older completion regressed a newer shared league-user representation."
  )
  assert(
    membershipRows.every(
      (row) =>
        (row.source_order === 1 &&
          row.is_starter &&
          row.starter_order === 1 &&
          row.starter_slot === "QB" &&
          !row.is_reserve &&
          row.is_keeper) ||
        (row.source_order === 2 &&
          !row.is_starter &&
          row.starter_order === null &&
          row.starter_slot === null &&
          row.is_reserve &&
          !row.is_keeper)
    ),
    "The older completion regressed newer membership flags or orders."
  )
  assert(
    ownershipRowsA.length === 2 && ownershipRowsB.length === 2,
    "A concurrent account lost or removed another account's ownership."
  )
  assert(
    ownershipRowsA.every((row) => row.ownership_role === "owner") &&
      ownershipRowsB.every((row) => row.ownership_role === "owner"),
    "Concurrent ownership resolution produced the wrong role."
  )

  const staleAbsenceNewerAt = "2099-02-04T00:00:00.000Z"
  const staleAbsenceOlderAt = "2099-02-03T00:00:00.000Z"
  const staleAbsenceNewerBundles = bundleSet(
    staleAbsenceNewerAt,
    "stale-absence-newer"
  )
  const firstAbsenceBundle = staleAbsenceNewerBundles[0]
  firstAbsenceBundle.users = firstAbsenceBundle.users.filter(
    (user) => user.external_user_id !== identityB.externalUserId
  )
  firstAbsenceBundle.rosters = firstAbsenceBundle.rosters.filter(
    (roster) => roster.external_roster_id !== 2
  )
  const survivingRoster = firstAbsenceBundle.rosters[0]
  survivingRoster.source_player_ids = ["roster-0001"]
  survivingRoster.source_starter_ids = ["roster-0001", "0"]
  survivingRoster.source_reserve_ids = []
  survivingRoster.source_taxi_ids = []
  survivingRoster.source_keeper_ids = ["roster-0001"]
  survivingRoster.memberships = [
    membership("roster-0001", 1, "roster-0001", null, "roster-0001"),
  ]
  const staleAbsenceOlderBundles = bundleSet(
    staleAbsenceOlderAt,
    "stale-absence-older"
  )
  const staleOnlyUserId = "stale-only-user"
  const staleOnlyRosterPlayerId = "stale-only-roster-player"
  const staleOnlyMembershipPlayerId = "stale-only-membership-player"
  const firstOlderBundle = staleAbsenceOlderBundles[0]
  firstOlderBundle.users.push({
    ...firstOlderBundle.users[0],
    external_user_id: staleOnlyUserId,
    username: "StaleOnlyUser",
    display_name: "Stale-only user",
    team_name: "Stale-only team",
    is_commissioner: false,
  })
  firstOlderBundle.rosters[0].source_player_ids = [
    ...firstOlderBundle.rosters[0].source_player_ids,
    staleOnlyMembershipPlayerId,
  ]
  firstOlderBundle.rosters[0].memberships.push(
    membership(staleOnlyMembershipPlayerId, 3, "roster-0002", null, null)
  )
  firstOlderBundle.rosters.push({
    external_roster_id: 3,
    owner_external_user_id: staleOnlyUserId,
    co_owner_external_user_ids: [],
    source_player_ids: [staleOnlyRosterPlayerId],
    source_starter_ids: [staleOnlyRosterPlayerId, "0"],
    source_reserve_ids: [],
    source_taxi_ids: [],
    source_keeper_ids: [],
    settings: { freshness: "stale-absence-older", roster_index: 3 },
    metadata: {
      freshness: "stale-absence-older",
      _fantasyhud: { metadata_source_state: "object" },
    },
    memberships: [
      membership(
        staleOnlyRosterPlayerId,
        1,
        staleOnlyRosterPlayerId,
        null,
        null
      ),
    ],
  })
  const staleAbsenceNewerStart = await startAndStage(
    identityA,
    "stale-absence newer",
    staleAbsenceNewerBundles
  )
  const staleAbsenceOlderStart = await startAndStage(
    identityB,
    "stale-absence older",
    staleAbsenceOlderBundles
  )
  const staleAbsenceNewerCompletion = await completePrepared(
    identityA,
    staleAbsenceNewerStart,
    "stale-absence newer"
  )
  const staleAbsenceOlderCompletion = await completePrepared(
    identityB,
    staleAbsenceOlderStart,
    "stale-absence older"
  )
  assert(
    staleAbsenceNewerCompletion.final_status === "succeeded" &&
      staleAbsenceNewerCompletion.applied_shared_league_bundles === 2 &&
      staleAbsenceNewerCompletion.stale_shared_league_bundles_skipped === 0,
    "The newer stale-absence collection did not publish both league bundles."
  )
  assert(
    staleAbsenceOlderCompletion.final_status === "succeeded" &&
      staleAbsenceOlderCompletion.applied_shared_league_bundles === 0 &&
      staleAbsenceOlderCompletion.stale_shared_league_bundles_skipped === 2,
    "The older stale-absence collection was not skipped at the shared watermark."
  )

  const leagueRows = assertSucceeded(
    await identityA.client
      .from("leagues")
      .select("id, external_league_id, roster_bundle_fetched_at")
      .in("external_league_id", externalLeagueIds),
    "read collection watermarks"
  )
  const firstLeagueId = leagueRows.find(
    (row) => row.external_league_id === externalLeagueIds[0]
  )?.id
  assert(firstLeagueId, "The first concurrency league was not found.")
  assert(
    leagueRows.length === 2 &&
      leagueRows.every(
        (row) =>
          Date.parse(row.roster_bundle_fetched_at) ===
          Date.parse(staleAbsenceNewerAt)
      ),
    "An older collection reduced a complete shared bundle watermark."
  )
  const [removedUser, removedRoster, playerMapping, survivingRosterRow] =
    await Promise.all([
      identityA.client
        .from("league_users")
        .select("removed_at")
        .eq("league_id", firstLeagueId)
        .eq("external_user_id", identityB.externalUserId)
        .single(),
      identityA.client
        .from("rosters")
        .select("id, removed_at")
        .eq("league_id", firstLeagueId)
        .eq("external_roster_id", 2)
        .single(),
      identityA.client
        .from("player_external_ids")
        .select("player_id")
        .eq("namespace", "sleeper")
        .eq("sport", "nfl")
        .eq("external_id", "roster-0002")
        .single(),
      identityA.client
        .from("rosters")
        .select("id")
        .eq("league_id", firstLeagueId)
        .eq("external_roster_id", 1)
        .single(),
    ])
  assertSucceeded(removedUser, "read stale-absence user")
  assertSucceeded(removedRoster, "read stale-absence roster")
  assertSucceeded(playerMapping, "read stale-absence player mapping")
  assertSucceeded(survivingRosterRow, "read stale-absence surviving roster")
  const removedMembership = assertSucceeded(
    await identityA.client
      .from("roster_players")
      .select("removed_at")
      .eq("roster_id", survivingRosterRow.data.id)
      .eq("player_id", playerMapping.data.player_id)
      .single(),
    "read stale-absence membership"
  )
  assert(
    removedUser.data.removed_at !== null &&
      removedRoster.data.removed_at !== null &&
      removedMembership.removed_at !== null,
    "An older complete collection resurrected a user, roster, or membership that newer absence removed."
  )
  const [
    staleOnlyUser,
    staleOnlyRoster,
    staleOnlyRosterMapping,
    staleOnlyMembershipMapping,
  ] = await Promise.all([
    identityA.client
      .from("league_users")
      .select("id")
      .eq("league_id", firstLeagueId)
      .eq("external_user_id", staleOnlyUserId)
      .maybeSingle(),
    identityA.client
      .from("rosters")
      .select("id")
      .eq("league_id", firstLeagueId)
      .eq("external_roster_id", 3)
      .maybeSingle(),
    identityA.client
      .from("player_external_ids")
      .select("id")
      .eq("namespace", "sleeper")
      .eq("sport", "nfl")
      .eq("external_id", staleOnlyRosterPlayerId)
      .maybeSingle(),
    identityA.client
      .from("player_external_ids")
      .select("id")
      .eq("namespace", "sleeper")
      .eq("sport", "nfl")
      .eq("external_id", staleOnlyMembershipPlayerId)
      .maybeSingle(),
  ])
  assertSucceeded(staleOnlyUser, "read never-created stale user")
  assertSucceeded(staleOnlyRoster, "read never-created stale roster")
  assertSucceeded(
    staleOnlyRosterMapping,
    "read never-created stale roster mapping"
  )
  assertSucceeded(
    staleOnlyMembershipMapping,
    "read never-created stale membership mapping"
  )
  assert(
    staleOnlyUser.data === null &&
      staleOnlyRoster.data === null &&
      staleOnlyRosterMapping.data === null &&
      staleOnlyMembershipMapping.data === null,
    "An older complete collection created a stale-only user, roster, membership, or sparse player mapping."
  )

  const ownershipForB = assertSucceeded(
    await identityB.client
      .from("fantasy_account_rosters")
      .select("id, league_id")
      .eq("fantasy_account_id", identityB.accountId)
      .is("removed_at", null),
    "read account B ownership before account A state races"
  )

  function withoutAccountOwnership(values, unresolved) {
    for (const value of values) {
      value.rosters[0].owner_external_user_id = `untracked-${value.external_league_id}`
      for (const roster of value.rosters) {
        roster.co_owner_external_user_ids = unresolved ? null : []
      }
    }
    return values
  }

  async function readOwnershipStates(identity, label) {
    return assertSucceeded(
      await identity.client
        .from("fantasy_account_leagues")
        .select(
          "league_id, roster_ownership_status, roster_ownership_observed_at"
        )
        .eq("fantasy_account_id", identity.accountId)
        .is("removed_at", null),
      label
    )
  }

  const notOwnedNewerAt = "2099-02-06T00:00:00.000Z"
  const notOwnedOlderAt = "2099-02-05T00:00:00.000Z"
  const notOwnedNewerStart = await startAndStage(
    identityA,
    "not-owned newer",
    withoutAccountOwnership(
      bundleSet(notOwnedNewerAt, "not-owned-newer"),
      false
    )
  )
  const notOwnedNewerCompletion = await completePrepared(
    identityA,
    notOwnedNewerStart,
    "not-owned newer"
  )
  const notOwnedOlderStart = await startAndStage(
    identityA,
    "not-owned older positive",
    bundleSet(notOwnedOlderAt, "not-owned-older-positive")
  )
  const notOwnedOlderCompletion = await completePrepared(
    identityA,
    notOwnedOlderStart,
    "not-owned older positive"
  )
  const notOwnedStates = await readOwnershipStates(
    identityA,
    "read not-owned state"
  )
  assert(
    notOwnedNewerCompletion.final_status === "succeeded" &&
      notOwnedNewerCompletion.confirmed_not_owned_leagues === 2 &&
      notOwnedNewerCompletion.active_owned_rosters === 0 &&
      notOwnedOlderCompletion.final_status === "succeeded" &&
      notOwnedOlderCompletion.stale_shared_league_bundles_skipped === 2 &&
      notOwnedOlderCompletion.confirmed_not_owned_leagues === 2 &&
      notOwnedStates.length === 2 &&
      notOwnedStates.every(
        (row) =>
          row.roster_ownership_status === "not_owned" &&
          Date.parse(row.roster_ownership_observed_at) ===
            Date.parse(notOwnedNewerAt)
      ),
    "An older positive bundle overwrote newer confirmed not-owned truth."
  )

  const unresolvedNewerAt = "2099-02-08T00:00:00.000Z"
  const unresolvedOlderAt = "2099-02-07T00:00:00.000Z"
  const unresolvedNewerStart = await startAndStage(
    identityA,
    "unresolved newer",
    withoutAccountOwnership(
      bundleSet(unresolvedNewerAt, "unresolved-newer"),
      true
    )
  )
  const unresolvedNewerCompletion = await completePrepared(
    identityA,
    unresolvedNewerStart,
    "unresolved newer"
  )
  const unresolvedOlderStart = await startAndStage(
    identityA,
    "unresolved older positive",
    bundleSet(unresolvedOlderAt, "unresolved-older-positive")
  )
  const unresolvedOlderCompletion = await completePrepared(
    identityA,
    unresolvedOlderStart,
    "unresolved older positive"
  )
  const unresolvedStates = await readOwnershipStates(
    identityA,
    "read unresolved state"
  )
  assert(
    unresolvedNewerCompletion.final_status === "partial" &&
      unresolvedNewerCompletion.unresolved_ownership_leagues === 2 &&
      unresolvedNewerCompletion.active_owned_rosters === 0 &&
      unresolvedOlderCompletion.final_status === "partial" &&
      unresolvedOlderCompletion.stale_shared_league_bundles_skipped === 2 &&
      unresolvedOlderCompletion.unresolved_ownership_leagues === 2 &&
      unresolvedStates.length === 2 &&
      unresolvedStates.every(
        (row) =>
          row.roster_ownership_status === "unresolved" &&
          Date.parse(row.roster_ownership_observed_at) ===
            Date.parse(unresolvedNewerAt)
      ),
    "An older positive bundle overwrote newer unresolved ownership truth."
  )

  const confirmedRecoveryAt = "2099-02-09T00:00:00.000Z"
  const confirmedRecoveryStart = await startAndStage(
    identityA,
    "newer confirmed ownership recovery",
    bundleSet(confirmedRecoveryAt, "confirmed-recovery")
  )
  const confirmedRecoveryCompletion = await completePrepared(
    identityA,
    confirmedRecoveryStart,
    "newer confirmed ownership recovery"
  )
  const [confirmedStates, ownershipAfterA, ownershipAfterB] = await Promise.all(
    [
      readOwnershipStates(identityA, "read confirmed ownership recovery"),
      identityA.client
        .from("fantasy_account_rosters")
        .select("id", { count: "exact", head: true })
        .eq("fantasy_account_id", identityA.accountId)
        .is("removed_at", null),
      identityB.client
        .from("fantasy_account_rosters")
        .select("id, league_id")
        .eq("fantasy_account_id", identityB.accountId)
        .is("removed_at", null),
    ]
  )
  assertSucceeded(ownershipAfterA, "count account A ownership after recovery")
  const ownershipRowsAfterB = assertSucceeded(
    ownershipAfterB,
    "read account B ownership after account A state races"
  )
  assert(
    confirmedRecoveryCompletion.final_status === "succeeded" &&
      confirmedRecoveryCompletion.owned_leagues === 2 &&
      confirmedRecoveryCompletion.active_owned_rosters === 2 &&
      confirmedStates.length === 2 &&
      confirmedStates.every(
        (row) =>
          row.roster_ownership_status === "owned" &&
          Date.parse(row.roster_ownership_observed_at) ===
            Date.parse(confirmedRecoveryAt)
      ) &&
      ownershipAfterA.count === 2,
    "A later newer confirmed collection did not restore owned state."
  )
  assert(
    ownershipRowsAfterB.length === ownershipForB.length &&
      ownershipRowsAfterB.every((row) =>
        ownershipForB.some(
          (before) => before.id === row.id && before.league_id === row.league_id
        )
      ),
    "Account A ownership resolution mutated account B ownership."
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
  assert(
    privateDump.status === 0,
    "Private roster staging verification failed."
  )
  assert(
    completedRunIds.every((runId) => !privateDump.stdout.includes(runId)),
    "A completed roster run retained private stage state."
  )

  console.log(
    `Roster concurrency test passed: same-resource, stale-absence, newer not-owned, newer unresolved, and later confirmed ownership scenarios across 2 accounts and 2 leagues; ${completedRunIds.length} terminal runs, ${Date.now() - startedAt}ms.`
  )
}

await withTimeout(run(), overallTimeoutMs, "Roster concurrency test")
