import { spawn } from "node:child_process"
import { randomUUID } from "node:crypto"
import assert from "node:assert/strict"

// Fixture-only SQL: this command can reach only the repository's local Docker database.
const container = "supabase_db_fantasyhud"
const timeout = setTimeout(() => {
  console.error("Draft integration checks exceeded 180 seconds.")
  process.exit(1)
}, 180_000)
const quote = (value) => `'${String(value).replaceAll("'", "''")}'`
const json = (value) => `${quote(JSON.stringify(value))}::jsonb`
function sql(statement) {
  return new Promise((resolve, reject) => {
    const child = spawn(
      "docker",
      [
        "exec",
        "-i",
        container,
        "psql",
        "-U",
        "postgres",
        "-d",
        "postgres",
        "-qAt",
        "-v",
        "ON_ERROR_STOP=1",
      ],
      { stdio: ["pipe", "pipe", "pipe"] }
    )
    let output = "",
      error = ""
    const deadline = setTimeout(() => {
      child.kill("SIGKILL")
      reject(new Error("Draft SQL exceeded 65 seconds."))
    }, 65_000)
    child.stdout.on("data", (bytes) => {
      output += bytes
    })
    child.stderr.on("data", (bytes) => {
      error += bytes
    })
    child.on("error", (error) => {
      clearTimeout(deadline)
      reject(error)
    })
    child.on("exit", (code) => {
      clearTimeout(deadline)
      if (code !== 0) reject(new Error(error || `psql exited ${code}`))
      else
        resolve(
          output.trim() ? JSON.parse(output.trim().split("\n").at(-1)) : null
        )
    })
    child.stdin.end(statement)
  })
}
async function seed(externalUser, leagueIds, teams = 2, rounds = 1) {
  const actor = { userId: randomUUID(), accountId: randomUUID(), externalUser }
  await sql(`
    insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
    values(${quote(actor.userId)},'authenticated','authenticated',${quote(`${actor.userId}@example.test`)},'{}','{}',clock_timestamp(),clock_timestamp());
    insert into public.fantasy_accounts(id,provider,external_user_id,username,normalized_username)
    values(${quote(actor.accountId)},'sleeper',${quote(externalUser)},${quote(externalUser)},${quote(externalUser)});
    insert into public.user_fantasy_accounts(user_id,fantasy_account_id,is_primary) values(${quote(actor.userId)},${quote(actor.accountId)},true);
    insert into public.provider_season_states(provider,sport,season,league_season,season_type,fetched_at)
    values('sleeper','nfl',2026,2026,'regular',clock_timestamp()) on conflict(provider,sport) do update set league_season=2026;
    ${leagueIds
      .map(
        (id) => `
      insert into public.leagues(provider,external_league_id,sport,season,name,status,season_type,team_count,roster_size,roster_management_type,is_best_ball,has_superflex,has_idp,scoring_format,settings,scoring_settings,roster_positions,fetched_at)
      values('sleeper',${quote(id)},'nfl',2026,'Draft integration fixture','in_season','regular',${teams},${rounds},'redraft',false,false,false,'ppr','{}','{"rec":1}',${json(["RB", ...Array(Math.max(0, rounds - 1)).fill("BN")])},clock_timestamp()) on conflict(provider,external_league_id) do nothing;
      insert into public.fantasy_account_leagues(fantasy_account_id,league_id,first_seen_at,last_seen_at)
      select ${quote(actor.accountId)},id,clock_timestamp(),clock_timestamp() from public.leagues where provider='sleeper' and external_league_id=${quote(id)};
    `
      )
      .join("\n")}
  `)
  return actor
}
const actorArgs = (actor, run) =>
  `${quote(actor.userId)}::uuid,${quote(actor.accountId)}::uuid,${quote(run.runId)}::uuid`
const start = (actor) =>
  sql(
    `select public.start_sleeper_draft_sync(${quote(actor.userId)},${quote(actor.accountId)});`
  )
const complete = (actor, run) =>
  sql(`select public.complete_sleeper_draft_sync(${actorArgs(actor, run)});`)
function board(id, league, users, time, rounds = 1) {
  return {
    detailFetchedAt: time,
    boardFetchedAt: time,
    detail: {
      externalDraftId: id,
      externalLeagueId: league,
      season: 2026,
      seasonType: "regular",
      draftType: "linear",
      status: "complete",
      teamCount: users.length,
      roundCount: rounds,
      pickTimerSeconds: 120,
      settings: { teams: users.length, rounds, pick_timer: 120 },
      metadata: {},
      draftPoolType: "unknown",
      draftOrder: Object.fromEntries(users.map((u, i) => [u, i + 1])),
      slotToRoster: null,
      creators: null,
    },
    slots: users.map((u, i) => ({
      draftSlot: i + 1,
      sourceUserIds: [u],
      externalRosterId: null,
    })),
    picks: Array.from({ length: users.length * rounds }, (_, i) => ({
      pickNo: i + 1,
      round: Math.floor(i / users.length) + 1,
      draftSlot: (i % users.length) + 1,
      externalPlayerId: `draft-fixture-player-${i + 1}`,
      pickedBy: users[i % users.length],
      isKeeper: null,
      auctionAmount: null,
      entityType: "player",
      position: "RB",
      metadata: { audit_padding: "x".repeat(1024) },
      sourceMetadata: {},
    })),
  }
}
async function stage(actor, run, boards, time) {
  const payload = {
    version: "sleeper-draft-collection/v1",
    scope: {
      externalUserId: actor.externalUser,
      season: 2026,
      externalLeagueIds: run.externalLeagueIds,
    },
    userCollection: {
      externalDraftIds: boards.map((b) => b.detail.externalDraftId).sort(),
      sourceFetchedAt: time,
    },
    leagueCollections: run.externalLeagueIds.map((id) => ({
      externalLeagueId: id,
      externalDraftIds: boards
        .filter((b) => b.detail.externalLeagueId === id)
        .map((b) => b.detail.externalDraftId)
        .sort(),
      sourceFetchedAt: time,
    })),
  }
  await sql(
    `select public.stage_sleeper_draft_source(${actorArgs(actor, run)},'collections',${json(payload)});`
  )
  for (const b of boards)
    await sql(
      `select public.stage_sleeper_draft_source(${actorArgs(actor, run)},${quote(`draft:${b.detail.externalDraftId}`)},${json(b)});`
    )
}
try {
  const a = await seed("draft_fixture_a", ["draft-race-league"])
  const b = await seed("draft_fixture_b", ["draft-race-league"])
  const [ar, br] = await Promise.all([start(a), start(b)])
  const observed = await sql("select to_jsonb(clock_timestamp());")
  const shared = board(
    "draft-race-board",
    "draft-race-league",
    [a.externalUser, b.externalUser],
    observed
  )
  await Promise.all([
    stage(a, ar, [shared], observed),
    stage(b, br, [shared], observed),
  ])
  const results = await Promise.all([complete(a, ar), complete(b, br)])
  assert(
    results.every((r) => r.drafts === 1 && r.confirmedParticipations === 1)
  )
  const counts = await sql(
    "select jsonb_build_object('drafts',(select count(*) from public.drafts where external_draft_id='draft-race-board'),'picks',(select count(*) from public.draft_picks p join public.drafts d on d.id=p.draft_id where d.external_draft_id='draft-race-board'));"
  )
  assert.deepEqual(counts, { drafts: 1, picks: 2 })
  console.log(
    "Overlapping account imports converge on one board and two picks."
  )

  const c = await seed("draft_fixture_c", ["draft-race-league"])
  const cr = await start(c)
  const oldTime = await sql("select to_jsonb(clock_timestamp());")
  await stage(
    c,
    cr,
    [{ ...shared, detailFetchedAt: oldTime, boardFetchedAt: oldTime }],
    oldTime
  )
  const newer = await start(b)
  const newTime = await sql("select to_jsonb(clock_timestamp());")
  await stage(b, newer, [], newTime)
  await complete(b, newer)
  await assert.rejects(complete(c, cr), /invalid or stale/)
  const removed = await sql(
    "select to_jsonb(removed_at is not null) from public.drafts where external_draft_id='draft-race-board';"
  )
  assert.equal(removed, true)
  await sql(`select public.fail_sleeper_draft_sync(${actorArgs(c, cr)});`)
  console.log("An older inclusion cannot resurrect newer collection absence.")

  const outsideActor = await seed("draft_fixture_outside", [
    "draft-outside-league",
  ])
  const outsideRun = await start(outsideActor)
  const outsideTime = await sql("select to_jsonb(clock_timestamp());")
  await stage(
    outsideActor,
    outsideRun,
    [{ ...shared, detailFetchedAt: outsideTime, boardFetchedAt: outsideTime }],
    outsideTime
  )
  await complete(outsideActor, outsideRun)
  assert.equal(
    await sql(
      "select to_jsonb(removed_at is not null) from public.drafts where external_draft_id='draft-race-board';"
    ),
    true
  )
  console.log(
    "User draft history outside the frozen league set cannot clear league absence."
  )

  const leagueIds = Array.from(
    { length: 30 },
    (_, i) => `draft-load-${String(i + 1).padStart(2, "0")}`
  )
  const loadActor = await seed("draft_fixture_load", leagueIds, 12, 20)
  const loadRun = await start(loadActor)
  const loadTime = await sql("select to_jsonb(clock_timestamp());")
  const users = [
    loadActor.externalUser,
    ...Array.from({ length: 11 }, (_, i) => `draft_load_other_${i}`),
  ]
  const boards = leagueIds.map((id) =>
    board(`${id}-board`, id, users, loadTime, 20)
  )
  await stage(loadActor, loadRun, boards, loadTime)
  const started = performance.now()
  const loaded = await complete(loadActor, loadRun)
  const duration = performance.now() - started
  assert.equal(loaded.drafts, 30)
  assert.equal(loaded.finalizedBoards, 30)
  assert.equal(loaded.confirmedParticipations, 30)
  assert(duration < 60_000)
  const picks = await sql(
    "select to_jsonb(count(*)) from public.draft_picks p join public.drafts d on d.id=p.draft_id where d.external_draft_id like 'draft-load-%';"
  )
  assert.equal(picks, 7200)
  console.log(
    `30 leagues / 30 complete boards / 7,200 picks published in ${Math.round(duration)}ms.`
  )
} finally {
  clearTimeout(timeout)
}
