begin;

select plan(130);

select has_table(
  'app_private',
  'sleeper_roster_sync_scopes',
  'private frozen roster-sync scope exists'
);
select has_table(
  'app_private',
  'sleeper_roster_sync_stage',
  'private per-league roster-sync stage exists'
);
select has_column(
  'public',
  'leagues',
  'roster_bundle_fetched_at',
  'shared leagues retain the latest complete roster-bundle watermark'
);
select has_column(
  'public',
  'fantasy_account_leagues',
  'roster_ownership_status',
  'account-to-league discovery retains explicit roster ownership status'
);
select has_column(
  'public',
  'fantasy_account_leagues',
  'roster_ownership_observed_at',
  'account-to-league ownership status retains its observation watermark'
);
select has_index(
  'public',
  'fantasy_account_leagues',
  'fantasy_account_leagues_current_roster_ownership_idx',
  'current account ownership-status reads have a supporting index'
);
select is(
  (
    select pg_catalog.count(*)::integer
    from pg_catalog.pg_constraint as constraint_row
    where constraint_row.conrelid in (
      'public.leagues'::regclass,
      'public.fantasy_account_leagues'::regclass
    )
      and constraint_row.conname in (
        'leagues_roster_bundle_fetched_at_is_finite',
        'fantasy_account_leagues_roster_ownership_state_is_valid',
        'fantasy_account_leagues_roster_ownership_time_is_finite'
      )
  ),
  3,
  'collection and ownership watermarks have all reviewed constraints'
);
select is(
  (
    select count(*)::integer
    from (values
      ('app_private.sleeper_roster_sync_scopes'),
      ('app_private.sleeper_roster_sync_stage')
    ) as private_table(name)
    where has_table_privilege('service_role', private_table.name, 'select')
      or has_table_privilege('service_role', private_table.name, 'insert')
      or has_table_privilege('service_role', private_table.name, 'update')
      or has_table_privilege('service_role', private_table.name, 'delete')
  ),
  0,
  'service_role has no direct private-stage CRUD'
);
select is(
  (
    select count(*)::integer
    from (values
      ('anon', 'app_private.sleeper_roster_sync_scopes'),
      ('anon', 'app_private.sleeper_roster_sync_stage'),
      ('authenticated', 'app_private.sleeper_roster_sync_scopes'),
      ('authenticated', 'app_private.sleeper_roster_sync_stage')
    ) as access(role_name, table_name)
    where has_table_privilege(access.role_name, access.table_name, 'select')
      or has_table_privilege(access.role_name, access.table_name, 'insert')
      or has_table_privilege(access.role_name, access.table_name, 'update')
      or has_table_privilege(access.role_name, access.table_name, 'delete')
  ),
  0,
  'browser roles have no direct private-stage CRUD'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_proc as procedure
    inner join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'start_sleeper_roster_sync',
        'stage_sleeper_roster_league_bundle',
        'complete_sleeper_roster_sync',
        'fail_sleeper_roster_sync'
      )
  ),
  4,
  'all four roster lifecycle functions exist'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_proc as procedure
    inner join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'start_sleeper_roster_sync',
        'stage_sleeper_roster_league_bundle',
        'complete_sleeper_roster_sync',
        'fail_sleeper_roster_sync'
      )
      and procedure.prosecdef
      and procedure.proconfig @> array['search_path=pg_catalog']
  ),
  4,
  'all lifecycle functions are security definer with fixed search paths'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_proc as procedure
    inner join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'start_sleeper_roster_sync',
        'stage_sleeper_roster_league_bundle',
        'fail_sleeper_roster_sync'
      )
      and procedure.proconfig @> array['statement_timeout=10s']
  ),
  3,
  'start, stage, and fail use ten-second statement timeouts'
);
select ok(
  (
    select procedure.proconfig @> array['statement_timeout=60s']
    from pg_catalog.pg_proc as procedure
    inner join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'complete_sleeper_roster_sync'
  ),
  'completion uses a sixty-second statement timeout'
);
select is(
  (
    select count(*)::integer
    from (values
      ('public.start_sleeper_roster_sync(uuid,uuid)'),
      ('public.stage_sleeper_roster_league_bundle(uuid,uuid,uuid,text,jsonb)'),
      ('public.complete_sleeper_roster_sync(uuid,uuid,uuid)'),
      ('public.fail_sleeper_roster_sync(uuid,uuid,uuid,text,text,boolean)')
    ) as lifecycle(name)
    where has_function_privilege('service_role', lifecycle.name, 'execute')
      and has_function_privilege('postgres', lifecycle.name, 'execute')
      and not has_function_privilege('anon', lifecycle.name, 'execute')
      and not has_function_privilege('authenticated', lifecycle.name, 'execute')
  ),
  4,
  'only server roles can execute every roster lifecycle function'
);
select is(
  (
    select count(*)::integer
    from (values
      ('public.league_users'),
      ('public.rosters'),
      ('public.fantasy_account_rosters'),
      ('public.roster_players')
    ) as provider_table(name)
    where has_table_privilege('service_role', provider_table.name, 'select')
      or has_table_privilege('service_role', provider_table.name, 'insert')
      or has_table_privilege('service_role', provider_table.name, 'update')
      or has_table_privilege('service_role', provider_table.name, 'delete')
  ),
  0,
  'service_role retains no direct roster-domain CRUD'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'task007b2-a@example.test', '', now(),
    '{"provider":"email","providers":["email"]}', '{}',
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'task007b2-b@example.test', '', now(),
    '{"provider":"email","providers":["email"]}', '{}',
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'task007b2-unlinked@example.test', '', now(),
    '{"provider":"email","providers":["email"]}', '{}',
    now(), now(), '', '', '', ''
  );

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
) values (
  '82000000-0000-0000-0000-000000000001',
  'sleeper', 'tracked-user', 'TrackedUser', 'trackeduser', '{}', now()
);
insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
) values
  (
    '81000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001', true
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    '82000000-0000-0000-0000-000000000001', true
  );

select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000099',
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'A valid app user is required.',
  'a missing Auth user cannot start a roster sync'
);
select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000003',
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  'The app user is not linked to this fantasy account.',
  'an unlinked app user cannot start a roster sync'
);

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
) values
  (
    '82000000-0000-0000-0000-000000000002',
    'espn', 'non-sleeper-user', 'NonSleeper', 'nonsleeper', '{}', now()
  ),
  (
    '82000000-0000-0000-0000-000000000003',
    'sleeper', 'other-tracked-user', 'OtherTracked', 'othertracked', '{}', now()
  );
insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
) values
  (
    '81000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000002', false
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    '82000000-0000-0000-0000-000000000003', true
  );
select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000001',
      '82000000-0000-0000-0000-000000000002'
    )
  $$,
  '22023',
  'Roster import requires a Sleeper fantasy account.',
  'a linked non-Sleeper account cannot start a roster sync'
);
select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000001',
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  '55000',
  'Import the Sleeper player catalog before importing rosters.',
  'a published player catalog is required'
);

insert into public.provider_catalog_runs (
  provider, sport, catalog, status, progress_current, progress_total,
  source_fetched_at, source_record_count, source_bytes,
  started_at, finished_at, updated_at
) values (
  'sleeper', 'nfl', 'players', 'succeeded', 500, 500,
  '2026-09-01T00:00:00Z', 500, 100000,
  '2026-09-01T00:00:00Z', '2026-09-01T00:01:00Z', now()
);
create temporary table roster_catalog_fixture as
select gen_random_uuid() as player_id, item,
  'known-' || lpad(item::text, 4, '0') as external_id
from generate_series(1, 500) as source(item);
insert into public.players (
  id, sport, entity_type, display_name, primary_position,
  fantasy_positions, active, profile_source, source_metadata,
  profile_fetched_at
)
select
  player_id, 'nfl', 'player', 'Known ' || item, 'WR', array['WR'],
  true, 'sleeper', '{}', '2026-09-01T00:00:00Z'
from roster_catalog_fixture;
insert into public.player_external_ids (
  player_id, namespace, sport, external_id, reported_by, is_primary,
  source_metadata, first_seen_at, last_seen_at
)
select
  player_id, 'sleeper', 'nfl', external_id, 'sleeper', true,
  '{}', '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
from roster_catalog_fixture;

select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000001',
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  '55000',
  'Import current-season leagues before importing rosters.',
  'provider season state is required'
);

insert into public.provider_season_states (
  provider, sport, season, league_season, season_type,
  provider_metadata, fetched_at
) values (
  'sleeper', 'nfl', 2026, 2026, 'regular', '{}',
  '2026-09-01T00:00:00Z'
);
select throws_ok(
  $$
    select * from public.start_sleeper_roster_sync(
      '81000000-0000-0000-0000-000000000001',
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  '55000',
  'Import current-season leagues before importing rosters.',
  'at least one active current-season league is required'
);

insert into public.leagues (
  id, provider, external_league_id, sport, season, name, status,
  season_type, team_count, roster_size, roster_management_type,
  is_best_ball, has_superflex, has_idp, scoring_format,
  settings, scoring_settings, roster_positions, provider_metadata,
  fetched_at
) values
  (
    '83000000-0000-0000-0000-000000000001', 'sleeper', 'league-b',
    'nfl', 2026, 'League B', 'in_season', 'regular', 12, 3,
    'dynasty', false, false, false, 'ppr', '{}', '{"rec":1}',
    '["QB","RB","BN"]', '{}', '2026-09-01T00:00:00Z'
  ),
  (
    '83000000-0000-0000-0000-000000000002', 'sleeper', 'league-a',
    'nfl', 2026, 'League A', 'in_season', 'regular', 12, 3,
    'dynasty', false, false, false, 'ppr', '{}', '{"rec":1}',
    '["QB","RB","BN"]', '{}', '2026-09-01T00:00:00Z'
  );
insert into public.fantasy_account_leagues (
  fantasy_account_id, league_id, first_seen_at, last_seen_at
) values
  (
    '82000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  ),
  (
    '82000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000002',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  ),
  (
    '82000000-0000-0000-0000-000000000003',
    '83000000-0000-0000-0000-000000000001',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  ),
  (
    '82000000-0000-0000-0000-000000000003',
    '83000000-0000-0000-0000-000000000002',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  );

create function pg_temp.ownership_state_is_rejected(
  p_status text,
  p_observed_at timestamptz
)
returns boolean
language plpgsql
as $$
begin
  update public.fantasy_account_leagues
  set
    roster_ownership_status = p_status,
    roster_ownership_observed_at = p_observed_at
  where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
    and league_id = '83000000-0000-0000-0000-000000000001';
  return false;
exception
  when check_violation then
    return true;
end;
$$;

create function pg_temp.league_watermark_is_rejected(
  p_fetched_at timestamptz
)
returns boolean
language plpgsql
as $$
begin
  update public.leagues
  set roster_bundle_fetched_at = p_fetched_at
  where id = '83000000-0000-0000-0000-000000000001';
  return false;
exception
  when check_violation then
    return true;
end;
$$;

select ok(
  pg_temp.ownership_state_is_rejected('owned', null),
  'an ownership status without an observation timestamp is rejected'
);
select ok(
  pg_temp.ownership_state_is_rejected(
    null,
    '2026-09-01T00:00:00Z'::timestamptz
  ),
  'an ownership observation timestamp without a status is rejected'
);
select ok(
  pg_temp.ownership_state_is_rejected(
    'claimed',
    '2026-09-01T00:00:00Z'::timestamptz
  ),
  'an unsupported ownership status is rejected'
);
select ok(
  pg_temp.ownership_state_is_rejected('owned', 'infinity'::timestamptz),
  'a nonfinite ownership observation timestamp is rejected'
);
select ok(
  pg_temp.league_watermark_is_rejected('infinity'::timestamptz),
  'a nonfinite shared roster-bundle watermark is rejected'
);

create function pg_temp.roster_bundle(
  p_external_league_id text,
  p_fetched_at timestamptz,
  p_owner_id text default 'tracked-user',
  p_co_owner_ids jsonb default '[]'::jsonb,
  p_player_ids jsonb default '["known-0001","reference-only"]'::jsonb,
  p_starter_ids jsonb default '["known-0001","0"]'::jsonb,
  p_reserve_ids jsonb default '["reference-only"]'::jsonb,
  p_taxi_ids jsonb default '[]'::jsonb,
  p_keeper_ids jsonb default '["known-0001"]'::jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_memberships jsonb;
begin
  if p_player_ids = 'null'::jsonb then
    v_memberships := 'null'::jsonb;
  else
    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'external_player_id', player.value,
        'source_order', player.ordinality,
        'is_starter', p_starter_ids <> 'null'::jsonb and exists (
          select 1 from pg_catalog.jsonb_array_elements_text(
            case
              when p_starter_ids = 'null'::jsonb then '[]'::jsonb
              else p_starter_ids
            end
          )
            as starter(value) where starter.value = player.value
        ),
        'starter_order', case
          when p_starter_ids <> 'null'::jsonb then (
            select pg_catalog.min(starter.ordinality)
            from pg_catalog.jsonb_array_elements_text(p_starter_ids)
              with ordinality as starter(value, ordinality)
            where starter.value = player.value
          )
          else null
        end,
        'starter_slot', case
          when p_starter_ids <> 'null'::jsonb
            and pg_catalog.jsonb_array_length(
              case
                when p_starter_ids = 'null'::jsonb then '[]'::jsonb
                else p_starter_ids
              end
            ) = 2
            and player.value = 'known-0001' then 'QB'
          else null
        end,
        'is_reserve', p_reserve_ids <> 'null'::jsonb and exists (
          select 1 from pg_catalog.jsonb_array_elements_text(
            case
              when p_reserve_ids = 'null'::jsonb then '[]'::jsonb
              else p_reserve_ids
            end
          )
            as reserve(value) where reserve.value = player.value
        ),
        'is_taxi', p_taxi_ids <> 'null'::jsonb and exists (
          select 1 from pg_catalog.jsonb_array_elements_text(
            case
              when p_taxi_ids = 'null'::jsonb then '[]'::jsonb
              else p_taxi_ids
            end
          )
            as taxi(value) where taxi.value = player.value
        ),
        'is_keeper', p_keeper_ids <> 'null'::jsonb and exists (
          select 1 from pg_catalog.jsonb_array_elements_text(
            case
              when p_keeper_ids = 'null'::jsonb then '[]'::jsonb
              else p_keeper_ids
            end
          )
            as keeper(value) where keeper.value = player.value
        ),
        'source_metadata', pg_catalog.jsonb_build_object(
          'annotation_source_state', pg_catalog.jsonb_build_object(
            'starters', case
              when p_starter_ids = 'null'::jsonb then 'unknown' else 'known'
            end,
            'reserve', case
              when p_reserve_ids = 'null'::jsonb then 'unknown' else 'known'
            end,
            'taxi', case
              when p_taxi_ids = 'null'::jsonb then 'unknown' else 'known'
            end,
            'keepers', case
              when p_keeper_ids = 'null'::jsonb then 'unknown' else 'known'
            end
          ),
          'normalization_warning_fields', '[]'::jsonb
        )
      ) order by player.ordinality
    ), '[]'::jsonb)
    into v_memberships
    from pg_catalog.jsonb_array_elements_text(p_player_ids)
      with ordinality as player(value, ordinality);
  end if;

  return pg_catalog.jsonb_build_object(
    'external_league_id', p_external_league_id,
    'league_season', 2026,
    'bundle_fetched_at', p_fetched_at,
    'users', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'external_user_id', 'league-user',
      'username', 'LeagueUser',
      'display_name', 'League User',
      'team_name', 'Fixture Team',
      'avatar_id', null,
      'avatar_url', null,
      'is_commissioner', true,
      'metadata', '{}'::jsonb
    )),
    'rosters', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'external_roster_id', 1,
      'owner_external_user_id', p_owner_id,
      'co_owner_external_user_ids', p_co_owner_ids,
      'source_player_ids', p_player_ids,
      'source_starter_ids', p_starter_ids,
      'source_reserve_ids', p_reserve_ids,
      'source_taxi_ids', p_taxi_ids,
      'source_keeper_ids', p_keeper_ids,
      'settings', '{"wins":1}'::jsonb,
      'metadata', '{}'::jsonb,
      'memberships', v_memberships
    )),
    'source_metadata', jsonb_build_object(
      'fixture', true,
      'users_endpoint_succeeded', 1,
      'rosters_endpoint_succeeded', 1,
      'users_response_bytes', 100,
      'rosters_response_bytes', 200,
      'source_fetch_duration_ms', 50
    )
  );
end;
$$;

create temporary table first_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select results_eq(
  $$
    select created_run, reused_run, recovered_stale_run, league_season
    from first_start
  $$,
  $$ values (true, false, false, 2026) $$,
  'first start creates a current-season roster run'
);
select results_eq(
  $$ select expected_external_league_ids from first_start $$,
  $$ values (array['league-a','league-b']::text[]) $$,
  'the frozen external league scope is exact and sorted'
);
select is(
  (
    select progress_total from public.sync_runs
    where id = (select sync_run_id from first_start)
  ),
  2,
  'the run total equals the frozen league count'
);
select is(
  (
    select count(*)::integer
    from app_private.sleeper_roster_sync_scopes
    where run_id = (select sync_run_id from first_start)
  ),
  1,
  'start creates one private frozen-scope row'
);

create temporary table reused_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000002',
  '82000000-0000-0000-0000-000000000001'
);
select results_eq(
  $$ select created_run, reused_run, sync_run_id from reused_start $$,
  $$ select false, true, sync_run_id from first_start $$,
  'a second linked app user reuses the fresh account run'
);

create temporary table independent_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000003',
  '82000000-0000-0000-0000-000000000003'
);
select ok(
  (
    select created_run
      and sync_run_id <> (select sync_run_id from first_start)
      and expected_external_league_ids = array['league-a','league-b']::text[]
    from independent_start
  ),
  'different fantasy accounts can run independently with their own frozen scopes'
);
select public.fail_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000003',
  '82000000-0000-0000-0000-000000000003',
  (select sync_run_id from independent_start),
  'fixture_cleanup',
  'The independent fixture run is complete.',
  false
);

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000002',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The sync run does not match this running Sleeper roster import.',
  'only the triggering app user may stage'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'outside-league',
        pg_temp.roster_bundle('outside-league','2026-09-01T01:00:00Z')
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The league is outside the frozen roster-sync scope.',
  'out-of-scope staging fails closed'
);

update public.fantasy_account_leagues
set removed_at = '2026-09-01T00:30:00Z'
where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  and league_id = '83000000-0000-0000-0000-000000000001';
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-b',
        pg_temp.roster_bundle('league-b','2026-09-01T01:00:00Z')
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The frozen league is no longer an active current-season association.',
  'an inactive account-to-league association cannot stage'
);
update public.fantasy_account_leagues
set removed_at = null
where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  and league_id = '83000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{league_season}',
          '2025'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'a bundle for the wrong season is rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{users}',
          (pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')->'users')
            || (pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')->'users')
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'duplicate league users are rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{rosters}',
          (pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')->'rosters')
            || (pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')->'rosters')
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'duplicate roster IDs are rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        pg_temp.roster_bundle(
          'league-a','2026-09-01T01:00:00Z','tracked-user','[]'::jsonb,
          '["known-0001","known-0001"]'::jsonb,
          '["known-0001","0"]'::jsonb,'[]'::jsonb,'[]'::jsonb,'[]'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'duplicate real player IDs are rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')
          || '{"unsupported":true}'::jsonb
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'unsupported top-level keys are rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{users}',
          (
            select jsonb_agg(
              jsonb_set(
                jsonb_set(
                  pg_temp.roster_bundle(
                    'league-a','2026-09-01T01:00:00Z'
                  ) -> 'users' -> 0,
                  '{external_user_id}',
                  to_jsonb('oversize-user-' || source.item::text)
                ),
                '{metadata}',
                jsonb_build_object('padding', repeat('x', 60000))
              )
            )
            from generate_series(1, 40) as source(item)
          )
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'a highly compressible bundle over the serialized byte limit is rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle(
            'league-a','2026-09-01T01:00:00Z','tracked-user','[]'::jsonb,
            'null'::jsonb,'null'::jsonb,'null'::jsonb,'null'::jsonb,'null'::jsonb
          ),
          '{rosters,0,memberships}',
          '[]'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'players null requires normalized memberships null'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        pg_temp.roster_bundle(
          'league-a','2026-09-01T01:00:00Z','tracked-user','[]'::jsonb,
          '["known-0001"]'::jsonb,'["known-0001","UNVERIFIED"]'::jsonb,
          '[]'::jsonb,'[]'::jsonb,'[]'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'an unverified starter placeholder is rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        pg_temp.roster_bundle(
          'league-a','2026-09-01T01:00:00Z','tracked-user','[]'::jsonb,
          '["0"]'::jsonb,'["0","0"]'::jsonb,
          '[]'::jsonb,'[]'::jsonb,'[]'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'the starter placeholder cannot appear in source players or memberships'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{rosters,0,memberships,0,source_order}',
          '2'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'a normalized membership that disagrees with exact source order is rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{rosters,0,memberships,0,source_metadata}',
          '{}'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'membership metadata without the exact annotation-state contract is rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{rosters,0,memberships,0,source_metadata,annotation_source_state,starters}',
          '"unknown"'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'membership annotation state must agree with the exact source array state'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{rosters,0,memberships,0,source_metadata,normalization_warning_fields}',
          '["UNSAFE"]'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The normalized roster league bundle is invalid.',
  'membership warning metadata is restricted to bounded safe tokens'
);

create temporary table first_stage_a as
select staged.*
from first_start as started
cross join lateral public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id,
  'league-a',
  pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')
) as staged;
select results_eq(
  $$ select staged_leagues, progress_total, replayed_bundle from first_stage_a $$,
  $$ values (1, 2, false) $$,
  'the first valid league bundle advances distinct progress'
);
create temporary table replay_stage_a as
select staged.*
from first_start as started
cross join lateral public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id,
  'league-a',
  pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z')
) as staged;
select results_eq(
  $$ select staged_leagues, replayed_bundle from replay_stage_a $$,
  $$ values (1, true) $$,
  'an exact staged-bundle replay is idempotent'
);
select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_roster_league_bundle(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'league-a',
        jsonb_set(
          pg_temp.roster_bundle('league-a','2026-09-01T01:00:00Z'),
          '{source_metadata}',
          '{"changed":true}'::jsonb
        )
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'A staged league bundle changed during this roster import.',
  'a changed replay fails closed'
);
select is(
  (
    select count(*)::integer from public.rosters
  ),
  0,
  'staging does not mutate public roster data'
);
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_roster_sync(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid
      )
    $sql$,
    (select sync_run_id from first_start)
  ),
  '22023',
  'The staged roster collection does not equal the frozen scope.',
  'completion rejects a missing staged league'
);

create temporary table first_stage_b as
select staged.*
from first_start as started
cross join lateral public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id,
  'league-b',
  pg_temp.roster_bundle('league-b','2026-09-01T01:00:00Z')
) as staged;
select is(
  (select staged_leagues from first_stage_b),
  2,
  'the full frozen league set stages exactly once'
);

update public.player_external_ids
set removed_at = '2026-09-01T02:00:00Z'
where namespace = 'sleeper'
  and sport = 'nfl'
  and external_id = 'known-0001';

create temporary table first_completion as
select completed.*
from first_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, observed_leagues, observed_league_users,
      observed_rosters, observed_memberships,
      applied_shared_league_bundles,
      stale_shared_league_bundles_skipped
    from first_completion
  $$,
  $$ values ('succeeded'::text, 2, 2, 2, 4, 2, 0) $$,
  'complete publication reports the full observed collection'
);
select results_eq(
  $$
    select created_league_users, created_rosters, created_memberships,
      created_ownerships, owned_leagues, confirmed_not_owned_leagues,
      unresolved_ownership_leagues, stale_ownership_resolutions_skipped
    from first_completion
  $$,
  $$ values (2, 2, 4, 2, 2, 0, 0, 0) $$,
  'first publication creates canonical shared and owned rows'
);
select results_eq(
  $$
    select external_league_id, roster_bundle_fetched_at
    from public.leagues
    order by external_league_id
  $$,
  $$
    values
      ('league-a'::text, '2026-09-01T01:00:00Z'::timestamptz),
      ('league-b'::text, '2026-09-01T01:00:00Z'::timestamptz)
  $$,
  'the first complete bundle sets each shared league watermark'
);
select results_eq(
  $$
    select league.external_league_id,
      association.roster_ownership_status,
      association.roster_ownership_observed_at
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id =
      '82000000-0000-0000-0000-000000000001'
    order by league.external_league_id
  $$,
  $$
    values
      ('league-a'::text, 'owned'::text, '2026-09-01T01:00:00Z'::timestamptz),
      ('league-b'::text, 'owned'::text, '2026-09-01T01:00:00Z'::timestamptz)
  $$,
  'the first confirmed ownership match records owned at the league watermark'
);
select results_eq(
  $$
    select reactivated_player_mappings,
      (select removed_at is null
       from public.player_external_ids
       where namespace = 'sleeper' and sport = 'nfl'
         and external_id = 'known-0001'),
      (select source_metadata
       from public.player_external_ids
       where namespace = 'sleeper' and sport = 'nfl'
         and external_id = 'known-0001')
    from first_completion
  $$,
  $$ values (1, true, '{}'::jsonb) $$,
  'an exact roster reference reactivates even newer removal history without relabeling catalog provenance'
);
select is((select count(*)::integer from public.league_users), 2,
  'one canonical league user exists per league');
select is((select count(*)::integer from public.rosters), 2,
  'one canonical roster exists per league-local identity');
select is((select count(*)::integer from public.fantasy_account_rosters), 2,
  'one explicit account ownership exists per matched league');
select is((select count(*)::integer from public.roster_players), 4,
  'one canonical current membership exists per roster and player');
select ok(
  (
    select bool_and(
      source_player_ids = array['known-0001','reference-only']
      and source_starter_ids = array['known-0001','0']
      and source_reserve_ids = array['reference-only']
      and source_taxi_ids = '{}'::text[]
      and source_keeper_ids = array['known-0001']
    ) from public.rosters
  ),
  'exact source arrays including the repeated-slot placeholder persist'
);
select ok(
  (
    select bool_and(
      (external_id.external_id = 'known-0001'
        and membership.source_order = 1
        and membership.is_starter
        and membership.starter_order = 1
        and membership.starter_slot = 'QB'
        and membership.is_keeper)
      or
      (external_id.external_id = 'reference-only'
        and membership.source_order = 2
        and not membership.is_starter
        and membership.is_reserve)
    )
    from public.roster_players as membership
    inner join public.player_external_ids as external_id
      on external_id.id = membership.source_player_external_id_id
  ),
  'normalized order, starter, reserve, and keeper state is exact'
);
select is(
  (
    select count(*)::integer from public.player_external_ids
    where namespace = 'sleeper' and sport = 'nfl' and external_id = '0'
  ),
  0,
  'the verified starter placeholder creates no player mapping'
);
select results_eq(
  $$
    select player.entity_type, player.display_name, player.active,
      player.source_metadata ->> 'reference_source'
    from public.players as player
    inner join public.player_external_ids as external_id
      on external_id.player_id = player.id
    where external_id.namespace = 'sleeper'
      and external_id.sport = 'nfl'
      and external_id.external_id = 'reference-only'
  $$,
  $$ values ('unknown'::text, null::text, null::boolean, 'roster'::text) $$,
  'an unmapped valid holding creates one sparse reference-only identity'
);
select results_eq(
  $$
    with attempted_removal as (
      update public.player_external_ids as external_id
      set removed_at = '2026-09-01T02:00:00Z'
      where external_id.namespace = 'sleeper'
        and external_id.sport = 'nfl'
        and external_id.external_id = 'reference-only'
        and not exists (
          select 1
          from public.roster_players as membership
          where membership.source_player_external_id_id = external_id.id
            and membership.removed_at is null
        )
      returning external_id.id
    )
    select
      (select count(*)::integer from attempted_removal),
      (select removed_at is null
       from public.player_external_ids
       where namespace = 'sleeper' and sport = 'nfl'
         and external_id = 'reference-only'),
      position(
        'from public.roster_players as membership'
        in pg_get_functiondef(
          'public.complete_sleeper_player_catalog_sync(uuid,uuid)'::regprocedure
        )
      ) > 0
  $$,
  $$ values (0, true, true) $$,
  'the catalog completion predicate cannot retire a mapping used by active membership'
);
select is(
  (
    select count(*)::integer from app_private.sleeper_roster_sync_stage
    where run_id = (select sync_run_id from first_start)
  ),
  0,
  'successful completion deletes private staged bundles'
);
select is(
  (
    select count(*)::integer from app_private.sleeper_roster_sync_scopes
    where run_id = (select sync_run_id from first_start)
  ),
  0,
  'successful completion deletes the private frozen scope'
);
select is(
  (
    select status from public.sync_runs
    where id = (select sync_run_id from first_start)
  ),
  'succeeded',
  'the completed run is terminal and succeeded'
);
select results_eq(
  $$
    select
      (result_counts ->> 'source_user_endpoint_successes')::bigint,
      (result_counts ->> 'source_roster_endpoint_successes')::bigint,
      (result_counts ->> 'source_endpoint_successes')::bigint,
      (result_counts ->> 'source_response_bytes')::bigint,
      (result_counts ->> 'source_fetch_duration_ms_total')::bigint,
      (result_counts ->> 'source_fetch_duration_ms_max')::bigint,
      (result_counts ->> 'source_collection_window_ms_derived')::bigint,
      (result_counts ->> 'applied_shared_league_bundles')::integer,
      (result_counts ->> 'stale_shared_league_bundles_skipped')::integer,
      (result_counts ->> 'owned_leagues')::integer,
      (result_counts ->> 'confirmed_not_owned_leagues')::integer,
      (result_counts ->> 'unresolved_ownership_leagues')::integer,
      (result_counts ->> 'stale_ownership_resolutions_skipped')::integer,
      (result_counts ->> 'stage_insert_window_ms')::bigint >= 0,
      (result_counts ->> 'stage_to_completion_ms')::bigint >= 0,
      (result_counts ->> 'completion_duration_ms')::bigint >= 0
    from public.sync_runs
    where id = (select sync_run_id from first_start)
  $$,
  $$ values (2::bigint, 2::bigint, 4::bigint, 600::bigint, 100::bigint,
    50::bigint, 50::bigint, 2, 0, 2, 0, 0, 0, true, true, true) $$,
  'terminal result counts retain bounded source, stage, and completion observability'
);
select is(
  (
    select last_synced_at from public.fantasy_accounts
    where id = '82000000-0000-0000-0000-000000000001'
  ),
  null::timestamptz,
  'roster import does not update the portfolio synchronization timestamp'
);

create temporary table null_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from null_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id, '2026-09-02T01:00:00Z',
    'tracked-user', 'null'::jsonb, 'null'::jsonb,
    'null'::jsonb, 'null'::jsonb, 'null'::jsonb, 'null'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from null_start)
) as scoped(external_league_id);
select public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from null_start)
);
select ok(
  (select bool_and(source_player_ids is null and source_starter_ids is null)
   from public.rosters),
  'source-null arrays remain SQL null'
);
select is(
  (select count(*)::integer from public.roster_players where removed_at is null),
  4,
  'null players preserves existing normalized memberships'
);
select is(
  (select count(*)::integer from public.roster_players where is_starter and removed_at is null),
  2,
  'null starter annotations preserve prior confirmed starter state'
);
select is(
  (select count(*)::integer from public.roster_players where is_reserve and removed_at is null),
  2,
  'null reserve annotations preserve prior confirmed reserve state'
);
select results_eq(
  $$
    select count(*) filter (where is_taxi)::integer,
      count(*) filter (where is_keeper)::integer
    from public.roster_players
    where removed_at is null
  $$,
  $$ values (0, 2) $$,
  'null taxi and keeper annotations preserve prior confirmed flag state'
);
select ok(
  (
    select pg_catalog.bool_and(
      source_metadata -> 'annotation_source_state' = pg_catalog.jsonb_build_object(
        'starters', 'unknown',
        'reserve', 'unknown',
        'taxi', 'unknown',
        'keepers', 'unknown'
      )
      and source_metadata -> 'normalization_warning_fields' = '[]'::jsonb
    )
    from public.roster_players
    where removed_at is null
  ),
  'source-null annotations persist unknown metadata while retaining last-confirmed flags'
);

create temporary table clear_annotations_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from clear_annotations_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id, '2026-09-02T12:00:00Z',
    'tracked-user', '[]'::jsonb,
    'null'::jsonb,
    '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from clear_annotations_start)
) as scoped(external_league_id);
select public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from clear_annotations_start)
);
select results_eq(
  $$
    select count(*)::integer,
      count(*) filter (
        where is_starter or is_reserve or is_taxi or is_keeper
          or starter_order is not null or starter_slot is not null
      )::integer
    from public.roster_players
    where removed_at is null
  $$,
  $$ values (4, 0) $$,
  'players null preserves membership while explicit empty annotations clear all four flags'
);
select ok(
  (
    select pg_catalog.bool_and(
      source_metadata -> 'annotation_source_state' = pg_catalog.jsonb_build_object(
        'starters', 'known',
        'reserve', 'known',
        'taxi', 'known',
        'keepers', 'known'
      )
    )
    from public.roster_players
    where removed_at is null
  ),
  'explicit empty annotations persist known metadata rather than unknown state'
);

create temporary table empty_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from empty_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id, '2026-09-03T01:00:00Z',
    'tracked-user', '[]'::jsonb, '[]'::jsonb,
    '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from empty_start)
) as scoped(external_league_id);
select public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from empty_start)
);
select ok(
  (select bool_and(
    source_player_ids = '{}'::text[]
    and source_starter_ids = '{}'::text[]
    and source_reserve_ids = '{}'::text[]
    and source_taxi_ids = '{}'::text[]
    and source_keeper_ids = '{}'::text[]
  ) from public.rosters),
  'explicit empty source arrays remain explicit empty arrays'
);
select is(
  (select count(*)::integer from public.roster_players where removed_at is null),
  0,
  'explicit empty players removes active memberships without deleting history'
);
select is((select count(*)::integer from public.roster_players), 4,
  'removed membership history is retained');

create temporary table membership_first_seen_before_refresh as
select roster_id, player_id, first_seen_at
from public.roster_players;

create temporary table newer_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from newer_start),
  scoped.external_league_id,
  jsonb_set(
    jsonb_set(
      pg_temp.roster_bundle(
        scoped.external_league_id, '2026-09-06T01:00:00Z',
        'tracked-user', '["tracked-user","other-tracked-user"]'::jsonb
      ),
      '{users,0,display_name}',
      '"Newer User"'::jsonb
    ),
    '{rosters,0,settings}',
    '{"freshness":"newer"}'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from newer_start)
) as scoped(external_league_id);
create temporary table newer_completion as
select completed.*
from newer_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, active_owned_rosters, active_owned_memberships,
      applied_shared_league_bundles,
      stale_shared_league_bundles_skipped
    from newer_completion
  $$,
  $$ values ('succeeded'::text, 2, 4, 2, 0) $$,
  'a newer run reactivates current owned rosters and memberships'
);
select ok(
  (
    select pg_catalog.bool_and(
      roster_bundle_fetched_at = '2026-09-06T01:00:00Z'::timestamptz
    )
    from public.leagues
  ),
  'a newer complete bundle advances every shared league watermark'
);

create temporary table older_other_account_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000003',
  '82000000-0000-0000-0000-000000000003'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000003',
  '82000000-0000-0000-0000-000000000003',
  (select sync_run_id from older_other_account_start),
  scoped.external_league_id,
  jsonb_set(
    jsonb_set(
      pg_temp.roster_bundle(
        scoped.external_league_id, '2026-09-05T01:00:00Z',
        'tracked-user', '["tracked-user","other-tracked-user"]'::jsonb,
        '["known-0001","reference-only"]'::jsonb,
        '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb
      ),
      '{users,0,display_name}',
      '"Older User"'::jsonb
    ),
    '{rosters,0,settings}',
    '{"freshness":"older"}'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from older_other_account_start)
) as scoped(external_league_id);
create temporary table older_other_account_completion as
select completed.*
from older_other_account_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000003',
  '82000000-0000-0000-0000-000000000003',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select stale_league_users_skipped, stale_rosters_skipped,
      stale_memberships_skipped, created_ownerships,
      applied_shared_league_bundles,
      stale_shared_league_bundles_skipped,
      owned_leagues
    from older_other_account_completion
  $$,
  $$ values (2, 2, 4, 2, 0, 2, 2) $$,
  'an older account run skips whole shared bundles and resolves ownership from canonical state'
);
select ok(
  (
    select pg_catalog.bool_and(
      roster_bundle_fetched_at = '2026-09-06T01:00:00Z'::timestamptz
    )
    from public.leagues
  ),
  'an older complete bundle cannot reduce a shared league watermark'
);
select ok(
  (
    select pg_catalog.bool_and(
      association.roster_ownership_status = 'owned'
      and association.roster_ownership_observed_at =
        '2026-09-06T01:00:00Z'::timestamptz
    )
    from public.fantasy_account_leagues as association
    where association.fantasy_account_id =
      '82000000-0000-0000-0000-000000000003'
  ),
  'an older account bundle records ownership at the newer canonical shared watermark'
);
select ok(
  (
    select bool_and(
      league_user.display_name = 'Newer User'
      and roster.settings = '{"freshness":"newer"}'::jsonb
      and roster.source_starter_ids = array['known-0001','0']::text[]
    )
    from public.league_users as league_user
    inner join public.rosters as roster
      on roster.league_id = league_user.league_id
  ),
  'older completion cannot regress newer shared user, roster, or exact-array state'
);
select ok(
  (
    select bool_and(
      membership.is_starter = (external_id.external_id = 'known-0001')
      and membership.is_reserve = (external_id.external_id = 'reference-only')
      and membership.is_keeper = (external_id.external_id = 'known-0001')
    )
    from public.roster_players as membership
    inner join public.player_external_ids as external_id
      on external_id.id = membership.source_player_external_id_id
    where membership.removed_at is null
  ),
  'older completion cannot regress newer normalized membership flags'
);
select ok(
  (
    select bool_and(membership.first_seen_at = before.first_seen_at)
    from public.roster_players as membership
    inner join membership_first_seen_before_refresh as before
      on before.roster_id = membership.roster_id
      and before.player_id = membership.player_id
  ),
  'membership reactivation preserves the original first-seen time'
);
select results_eq(
  $$
    select account.external_user_id, ownership.ownership_role,
      count(*)::integer
    from public.fantasy_account_rosters as ownership
    inner join public.fantasy_accounts as account
      on account.id = ownership.fantasy_account_id
    where ownership.removed_at is null
    group by account.external_user_id, ownership.ownership_role
    order by account.external_user_id
  $$,
  $$
    values
      ('other-tracked-user'::text, 'co_owner'::text, 2),
      ('tracked-user'::text, 'owner'::text, 2)
  $$,
  'owner takes precedence over co-owner and a second account owns the same shared rosters independently'
);

create temporary table partial_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from partial_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id, '2026-09-06T12:00:00Z',
    'different-owner', 'null'::jsonb
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from partial_start)
) as scoped(external_league_id);
create temporary table partial_completion as
select completed.*
from partial_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, owned_leagues, confirmed_not_owned_leagues,
      unresolved_ownership_leagues, active_owned_rosters,
      active_owned_memberships
    from partial_completion
  $$,
  $$ values ('partial'::text, 0, 0, 2, 0, 0) $$,
  'unknown co-owner state yields a truthful partial run'
);
select is(
  (select count(*)::integer from public.fantasy_account_rosters where removed_at is null),
  4,
  'unresolved ownership preserves prior confirmed associations for both accounts'
);
select ok(
  (
    select pg_catalog.bool_and(
      roster_ownership_status = 'unresolved'
      and roster_ownership_observed_at =
        '2026-09-06T12:00:00Z'::timestamptz
    )
    from public.fantasy_account_leagues
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  ),
  'unresolved ownership is explicit even while prior ownership history remains active'
);

create temporary table older_after_unresolved_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from older_after_unresolved_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-06T06:00:00Z'
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from older_after_unresolved_start)
) as scoped(external_league_id);
create temporary table older_after_unresolved_completion as
select completed.*
from older_after_unresolved_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, applied_shared_league_bundles,
      stale_shared_league_bundles_skipped, owned_leagues,
      unresolved_ownership_leagues, active_owned_rosters,
      active_owned_memberships
    from older_after_unresolved_completion
  $$,
  $$ values ('partial'::text, 0, 2, 0, 2, 0, 0) $$,
  'an older positive bundle reuses newer canonical unresolved state and cannot restore current ownership'
);
select ok(
  (
    select pg_catalog.bool_and(
      roster_ownership_status = 'unresolved'
      and roster_ownership_observed_at =
        '2026-09-06T12:00:00Z'::timestamptz
    )
    from public.fantasy_account_leagues
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  ),
  'a newer unresolved observation cannot be overwritten by an older positive bundle'
);

create temporary table scoped_removal_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from scoped_removal_start),
  'league-a',
  jsonb_set(
    jsonb_set(
      pg_temp.roster_bundle('league-a','2026-09-07T01:00:00Z'),
      '{users}',
      '[]'::jsonb
    ),
    '{rosters}',
    '[]'::jsonb
  )
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from scoped_removal_start),
  'league-b',
  pg_temp.roster_bundle('league-b','2026-09-07T01:00:00Z')
);
create temporary table scoped_removal_completion as
select completed.*
from scoped_removal_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select removed_league_users, removed_rosters, removed_memberships,
      removed_ownerships, owned_leagues, confirmed_not_owned_leagues,
      active_owned_rosters, active_owned_memberships, final_status
    from scoped_removal_completion
  $$,
  $$ values (1, 1, 2, 1, 1, 1, 1, 2, 'succeeded'::text) $$,
  'confirmed empty users and rosters remove only current rows and holdings in the exact league'
);
select results_eq(
  $$
    select league.external_league_id,
      association.roster_ownership_status,
      association.roster_ownership_observed_at
    from public.fantasy_account_leagues as association
    inner join public.leagues as league on league.id = association.league_id
    where association.fantasy_account_id =
      '82000000-0000-0000-0000-000000000001'
    order by league.external_league_id
  $$,
  $$
    values
      ('league-a'::text, 'not_owned'::text, '2026-09-07T01:00:00Z'::timestamptz),
      ('league-b'::text, 'owned'::text, '2026-09-07T01:00:00Z'::timestamptz)
  $$,
  'canonical current state records one confirmed not-owned and one owned league'
);
select results_eq(
  $$
    select league.external_league_id,
      league_user.removed_at is null as user_active,
      roster.removed_at is null as roster_active
    from public.leagues as league
    inner join public.league_users as league_user
      on league_user.league_id = league.id
    inner join public.rosters as roster on roster.league_id = league.id
    order by league.external_league_id
  $$,
  $$
    values
      ('league-a'::text, false, false),
      ('league-b'::text, true, true)
  $$,
  'user and roster removal is scoped to one league and leaves another league untouched'
);
select results_eq(
  $$
    select count(*)::integer,
      count(*) filter (where removed_at is null)::integer
    from public.fantasy_account_rosters
    where fantasy_account_id = '82000000-0000-0000-0000-000000000003'
  $$,
  $$ values (2, 2) $$,
  'one account removal never rewrites another fantasy account ownership'
);
select results_eq(
  $$
    select count(*)::integer,
      count(*) filter (where removed_at is null)::integer
    from public.fantasy_account_rosters
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  $$,
  $$ values (2, 1) $$,
  'confirmed no owned roster removes only this account association'
);
select results_eq(
  $$
    select
      (select count(*)::integer from public.league_users),
      (select count(*)::integer from public.rosters)
  $$,
  $$ values (2, 2) $$,
  'shared user and roster history is never deleted during removal'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) values (
  '00000000-0000-0000-0000-000000000000',
  '81000000-0000-0000-0000-000000000004', 'authenticated',
  'authenticated', 'task007b2-never-owned@example.test', '', now(),
  '{"provider":"email","providers":["email"]}', '{}',
  now(), now(), '', '', '', ''
);
insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
) values (
  '82000000-0000-0000-0000-000000000004',
  'sleeper', 'never-owned-user', 'NeverOwned', 'neverowned', '{}', now()
);
insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
) values (
  '81000000-0000-0000-0000-000000000004',
  '82000000-0000-0000-0000-000000000004', true
);
insert into public.fantasy_account_leagues (
  fantasy_account_id, league_id, first_seen_at, last_seen_at
) values
  (
    '82000000-0000-0000-0000-000000000004',
    '83000000-0000-0000-0000-000000000001',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  ),
  (
    '82000000-0000-0000-0000-000000000004',
    '83000000-0000-0000-0000-000000000002',
    '2026-09-01T00:00:00Z', '2026-09-01T00:00:00Z'
  );
create temporary table never_owned_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000004',
  '82000000-0000-0000-0000-000000000004'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000004',
  '82000000-0000-0000-0000-000000000004',
  (select sync_run_id from never_owned_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-06T00:00:00Z'
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from never_owned_start)
) as scoped(external_league_id);
create temporary table never_owned_completion as
select completed.*
from never_owned_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000004',
  '82000000-0000-0000-0000-000000000004',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, confirmed_not_owned_leagues,
      stale_shared_league_bundles_skipped, created_ownerships,
      active_owned_rosters, active_owned_memberships
    from never_owned_completion
  $$,
  $$ values ('succeeded'::text, 2, 2, 0, 0, 0) $$,
  'confirmed zero matches records not-owned even without prior ownership rows'
);
select ok(
  (
    select pg_catalog.bool_and(
      roster_ownership_status = 'not_owned'
      and roster_ownership_observed_at =
        '2026-09-07T01:00:00Z'::timestamptz
    )
    from public.fantasy_account_leagues
    where fantasy_account_id = '82000000-0000-0000-0000-000000000004'
  ),
  'first negative ownership observations use the canonical shared watermark'
);

create temporary table membership_removal_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from membership_removal_start),
  'league-a',
  jsonb_set(
    jsonb_set(
      pg_temp.roster_bundle('league-a','2026-09-08T01:00:00Z'),
      '{users}',
      '[]'::jsonb
    ),
    '{rosters}',
    '[]'::jsonb
  )
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from membership_removal_start),
  'league-b',
  pg_temp.roster_bundle(
    'league-b','2026-09-08T01:00:00Z','tracked-user','[]'::jsonb,
    '["known-0001"]'::jsonb,'["known-0001","0"]'::jsonb,
    '[]'::jsonb,'[]'::jsonb,'[]'::jsonb
  )
);
create temporary table membership_removal_completion as
select completed.*
from membership_removal_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select removed_memberships,
      (select count(*)::integer
       from public.roster_players as membership
       inner join public.rosters as roster on roster.id = membership.roster_id
       inner join public.leagues as league on league.id = roster.league_id
       inner join public.player_external_ids as external_id
         on external_id.id = membership.source_player_external_id_id
       where league.external_league_id = 'league-b'
         and external_id.external_id = 'reference-only'
         and membership.removed_at is not null)
    from membership_removal_completion
  $$,
  $$ values (1, 1) $$,
  'an absent player is removed only from the exact current roster'
);

create temporary table stale_absence_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
create temporary table stale_absence_creation_counts_before as
select
  (select count(*)::integer from public.players) as players,
  (select count(*)::integer from public.player_external_ids) as mappings;
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from stale_absence_start),
  scoped.external_league_id,
  case
    when scoped.external_league_id = 'league-a' then jsonb_set(
      jsonb_set(
        source.bundle,
        '{users}',
        (source.bundle -> 'users') || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'external_user_id', 'stale-only-user',
            'username', 'StaleOnly',
            'display_name', 'Stale Only User',
            'team_name', 'Stale Only Team',
            'avatar_id', null,
            'avatar_url', null,
            'is_commissioner', false,
            'metadata', '{}'::jsonb
          )
        )
      ),
      '{rosters}',
      (source.bundle -> 'rosters') || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'external_roster_id', 2,
          'owner_external_user_id', 'tracked-user',
          'co_owner_external_user_ids', '[]'::jsonb,
          'source_player_ids', '["stale-only-player"]'::jsonb,
          'source_starter_ids',
            '["stale-only-player","0"]'::jsonb,
          'source_reserve_ids', '[]'::jsonb,
          'source_taxi_ids', '[]'::jsonb,
          'source_keeper_ids', '[]'::jsonb,
          'settings', '{}'::jsonb,
          'metadata', '{}'::jsonb,
          'memberships', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'external_player_id', 'stale-only-player',
              'source_order', 1,
              'is_starter', true,
              'starter_order', 1,
              'starter_slot', 'QB',
              'is_reserve', false,
              'is_taxi', false,
              'is_keeper', false,
              'source_metadata', pg_catalog.jsonb_build_object(
                'annotation_source_state', pg_catalog.jsonb_build_object(
                  'starters', 'known',
                  'reserve', 'known',
                  'taxi', 'known',
                  'keepers', 'known'
                ),
                'normalization_warning_fields', '[]'::jsonb
              )
            )
          )
        )
      )
    )
    else source.bundle
  end
)
from pg_catalog.unnest(
  (select expected_external_league_ids from stale_absence_start)
) as scoped(external_league_id)
cross join lateral (
  select pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-07T12:00:00Z'
  ) as bundle
) as source;
create temporary table stale_absence_completion as
select completed.*
from stale_absence_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select applied_shared_league_bundles,
      stale_shared_league_bundles_skipped,
      created_league_users, updated_league_users, removed_league_users,
      created_rosters, updated_rosters, removed_rosters,
      created_memberships, updated_memberships, removed_memberships,
      reactivated_player_mappings
    from stale_absence_completion
  $$,
  $$ values (0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) $$,
  'stale bundles perform no shared creation, update, removal, or mapping reactivation'
);
select results_eq(
  $$
    select stale_league_users_skipped, stale_rosters_skipped,
      stale_memberships_skipped, owned_leagues,
      confirmed_not_owned_leagues, stale_ownership_resolutions_skipped
    from stale_absence_completion
  $$,
  $$ values (3, 3, 5, 1, 1, 0) $$,
  'stale bundle and canonical ownership result counts are explicit and bounded'
);
select results_eq(
  $$
    select
      (select count(*)::integer
       from public.league_users
       where external_user_id = 'stale-only-user'),
      (select count(*)::integer
       from public.rosters as roster
       inner join public.leagues as league on league.id = roster.league_id
       where league.external_league_id = 'league-a'
         and roster.external_roster_id = 2),
      (select count(*)::integer
       from public.roster_players as membership
       inner join public.player_external_ids as external_id
         on external_id.id = membership.source_player_external_id_id
       where external_id.external_id = 'stale-only-player'),
      (select count(*)::integer
       from public.player_external_ids
       where namespace = 'sleeper'
         and sport = 'nfl'
         and external_id = 'stale-only-player'),
      (select count(*)::integer from public.players),
      (select count(*)::integer from public.player_external_ids)
  $$,
  $$
    select 0, 0, 0, 0, players, mappings
    from stale_absence_creation_counts_before
  $$,
  'an older stale bundle cannot create a never-seen user, roster, membership, sparse player, or mapping'
);
select results_eq(
  $$
    select
      (select count(*)::integer
       from public.league_users where removed_at is null),
      (select count(*)::integer
       from public.rosters where removed_at is null),
      (select count(*)::integer
       from public.roster_players where removed_at is null),
      (select count(*)::integer
       from public.roster_players as membership
       inner join public.player_external_ids as external_id
         on external_id.id = membership.source_player_external_id_id
       inner join public.rosters as roster on roster.id = membership.roster_id
       inner join public.leagues as league on league.id = roster.league_id
       where league.external_league_id = 'league-b'
         and external_id.external_id = 'reference-only'
         and membership.removed_at is not null)
  $$,
  $$ values (1, 1, 1, 1) $$,
  'older inclusion cannot resurrect a user, roster, or membership omitted by newer bundles'
);
select results_eq(
  $$
    select league.external_league_id,
      league.roster_bundle_fetched_at,
      association.roster_ownership_status,
      association.roster_ownership_observed_at
    from public.leagues as league
    inner join public.fantasy_account_leagues as association
      on association.league_id = league.id
    where association.fantasy_account_id =
      '82000000-0000-0000-0000-000000000001'
    order by league.external_league_id
  $$,
  $$
    values
      (
        'league-a'::text,
        '2026-09-08T01:00:00Z'::timestamptz,
        'not_owned'::text,
        '2026-09-08T01:00:00Z'::timestamptz
      ),
      (
        'league-b'::text,
        '2026-09-08T01:00:00Z'::timestamptz,
        'owned'::text,
        '2026-09-08T01:00:00Z'::timestamptz
      )
  $$,
  'a newer not-owned observation cannot be overwritten by an older positive bundle'
);

create temporary table equal_replay_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from equal_replay_start),
  'league-a',
  jsonb_set(
    jsonb_set(
      pg_temp.roster_bundle('league-a','2026-09-08T01:00:00Z'),
      '{users}',
      '[]'::jsonb
    ),
    '{rosters}',
    '[]'::jsonb
  )
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from equal_replay_start),
  'league-b',
  pg_temp.roster_bundle(
    'league-b','2026-09-08T01:00:00Z','tracked-user','[]'::jsonb,
    '["known-0001"]'::jsonb,'["known-0001","0"]'::jsonb,
    '[]'::jsonb,'[]'::jsonb,'[]'::jsonb
  )
);
create temporary table equal_replay_completion as
select completed.*
from equal_replay_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, applied_shared_league_bundles,
      stale_shared_league_bundles_skipped,
      created_league_users, created_rosters, created_memberships,
      removed_league_users, removed_rosters, removed_memberships
    from equal_replay_completion
  $$,
  $$ values ('succeeded'::text, 2, 0, 0, 0, 0, 0, 0, 0) $$,
  'equal-time complete-bundle replay remains idempotently applicable'
);

create temporary table restore_owned_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from restore_owned_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-08T12:00:00Z'
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from restore_owned_start)
) as scoped(external_league_id);
create temporary table restore_owned_completion as
select completed.*
from restore_owned_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, owned_leagues, confirmed_not_owned_leagues,
      unresolved_ownership_leagues, reactivated_ownerships,
      active_owned_rosters, active_owned_memberships
    from restore_owned_completion
  $$,
  $$ values ('succeeded'::text, 2, 0, 0, 1, 2, 4) $$,
  'a later newer confirmed match restores owned state and current holdings'
);
select results_eq(
  $$
    select
      (select count(*)::integer
       from public.fantasy_account_rosters
       where fantasy_account_id =
         '82000000-0000-0000-0000-000000000001'),
      (select count(*)::integer
       from public.fantasy_account_rosters
       where fantasy_account_id =
         '82000000-0000-0000-0000-000000000001'
         and removed_at is null),
      (select count(*)::integer
       from public.fantasy_account_leagues
       where fantasy_account_id =
         '82000000-0000-0000-0000-000000000004'
         and roster_ownership_status = 'not_owned')
  $$,
  $$ values (2, 2, 2) $$,
  'ownership restoration creates no duplicate and leaves another account independent'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_rosters
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
      and removed_at is null
  ),
  2,
  'another app user tracking the same canonical account reads the same active ownership'
);
reset role;

create temporary table multiple_match_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
create temporary table multiple_match_bundle as
select
  scoped.external_league_id,
  jsonb_set(
    source.bundle,
    '{rosters}',
    (source.bundle -> 'rosters') || jsonb_build_array(
      jsonb_set(
        source.bundle -> 'rosters' -> 0,
        '{external_roster_id}',
        '2'::jsonb
      )
    )
  ) as bundle
from pg_catalog.unnest(
  (select expected_external_league_ids from multiple_match_start)
) as scoped(external_league_id)
cross join lateral (
  select pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-09T01:00:00Z'
  ) as bundle
) as source;
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from multiple_match_start),
  external_league_id,
  bundle
)
from multiple_match_bundle;
select throws_ok(
  format(
    $sql$
      select * from public.complete_sleeper_roster_sync(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid
      )
    $sql$,
    (select sync_run_id from multiple_match_start)
  ),
  '22023',
  'The Sleeper account matched more than one roster in one league.',
  'two ownership matches reject and roll back the entire completion'
);
select results_eq(
  $$
    select count(*)::integer,
      (select status from public.sync_runs
       where id = (select sync_run_id from multiple_match_start))
    from public.rosters
  $$,
  $$ values (2, 'running'::text) $$,
  'invalid ownership publishes no partial roster rows and leaves the run fail-able'
);
select public.fail_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from multiple_match_start),
  'invalid_ownership',
  'The normalized ownership collection is invalid.',
  false
);

update public.fantasy_account_leagues
set
  roster_ownership_status = 'unresolved',
  roster_ownership_observed_at = '2026-09-10T00:00:00Z'
where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  and league_id = '83000000-0000-0000-0000-000000000002';
create temporary table stale_ownership_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from stale_ownership_start),
  scoped.external_league_id,
  pg_temp.roster_bundle(
    scoped.external_league_id,
    '2026-09-08T18:00:00Z'
  )
)
from pg_catalog.unnest(
  (select expected_external_league_ids from stale_ownership_start)
) as scoped(external_league_id);
create temporary table stale_ownership_completion as
select completed.*
from stale_ownership_start as started
cross join lateral public.complete_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id
) as completed;
select results_eq(
  $$
    select final_status, owned_leagues, unresolved_ownership_leagues,
      stale_ownership_resolutions_skipped, active_owned_rosters,
      active_owned_memberships
    from stale_ownership_completion
  $$,
  $$ values ('partial'::text, 1, 1, 1, 1, 2) $$,
  'an ownership resolution older than its account-league watermark is skipped and counted'
);
select results_eq(
  $$
    select roster_ownership_status, roster_ownership_observed_at,
      (select count(*)::integer
       from public.fantasy_account_rosters as ownership
       where ownership.fantasy_account_id = association.fantasy_account_id
         and ownership.league_id = association.league_id
         and ownership.removed_at is null)
    from public.fantasy_account_leagues as association
    where association.fantasy_account_id =
      '82000000-0000-0000-0000-000000000001'
      and association.league_id =
        '83000000-0000-0000-0000-000000000002'
  $$,
  $$ values ('unresolved'::text, '2026-09-10T00:00:00Z'::timestamptz, 1) $$,
  'skipped unresolved ownership preserves history but excludes it from current owned totals'
);

create temporary table failure_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
create temporary table public_counts_before_failure as
select
  (select count(*) from public.league_users) as league_users,
  (select count(*) from public.rosters) as rosters,
  (select count(*) from public.fantasy_account_rosters) as ownerships,
  (select count(*) from public.roster_players) as memberships;
select public.stage_sleeper_roster_league_bundle(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  (select sync_run_id from failure_start),
  'league-a',
  pg_temp.roster_bundle('league-a','2026-09-05T01:00:00Z')
);
create temporary table failed_run as
select failed.*
from failure_start as started
cross join lateral public.fail_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  started.sync_run_id,
  'source_unavailable',
  'Sleeper is temporarily unavailable. Try again.',
  true
) as failed;
select results_eq(
  $$ select status, changed_run from failed_run $$,
  $$ values ('failed'::text, true) $$,
  'explicit failure is terminal'
);
select is(
  (
    select count(*)::integer from app_private.sleeper_roster_sync_stage
    where run_id = (select sync_run_id from failure_start)
  ),
  0,
  'failure cleans staged bundles'
);
select is(
  (
    select count(*)::integer from app_private.sleeper_roster_sync_scopes
    where run_id = (select sync_run_id from failure_start)
  ),
  0,
  'failure cleans frozen scope'
);
select results_eq(
  format(
    $sql$
      select status, changed_run
      from public.fail_sleeper_roster_sync(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        %L::uuid,
        'source_unavailable',
        'Sleeper is temporarily unavailable. Try again.',
        true
      )
    $sql$,
    (select sync_run_id from failure_start)
  ),
  $$ values ('failed'::text, false) $$,
  'repeated failure of a terminal run is idempotent'
);
select is(
  (
    select error_summary ->> 'code' from public.sync_runs
    where id = (select sync_run_id from failure_start)
  ),
  'source_unavailable',
  'failure stores only the bounded safe error category'
);
select results_eq(
  $$
    select
      (select count(*) from public.league_users),
      (select count(*) from public.rosters),
      (select count(*) from public.fantasy_account_rosters),
      (select count(*) from public.roster_players)
  $$,
  $$
    select league_users, rosters, ownerships, memberships
    from public_counts_before_failure
  $$,
  'failure preserves every previously published public row'
);

create temporary table stale_start (sync_run_id uuid primary key);
insert into stale_start values (gen_random_uuid());
insert into public.sync_runs (
  id,
  fantasy_account_id,
  triggered_by_user_id,
  provider,
  sport,
  season,
  scope,
  status,
  progress_current,
  progress_total,
  started_at,
  created_at,
  updated_at
)
select
  sync_run_id,
  '82000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  'sleeper',
  'nfl',
  2026,
  'roster_sync',
  'running',
  0,
  2,
  now() - interval '16 minutes',
  now() - interval '16 minutes',
  now() - interval '16 minutes'
from stale_start;
insert into app_private.sleeper_roster_sync_scopes (
  run_id,
  league_season,
  expected_external_league_ids,
  scope_hash,
  created_at
)
select
  sync_run_id,
  2026,
  array['league-a','league-b']::text[],
  app_private.sleeper_roster_scope_hash(
    2026,
    array['league-a','league-b']::text[]
  ),
  now() - interval '16 minutes'
from stale_start;
create temporary table recovered_start as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select results_eq(
  $$ select created_run, reused_run, recovered_stale_run from recovered_start $$,
  $$ values (true, false, true) $$,
  'a stale running roster sync is failed, cleaned, and replaced'
);
select is(
  (
    select error_summary ->> 'code' from public.sync_runs
    where id = (select sync_run_id from stale_start)
  ),
  'stale_roster_sync',
  'stale recovery retains bounded stale-run metadata'
);

delete from app_private.sleeper_roster_sync_scopes
where run_id = (select sync_run_id from recovered_start);
create temporary table invalid_scope_recovery as
select * from public.start_sleeper_roster_sync(
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001'
);
select ok(
  (select recovered_stale_run and created_run from invalid_scope_recovery),
  'a fresh run with missing private scope is recovered safely'
);
select is(
  (
    select error_summary ->> 'code' from public.sync_runs
    where id = (select sync_run_id from recovered_start)
  ),
  'invalid_sync_scope',
  'missing-scope recovery records bounded invalid-scope metadata'
);

select * from finish();
rollback;
