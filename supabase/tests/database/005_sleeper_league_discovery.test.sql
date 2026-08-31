begin;

select plan(84);

select has_column(
  'public', 'leagues', 'fetched_at',
  'leagues record the provider fetch time'
);
select col_not_null(
  'public', 'leagues', 'fetched_at',
  'league fetch time is required'
);
select col_is_null(
  'public', 'leagues', 'provider_updated_at',
  'provider update time is nullable when Sleeper does not publish one'
);

select is(
  (
    select count(*)::integer
    from (values
      ('public.provider_season_states'),
      ('public.leagues'),
      ('public.fantasy_account_leagues'),
      ('public.sync_runs')
    ) as provider_table(name)
    where has_table_privilege('service_role', provider_table.name, 'select')
      or has_table_privilege('service_role', provider_table.name, 'insert')
      or has_table_privilege('service_role', provider_table.name, 'update')
      or has_table_privilege('service_role', provider_table.name, 'delete')
  ),
  0,
  'service_role has no direct CRUD on provider-data tables'
);

select has_function(
  'public', 'start_sleeper_league_discovery', array['uuid', 'uuid'],
  'start function exists'
);
select ok(
  (select prosecdef from pg_proc where oid =
    'public.start_sleeper_league_discovery(uuid,uuid)'::regprocedure),
  'start function is SECURITY DEFINER'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog'] from pg_proc where oid =
    'public.start_sleeper_league_discovery(uuid,uuid)'::regprocedure),
  'start function fixes its search path'
);
select ok(
  not exists (
    select 1
    from pg_proc as procedure
    cross join lateral aclexplode(procedure.proacl) as acl
    where procedure.oid =
      'public.start_sleeper_league_discovery(uuid,uuid)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute start'
);
select is(
  has_function_privilege('anon', 'public.start_sleeper_league_discovery(uuid,uuid)', 'execute'),
  false,
  'anon cannot execute start'
);
select is(
  has_function_privilege('authenticated', 'public.start_sleeper_league_discovery(uuid,uuid)', 'execute'),
  false,
  'authenticated cannot execute start'
);
select is(
  has_function_privilege('service_role', 'public.start_sleeper_league_discovery(uuid,uuid)', 'execute'),
  true,
  'service_role can execute start'
);
select is(
  has_function_privilege('postgres', 'public.start_sleeper_league_discovery(uuid,uuid)', 'execute'),
  true,
  'postgres can execute start'
);

select has_function(
  'public', 'complete_sleeper_league_discovery',
  array['uuid', 'uuid', 'uuid', 'jsonb', 'jsonb'],
  'complete function exists'
);
select ok(
  (select prosecdef from pg_proc where oid =
    'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure),
  'complete function is SECURITY DEFINER'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog'] from pg_proc where oid =
    'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure),
  'complete function fixes its search path'
);
select ok(
  not exists (
    select 1
    from pg_proc as procedure
    cross join lateral aclexplode(procedure.proacl) as acl
    where procedure.oid =
      'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute complete'
);
select is(
  has_function_privilege('anon', 'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)', 'execute'),
  false,
  'anon cannot execute complete'
);
select is(
  has_function_privilege('authenticated', 'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)', 'execute'),
  false,
  'authenticated cannot execute complete'
);
select is(
  has_function_privilege('service_role', 'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)', 'execute'),
  true,
  'service_role can execute complete'
);
select is(
  has_function_privilege('postgres', 'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)', 'execute'),
  true,
  'postgres can execute complete'
);

select has_function(
  'public', 'fail_sleeper_league_discovery',
  array['uuid', 'uuid', 'uuid', 'text', 'text', 'boolean'],
  'fail function exists'
);
select ok(
  (select prosecdef from pg_proc where oid =
    'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)'::regprocedure),
  'fail function is SECURITY DEFINER'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog'] from pg_proc where oid =
    'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)'::regprocedure),
  'fail function fixes its search path'
);
select ok(
  not exists (
    select 1
    from pg_proc as procedure
    cross join lateral aclexplode(procedure.proacl) as acl
    where procedure.oid =
      'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute fail'
);
select is(
  has_function_privilege('anon', 'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)', 'execute'),
  false,
  'anon cannot execute fail'
);
select is(
  has_function_privilege('authenticated', 'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)', 'execute'),
  false,
  'authenticated cannot execute fail'
);
select is(
  has_function_privilege('service_role', 'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)', 'execute'),
  true,
  'service_role can execute fail'
);
select is(
  has_function_privilege('postgres', 'public.fail_sleeper_league_discovery(uuid,uuid,uuid,text,text,boolean)', 'execute'),
  true,
  'postgres can execute fail'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'task006-a@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'task006-b@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'task006-unlinked@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
)
values
  (
    '61000000-0000-0000-0000-000000000001', 'sleeper',
    'fixture-user-a', 'FixtureA', 'fixturea', '{}'::jsonb, now()
  ),
  (
    '61000000-0000-0000-0000-000000000002', 'espn',
    'fixture-user-espn', 'FixtureEspn', 'fixtureespn', '{}'::jsonb, now()
  ),
  (
    '61000000-0000-0000-0000-000000000003', 'sleeper',
    'fixture-user-b', 'FixtureB', 'fixtureb', '{}'::jsonb, now()
  );

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001', true
  ),
  (
    '60000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002', false
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    '61000000-0000-0000-0000-000000000003', true
  );

select throws_ok(
  $$
    select * from public.start_sleeper_league_discovery(
      '60000000-0000-0000-0000-000000000003',
      '61000000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  'The app user is not linked to this fantasy account.',
  'an unlinked app user cannot start discovery'
);
select throws_ok(
  $$
    select * from public.start_sleeper_league_discovery(
      '60000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002'
    )
  $$,
  '22023',
  'League discovery requires a Sleeper fantasy account.',
  'a linked account for another provider is rejected'
);

create temporary table first_start as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
create temporary table repeated_start as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

select results_eq(
  $$ select created_run, reused_run, recovered_stale_run from first_start $$,
  $$ values (true, false, false) $$,
  'the first start creates a run'
);
select results_eq(
  $$ select created_run, reused_run, recovered_stale_run from repeated_start $$,
  $$ values (false, true, false) $$,
  'an immediate repeat reuses the fresh run'
);
select is(
  (select sync_run_id from first_start),
  (select sync_run_id from repeated_start),
  'the reused run has the same ID'
);
select is(
  (
    select count(*)::integer from public.sync_runs
    where fantasy_account_id = '61000000-0000-0000-0000-000000000001'
      and status = 'running'
  ),
  1,
  'there is no duplicate running run'
);
select is(
  (select status from public.sync_runs where id = (select sync_run_id from first_start)),
  'running',
  'a fresh reused run is not failed'
);

create temporary table other_account_start as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000003'
);

-- The production updated_at trigger intentionally refreshes the heartbeat on
-- every update. Disable user triggers only for this fixture mutation so the
-- test can model a worker that stopped six minutes ago.
set local session_replication_role = replica;

update public.sync_runs
set updated_at = now() - interval '6 minutes'
where id = (select sync_run_id from first_start);

set local session_replication_role = origin;

create temporary table recovered_start as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

select results_eq(
  $$ select created_run, reused_run, recovered_stale_run from recovered_start $$,
  $$ values (true, false, true) $$,
  'a stale run is recovered before replacement'
);
select is(
  (select status from public.sync_runs where id = (select sync_run_id from first_start)),
  'failed',
  'the stale run becomes terminal'
);
select is(
  (select error_summary ->> 'code' from public.sync_runs where id = (select sync_run_id from first_start)),
  'stale_run_timeout',
  'stale recovery stores a bounded error code'
);
select is(
  (select error_summary ->> 'stage' from public.sync_runs where id = (select sync_run_id from first_start)),
  'league_discovery',
  'stale recovery stores only the discovery stage'
);
select isnt(
  (select sync_run_id from recovered_start),
  (select sync_run_id from first_start),
  'stale recovery creates a replacement ID'
);
select is(
  (select status from public.sync_runs where id = (select sync_run_id from other_account_start)),
  'running',
  'another fantasy account is unaffected by stale recovery'
);

create temporary table initial_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from recovered_start),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":1,"leg":1,"display_week":1,"season_start_date":"2026-09-10","provider_metadata":{"display_week":1},"fetched_at":"2026-08-31T08:30:00.000Z"}'::jsonb,
  '[
    {"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Fixture Dynasty","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2,"best_ball":0},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{"draft_id":"fixture-draft-a"},"provider_updated_at":null,"fetched_at":"2026-08-31T08:30:00.000Z"},
    {"external_league_id":"fixture-league-b","sport":"nfl","season":2026,"name":"Fixture Best Ball","status":"in_season","season_type":"regular","team_count":10,"roster_size":4,"roster_management_type":"redraft","is_best_ball":true,"has_superflex":false,"has_idp":false,"scoring_format":"half_ppr","avatar_id":"fixture-avatar","avatar_url":"https://sleepercdn.com/avatars/fixture-avatar","previous_external_league_id":"fixture-previous","settings":{"type":0,"best_ball":1},"scoring_settings":{"rec":0.5},"roster_positions":["QB","RB","WR","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:30:00.000Z"}
  ]'::jsonb
);

select is(
  (select league_season from public.provider_season_states where provider = 'sleeper' and sport = 'nfl'),
  2026,
  'valid provider state is inserted'
);
select is(
  (select count(*)::integer from public.leagues where provider = 'sleeper'),
  2,
  'valid shared leagues are inserted'
);
select is(
  (select count(*)::integer from public.fantasy_account_leagues where fantasy_account_id = '61000000-0000-0000-0000-000000000001'),
  2,
  'discovery associations are inserted'
);
select is(
  (select settings from public.leagues where external_league_id = 'fixture-league-a'),
  '{"type":2,"best_ball":0}'::jsonb,
  'exact settings survive persistence'
);
select is(
  (select scoring_settings from public.leagues where external_league_id = 'fixture-league-b'),
  '{"rec":0.5}'::jsonb,
  'exact scoring settings survive persistence'
);
select is(
  (select roster_positions from public.leagues where external_league_id = 'fixture-league-a'),
  '["QB","RB","WR","SUPER_FLEX","BN"]'::jsonb,
  'ordered roster positions survive persistence'
);
select is(
  (select fetched_at from public.leagues where external_league_id = 'fixture-league-a'),
  '2026-08-31 08:30:00+00'::timestamptz,
  'league fetch time is stored'
);
select is(
  (select provider_updated_at from public.leagues where external_league_id = 'fixture-league-a'),
  null::timestamptz,
  'provider update time remains null when unavailable'
);
select results_eq(
  $$
    select observed_leagues, created_leagues, updated_leagues,
      created_associations, reactivated_associations,
      removed_associations, active_associations
    from initial_completion
  $$,
  $$ values (2, 2, 0, 2, 0, 0, 2) $$,
  'initial result counts are accurate'
);
select is(
  (select last_synced_at from public.fantasy_accounts where id = '61000000-0000-0000-0000-000000000001'),
  null::timestamptz,
  'league discovery does not claim a full account sync'
);

create temporary table first_seen_before as
select league_id, first_seen_at
from public.fantasy_account_leagues
where fantasy_account_id = '61000000-0000-0000-0000-000000000001';

create temporary table repeat_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from repeat_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":1,"leg":1,"display_week":1,"season_start_date":"2026-09-10","provider_metadata":{},"fetched_at":"2026-08-31T08:31:00.000Z"}'::jsonb,
  '[
    {"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Fixture Dynasty Updated","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2,"best_ball":0,"waiver_type":2},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:31:00.000Z"},
    {"external_league_id":"fixture-league-b","sport":"nfl","season":2026,"name":"Fixture Best Ball","status":"in_season","season_type":"regular","team_count":10,"roster_size":4,"roster_management_type":"redraft","is_best_ball":true,"has_superflex":false,"has_idp":false,"scoring_format":"half_ppr","avatar_id":"fixture-avatar","avatar_url":"https://sleepercdn.com/avatars/fixture-avatar","previous_external_league_id":"fixture-previous","settings":{"type":0,"best_ball":1},"scoring_settings":{"rec":0.5},"roster_positions":["QB","RB","WR","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:31:00.000Z"}
  ]'::jsonb
);

select is(
  (select count(*)::integer from public.leagues where provider = 'sleeper'),
  2,
  'repeat import creates no duplicate shared leagues'
);
select is(
  (select name from public.leagues where external_league_id = 'fixture-league-a'),
  'Fixture Dynasty Updated',
  'changed source fields update the canonical league'
);
select is(
  (select settings ->> 'waiver_type' from public.leagues where external_league_id = 'fixture-league-a'),
  '2',
  'changed exact settings update the canonical league'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_leagues as association
    inner join first_seen_before as prior using (league_id)
    where association.fantasy_account_id = '61000000-0000-0000-0000-000000000001'
      and association.first_seen_at = prior.first_seen_at
  ),
  2,
  'repeat import preserves first-seen timestamps'
);

insert into public.fantasy_account_leagues (
  fantasy_account_id, league_id, first_seen_at, last_seen_at
)
select
  '61000000-0000-0000-0000-000000000003', id, now(), now()
from public.leagues
where external_league_id = 'fixture-league-b';

create temporary table shrink_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
create temporary table shrink_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from shrink_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":1,"leg":1,"display_week":1,"season_start_date":"2026-09-10","provider_metadata":{},"fetched_at":"2026-08-31T08:32:00.000Z"}'::jsonb,
  '[{"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Fixture Dynasty Updated","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:32:00.000Z"}]'::jsonb
);

select is(
  (select removed_associations from shrink_completion),
  1,
  'an absent active association is reconciled as removed'
);
select ok(
  (
    select removed_at >= last_seen_at
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id = '61000000-0000-0000-0000-000000000001'
      and league.external_league_id = 'fixture-league-b'
  ),
  'removal occurs at or after the last positive observation'
);
select is(
  (select count(*)::integer from public.leagues where external_league_id = 'fixture-league-b'),
  1,
  'a removed association never deletes the shared league'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id = '61000000-0000-0000-0000-000000000003'
      and association.removed_at is null
      and league.external_league_id = 'fixture-league-b'
  ),
  1,
  'another account association remains active'
);

create temporary table reappear_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
create temporary table reappear_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from reappear_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":1,"leg":1,"display_week":1,"season_start_date":"2026-09-10","provider_metadata":{},"fetched_at":"2026-08-31T08:33:00.000Z"}'::jsonb,
  '[
    {"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Fixture Dynasty Updated","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:33:00.000Z"},
    {"external_league_id":"fixture-league-b","sport":"nfl","season":2026,"name":"Fixture Best Ball","status":"in_season","season_type":"regular","team_count":10,"roster_size":4,"roster_management_type":"redraft","is_best_ball":true,"has_superflex":false,"has_idp":false,"scoring_format":"half_ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":0,"best_ball":1},"scoring_settings":{"rec":0.5},"roster_positions":["QB","RB","WR","BN"],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:33:00.000Z"}
  ]'::jsonb
);

select is(
  (select reactivated_associations from reappear_completion),
  1,
  'a reappearing league is counted as reactivated'
);
select is(
  (
    select removed_at
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id = '61000000-0000-0000-0000-000000000001'
      and league.external_league_id = 'fixture-league-b'
  ),
  null::timestamptz,
  'reappearance clears the removal timestamp'
);

create temporary table empty_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
create temporary table empty_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from empty_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":1,"leg":1,"display_week":1,"season_start_date":"2026-09-10","provider_metadata":{},"fetched_at":"2026-08-31T08:34:00.000Z"}'::jsonb,
  '[]'::jsonb
);

select results_eq(
  $$ select observed_leagues, removed_associations, active_associations from empty_completion $$,
  $$ values (0, 2, 0) $$,
  'an empty validated collection succeeds and reconciles to zero active leagues'
);

create temporary table newer_shared_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
create temporary table newer_shared_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from newer_shared_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":9,"leg":9,"display_week":9,"season_start_date":"2026-09-10","provider_metadata":{"freshness":"newer"},"fetched_at":"2026-08-31T08:40:00.000Z"}'::jsonb,
  '[{"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Newest Shared League","status":"in_season","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2,"freshness":"newer"},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{"freshness":"newer"},"provider_updated_at":"2026-08-31T08:39:00.000Z","fetched_at":"2026-08-31T08:40:00.000Z"}]'::jsonb
);

select results_eq(
  $$
    select provider_state_applied, provider_state_stale_skipped,
      stale_shared_leagues_skipped
    from newer_shared_completion
  $$,
  $$ values (true, false, 0) $$,
  'a newer completion reports applied shared state'
);

create temporary table older_shared_completion as
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000003',
  (select sync_run_id from other_account_start),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":8,"leg":8,"display_week":8,"season_start_date":"2026-09-10","provider_metadata":{"freshness":"older"},"fetched_at":"2026-08-31T08:35:00.000Z"}'::jsonb,
  '[{"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Older Shared League","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2,"freshness":"older"},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{"freshness":"older"},"provider_updated_at":null,"fetched_at":"2026-08-31T08:35:00.000Z"}]'::jsonb
);

select is(
  (select week from public.provider_season_states where provider = 'sleeper' and sport = 'nfl'),
  9,
  'an older completion does not regress provider season fields'
);
select is(
  (select provider_metadata ->> 'freshness' from public.provider_season_states where provider = 'sleeper' and sport = 'nfl'),
  'newer',
  'an older completion does not regress provider season metadata'
);
select is(
  (select fetched_at from public.provider_season_states where provider = 'sleeper' and sport = 'nfl'),
  '2026-08-31 08:40:00+00'::timestamptz,
  'provider season fetch time remains monotonic'
);
select is(
  (select name from public.leagues where external_league_id = 'fixture-league-a'),
  'Newest Shared League',
  'an older league observation does not regress mutable fields'
);
select is(
  (select settings ->> 'freshness' from public.leagues where external_league_id = 'fixture-league-a'),
  'newer',
  'an older league observation does not regress exact settings'
);
select is(
  (select fetched_at from public.leagues where external_league_id = 'fixture-league-a'),
  '2026-08-31 08:40:00+00'::timestamptz,
  'shared league fetch time remains monotonic'
);
select is(
  (select provider_updated_at from public.leagues where external_league_id = 'fixture-league-a'),
  '2026-08-31 08:39:00+00'::timestamptz,
  'a stale null provider timestamp does not erase a reliable timestamp'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id = '61000000-0000-0000-0000-000000000003'
      and league.external_league_id = 'fixture-league-a'
      and association.removed_at is null
  ),
  1,
  'a stale shared observation still creates the importing account association'
);
select results_eq(
  $$
    select updated_leagues, stale_shared_leagues_skipped,
      created_associations, provider_state_applied,
      provider_state_stale_skipped
    from older_shared_completion
  $$,
  $$ values (0, 1, 1, false, true) $$,
  'stale shared representations are counted separately from updates'
);
select results_eq(
  $$
    select
      (result_counts ->> 'stale_shared_leagues_skipped')::integer,
      (result_counts ->> 'provider_state_applied')::boolean,
      (result_counts ->> 'provider_state_stale_skipped')::boolean
    from public.sync_runs
    where id = (select sync_run_id from other_account_start)
  $$,
  $$ values (1, false, true) $$,
  'the sync run records bounded freshness outcomes'
);
select results_eq(
  $$
    select status
    from public.sync_runs
    where id in (
      (select sync_run_id from newer_shared_run),
      (select sync_run_id from other_account_start)
    )
    order by status
  $$,
  $$ values ('succeeded'::text), ('succeeded'::text) $$,
  'newer and stale importing runs both succeed'
);

create temporary table accepted_null_provider_time_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
select * from public.complete_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from accepted_null_provider_time_run),
  '{"season":2026,"league_season":2026,"league_create_season":2027,"previous_season":2025,"season_type":"regular","week":10,"leg":10,"display_week":10,"season_start_date":"2026-09-10","provider_metadata":{"freshness":"newest"},"fetched_at":"2026-08-31T08:41:00.000Z"}'::jsonb,
  '[{"external_league_id":"fixture-league-a","sport":"nfl","season":2026,"name":"Accepted Null Provider Time","status":"in_season","season_type":"regular","team_count":12,"roster_size":5,"roster_management_type":"dynasty","is_best_ball":false,"has_superflex":true,"has_idp":false,"scoring_format":"ppr","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{"type":2,"freshness":"newest"},"scoring_settings":{"rec":1},"roster_positions":["QB","RB","WR","SUPER_FLEX","BN"],"provider_metadata":{"freshness":"newest"},"provider_updated_at":null,"fetched_at":"2026-08-31T08:41:00.000Z"}]'::jsonb
);
select is(
  (select provider_updated_at from public.leagues where external_league_id = 'fixture-league-a'),
  '2026-08-31 08:39:00+00'::timestamptz,
  'an accepted newer observation with null provider time preserves the reliable timestamp'
);

create temporary table invalid_run as
select * from public.start_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_league_discovery(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        %L::uuid,
        '{"season":2026,"league_season":2026,"league_create_season":null,"previous_season":null,"season_type":"regular","week":null,"leg":null,"display_week":null,"season_start_date":null,"provider_metadata":{},"fetched_at":"2026-08-31T08:35:00.000Z"}'::jsonb,
        '[{"external_league_id":"duplicate","sport":"nfl","season":2026,"name":"Duplicate","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":0,"roster_management_type":"unknown","is_best_ball":false,"has_superflex":false,"has_idp":false,"scoring_format":"unknown","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{},"scoring_settings":{},"roster_positions":[],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:35:00.000Z"},{"external_league_id":"duplicate","sport":"nfl","season":2026,"name":"Duplicate","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":0,"roster_management_type":"unknown","is_best_ball":false,"has_superflex":false,"has_idp":false,"scoring_format":"unknown","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{},"scoring_settings":{},"roster_positions":[],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:35:00.000Z"}]'::jsonb
      )
    $sql$,
    (select sync_run_id from invalid_run)
  ),
  '22023',
  'The normalized league collection contains duplicate IDs.',
  'duplicate league IDs reject the whole completion'
);
select is(
  (select count(*)::integer from public.leagues where external_league_id = 'duplicate'),
  0,
  'duplicate rejection writes no partial league'
);
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_league_discovery(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        %L::uuid,
        '{"season":2026,"league_season":2026,"league_create_season":null,"previous_season":null,"season_type":"regular","week":null,"leg":null,"display_week":null,"season_start_date":null,"provider_metadata":{},"fetched_at":"2026-08-31T08:35:00.000Z"}'::jsonb,
        '[{"external_league_id":"wrong-season","sport":"nfl","season":2025,"name":"Wrong Season","status":"pre_draft","season_type":"regular","team_count":12,"roster_size":0,"roster_management_type":"unknown","is_best_ball":false,"has_superflex":false,"has_idp":false,"scoring_format":"unknown","avatar_id":null,"avatar_url":null,"previous_external_league_id":null,"settings":{},"scoring_settings":{},"roster_positions":[],"provider_metadata":{},"provider_updated_at":null,"fetched_at":"2026-08-31T08:35:00.000Z"}]'::jsonb
      )
    $sql$,
    (select sync_run_id from invalid_run)
  ),
  '22023',
  'A normalized league failed validation.',
  'wrong-season league IDs reject the whole completion'
);
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_league_discovery(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000002',
        %L::uuid,
        '{}'::jsonb,
        '[]'::jsonb
      )
    $sql$,
    (select sync_run_id from invalid_run)
  ),
  '22023',
  'League discovery requires a Sleeper fantasy account.',
  'cross-provider account context is rejected'
);

create temporary table failed_run as
select * from public.fail_sleeper_league_discovery(
  '60000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  (select sync_run_id from invalid_run),
  'invalid_source_response',
  'Sleeper returned an unexpected league response. Try again.',
  true
);

select results_eq(
  $$ select status, changed_run from failed_run $$,
  $$ values ('failed'::text, true) $$,
  'failure makes a running run terminal'
);
select is(
  (
    select error_summary
    from public.sync_runs
    where id = (select sync_run_id from invalid_run)
  ),
  '{"code":"invalid_source_response","message":"Sleeper returned an unexpected league response. Try again.","retryable":true,"stage":"league_discovery"}'::jsonb,
  'failure stores only bounded safe metadata'
);
select is(
  (select count(*)::integer from public.leagues where provider = 'sleeper'),
  2,
  'failure preserves previously successful shared data'
);
select results_eq(
  format(
    $$
      select status, changed_run
      from public.fail_sleeper_league_discovery(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        %L::uuid,
        'ignored', 'Ignored terminal retry.', false
      )
    $$,
    (select sync_run_id from invalid_run)
  ),
  $$ values ('failed'::text, false) $$,
  'repeated failure is a documented idempotent terminal result'
);
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_league_discovery(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        %L::uuid,
        '{"season":2026,"league_season":2026,"league_create_season":null,"previous_season":null,"season_type":"regular","week":null,"leg":null,"display_week":null,"season_start_date":null,"provider_metadata":{},"fetched_at":"2026-08-31T08:36:00.000Z"}'::jsonb,
        '[]'::jsonb
      )
    $sql$,
    (select sync_run_id from invalid_run)
  ),
  '55000',
  'A terminal league-discovery run cannot be completed.',
  'a terminal run cannot be completed again'
);

select * from finish();

rollback;
