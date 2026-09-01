begin;

select no_plan();

select has_table('public', 'players', 'canonical players table exists');
select has_table(
  'public', 'player_external_ids',
  'player external identity table exists'
);
select has_table(
  'public', 'provider_catalog_runs',
  'global provider catalog run table exists'
);
select has_table(
  'app_private', 'sleeper_player_catalog_stage',
  'private player catalog staging table exists'
);

select col_not_null(
  'public', 'players', 'profile_fetched_at',
  'canonical profiles require a fetch observation time'
);
select col_type_is(
  'public', 'players', 'fantasy_positions', 'text[]',
  'fantasy positions are exact text tokens'
);
select col_type_is(
  'public', 'player_external_ids', 'external_id', 'text',
  'external IDs remain text'
);
select fk_ok(
  'public', 'player_external_ids', 'player_id',
  'public', 'players', 'id',
  'external IDs reference canonical players'
);
select fk_ok(
  'app_private', 'sleeper_player_catalog_stage', 'run_id',
  'public', 'provider_catalog_runs', 'id',
  'staging belongs to one catalog run'
);

select is(
  (
    select count(*)::integer
    from (values
      ('public.players'),
      ('public.player_external_ids'),
      ('public.provider_catalog_runs'),
      ('app_private.sleeper_player_catalog_stage')
    ) as provider_table(name)
    where has_table_privilege('service_role', provider_table.name, 'select')
      or has_table_privilege('service_role', provider_table.name, 'insert')
      or has_table_privilege('service_role', provider_table.name, 'update')
      or has_table_privilege('service_role', provider_table.name, 'delete')
  ),
  0,
  'service_role has no direct CRUD on player catalog tables'
);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'players', 'player_external_ids', 'provider_catalog_runs'
      )
      and roles @> array['authenticated'::name]
      and cmd = 'SELECT'
  ),
  3,
  'authenticated reads have one policy on every public catalog table'
);

select has_function(
  'public', 'start_sleeper_player_catalog_sync', array['uuid'],
  'start catalog function exists'
);
select has_function(
  'public', 'stage_sleeper_player_catalog_batch',
  array['uuid', 'uuid', 'integer', 'integer', 'timestamptz', 'integer', 'jsonb'],
  'stage catalog function exists'
);
select has_function(
  'public', 'complete_sleeper_player_catalog_sync',
  array['uuid', 'uuid'],
  'complete catalog function exists'
);
select has_function(
  'public', 'fail_sleeper_player_catalog_sync',
  array['uuid', 'uuid', 'text', 'text', 'boolean'],
  'fail catalog function exists'
);

select is(
  (
    select count(*)::integer
    from pg_proc
    where oid in (
      'public.start_sleeper_player_catalog_sync(uuid)'::regprocedure,
      'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure,
      'public.complete_sleeper_player_catalog_sync(uuid,uuid)'::regprocedure,
      'public.fail_sleeper_player_catalog_sync(uuid,uuid,text,text,boolean)'::regprocedure
    )
      and prosecdef
      and proconfig @> array['search_path=pg_catalog']
  ),
  4,
  'every public catalog function is SECURITY DEFINER with a fixed path'
);
select is(
  (
    select count(*)::integer
    from pg_proc
    where oid in (
      'public.start_sleeper_player_catalog_sync(uuid)'::regprocedure,
      'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure,
      'public.fail_sleeper_player_catalog_sync(uuid,uuid,text,text,boolean)'::regprocedure
    )
      and proconfig @> array['statement_timeout=10s']
  ),
  3,
  'start, stage, and fail have short function timeouts'
);
select ok(
  (
    select proconfig @> array['statement_timeout=60s']
    from pg_proc
    where oid =
      'public.complete_sleeper_player_catalog_sync(uuid,uuid)'::regprocedure
  ),
  'completion is bounded to 60 seconds'
);
select is(
  (
    select count(*)::integer
    from pg_proc as procedure
    cross join lateral aclexplode(procedure.proacl) as acl
    where procedure.oid in (
      'public.start_sleeper_player_catalog_sync(uuid)'::regprocedure,
      'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure,
      'public.complete_sleeper_player_catalog_sync(uuid,uuid)'::regprocedure,
      'public.fail_sleeper_player_catalog_sync(uuid,uuid,text,text,boolean)'::regprocedure
    )
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  0,
  'PUBLIC cannot execute catalog lifecycle functions'
);
select is(
  (
    select count(*)::integer
    from (values
      ('public.start_sleeper_player_catalog_sync(uuid)'),
      ('public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'),
      ('public.complete_sleeper_player_catalog_sync(uuid,uuid)'),
      ('public.fail_sleeper_player_catalog_sync(uuid,uuid,text,text,boolean)')
    ) as function_name(name)
    where has_function_privilege('service_role', function_name.name, 'execute')
      and has_function_privilege('postgres', function_name.name, 'execute')
      and not has_function_privilege('anon', function_name.name, 'execute')
      and not has_function_privilege(
        'authenticated', function_name.name, 'execute'
      )
  ),
  4,
  'only server roles can execute all four catalog functions'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'task007a-a@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'task007a-b@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'task007a-unlinked@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
)
values
  (
    '71000000-0000-0000-0000-000000000001', 'sleeper',
    'task007a-a', 'Task007A', 'task007a', '{}'::jsonb, now()
  ),
  (
    '71000000-0000-0000-0000-000000000002', 'sleeper',
    'task007a-b', 'Task007B', 'task007b', '{}'::jsonb, now()
  );

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values
  (
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001', true
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000002', true
  );

create function pg_temp.player_catalog_record(
  p_external_id text,
  p_fetched_at timestamptz,
  p_display_name text default null,
  p_entity_type text default 'player',
  p_active boolean default true,
  p_warning_count integer default 0,
  p_external_ids jsonb default '[]'::jsonb,
  p_fantasy_positions jsonb default '["WR"]'::jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'external_player_id', p_external_id,
    'profile', jsonb_build_object(
      'sport', 'nfl',
      'entity_type', p_entity_type,
      'display_name', p_display_name,
      'first_name', null,
      'last_name', null,
      'full_name', p_display_name,
      'primary_position', case
        when p_entity_type = 'team_defense' then 'DEF'
        when p_entity_type = 'unknown' then null
        else 'WR'
      end,
      'fantasy_positions', p_fantasy_positions,
      'nfl_team', case when p_entity_type = 'team_defense' then 'SEA' else null end,
      'active', p_active,
      'status', 'Active',
      'jersey_number', 10,
      'age', 25,
      'height', '6-1',
      'weight', '205',
      'years_experience', 3,
      'college', 'Fixture University',
      'high_school', null,
      'birth_country', 'USA',
      'depth_chart_position', 1,
      'depth_chart_order', 1,
      'injury_status', null,
      'injury_body_part', null,
      'injury_start_date', null,
      'practice_participation', null,
      'news_updated_at', null,
      'search_rank', 100,
      'profile_source', 'sleeper',
      'source_metadata', jsonb_build_object(
        'normalization_warning_fields', case
          when p_warning_count > 0 then jsonb_build_array('fixture_field')
          else '[]'::jsonb
        end,
        'unmodeled_fields', '{}'::jsonb
      ),
      'profile_fetched_at', p_fetched_at
    ),
    'external_ids', p_external_ids,
    'normalization_warning_count', p_warning_count
  );
$$;

select throws_ok(
  $$
    select * from public.start_sleeper_player_catalog_sync(
      '70000000-0000-0000-0000-000000000003'
    )
  $$,
  '42501',
  'The app user must track a Sleeper fantasy account.',
  'an unlinked user cannot start the shared catalog'
);

create temporary table first_catalog_start as
select * from public.start_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000001'
);

create temporary table repeated_catalog_start as
select * from public.start_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000002'
);

select results_eq(
  $$
    select created_run, reused_run, catalog_fresh, recovered_stale_run
    from first_catalog_start
  $$,
  $$ values (true, false, false, false) $$,
  'the first eligible user creates the one global run'
);
select results_eq(
  $$
    select created_run, reused_run, catalog_fresh, recovered_stale_run
    from repeated_catalog_start
  $$,
  $$ values (false, true, false, false) $$,
  'a second user reuses the active global run'
);
select results_eq(
  $$ select catalog_run_id from repeated_catalog_start $$,
  $$ select catalog_run_id from first_catalog_start $$,
  'reused start returns the same run ID'
);

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_player_catalog_batch(
        '70000000-0000-0000-0000-000000000002',
        %L::uuid, 0, 500, '2026-08-31T12:00:00Z', 100000,
        jsonb_build_array(pg_temp.player_catalog_record(
          'p0000', '2026-08-31T12:00:00Z'
        ))
      )
    $sql$,
    (select catalog_run_id from first_catalog_start)
  ),
  '22023',
  'The catalog run does not match this running Sleeper player refresh.',
  'only the triggering user can stage the run'
);

insert into public.players (
  id, sport, entity_type, display_name, primary_position,
  fantasy_positions, active, status, profile_source,
  source_metadata, profile_fetched_at
)
values
  (
    '72000000-0000-0000-0000-000000000005', 'nfl', 'player',
    'Old Five', 'WR', array['WR'], true, 'Active', 'sleeper', '{}',
    '2026-08-30T12:00:00Z'
  ),
  (
    '72000000-0000-0000-0000-000000000006', 'nfl', 'player',
    'Newer Six', 'WR', array['WR'], true, 'Active', 'sleeper', '{}',
    '2026-09-01T12:00:00Z'
  ),
  (
    '72000000-0000-0000-0000-000000000008', 'nfl', 'player',
    'Old Eight', 'WR', array['WR'], true, 'Active', 'sleeper', '{}',
    '2026-08-30T12:00:00Z'
  ),
  (
    '72000000-0000-0000-0000-000000000090', 'nfl', 'player',
    'Absent Player', 'WR', array['WR'], true, 'Active', 'sleeper', '{}',
    '2026-08-30T12:00:00Z'
  ),
  (
    '72000000-0000-0000-0000-000000000091', 'nfl', 'player',
    'Conflict Owner', 'WR', array['WR'], true, 'Active', 'sleeper', '{}',
    '2026-08-30T12:00:00Z'
  );

insert into public.player_external_ids (
  player_id, namespace, sport, external_id, reported_by, is_primary,
  source_metadata, first_seen_at, last_seen_at, removed_at
)
values
  (
    '72000000-0000-0000-0000-000000000005', 'sleeper', 'nfl',
    'p0005', 'sleeper', true, '{}', '2026-08-01', '2026-08-02',
    '2026-08-03'
  ),
  (
    '72000000-0000-0000-0000-000000000006', 'sleeper', 'nfl',
    'p0006', 'sleeper', true, '{}', '2026-08-01', '2026-08-02',
    '2026-08-03'
  ),
  (
    '72000000-0000-0000-0000-000000000008', 'sleeper', 'nfl',
    'p0008', 'sleeper', true, '{}', '2026-08-01', '2026-08-02',
    '2026-08-03'
  ),
  (
    '72000000-0000-0000-0000-000000000090', 'sleeper', 'nfl',
    'absent-from-source', 'sleeper', true, '{}',
    '2026-08-01', '2026-08-02', null
  ),
  (
    '72000000-0000-0000-0000-000000000005', 'espn', 'nfl',
    'old-five', 'sleeper', false, '{}',
    '2026-08-01', '2026-08-02', null
  ),
  (
    '72000000-0000-0000-0000-000000000008', 'yahoo', 'nfl',
    'same-eight', 'sleeper', false, '{}',
    '2026-08-01', '2026-08-02', null
  ),
  (
    '72000000-0000-0000-0000-000000000091', 'stats', 'nfl',
    'owned-conflict', 'sleeper', false, '{}',
    '2026-08-01', '2026-08-02', null
  );

create temporary table catalog_batch as
select jsonb_agg(
  pg_temp.player_catalog_record(
    'p' || lpad(item::text, 4, '0'),
    '2026-08-31T12:00:00Z',
    case when item = 12 then null else 'Fixture ' || item end,
    case
      when item = 11 then 'team_defense'
      when item = 12 then 'unknown'
      else 'player'
    end,
    true,
    case when item = 9 then 1 else 0 end,
    case
      when item = 0 then '[{"namespace":"espn","external_id":"100","reported_by":"sleeper","source_field":"espn_id"}]'::jsonb
      when item in (1, 2) then '[{"namespace":"espn","external_id":"shared","reported_by":"sleeper","source_field":"espn_id"}]'::jsonb
      when item = 3 then '[{"namespace":"yahoo","external_id":"y-three","reported_by":"sleeper","source_field":"yahoo_id"}]'::jsonb
      when item = 4 then '[{"namespace":"stats","external_id":"owned-conflict","reported_by":"sleeper","source_field":"stats_id"}]'::jsonb
      when item = 5 then '[{"namespace":"espn","external_id":"new-five","reported_by":"sleeper","source_field":"espn_id"}]'::jsonb
      when item = 8 then '[{"namespace":"yahoo","external_id":"same-eight","reported_by":"sleeper","source_field":"yahoo_id"}]'::jsonb
      else '[]'::jsonb
    end,
    case when item = 10 then '["WR","RB"]'::jsonb else '["WR"]'::jsonb end
  ) order by item
) as records
from generate_series(0, 499) as source(item);

create temporary table first_stage as
select staged.*
from first_catalog_start as started
cross join catalog_batch as batch
cross join lateral public.stage_sleeper_player_catalog_batch(
  '70000000-0000-0000-0000-000000000001',
  started.catalog_run_id,
  0,
  500,
  '2026-08-31T12:00:00Z',
  100000,
  batch.records
) as staged;

select results_eq(
  $$
    select staged_records, total_staged_records, progress_total, replayed_batch
    from first_stage
  $$,
  $$ values (500, 500, 500, false) $$,
  'the first complete batch stages exactly 500 normalized records'
);

create temporary table replayed_stage as
select staged.*
from first_catalog_start as started
cross join catalog_batch as batch
cross join lateral public.stage_sleeper_player_catalog_batch(
  '70000000-0000-0000-0000-000000000001',
  started.catalog_run_id,
  0,
  500,
  '2026-08-31T12:00:00Z',
  100000,
  batch.records
) as staged;

select results_eq(
  $$ select total_staged_records, replayed_batch from replayed_stage $$,
  $$ values (500, true) $$,
  'an identical batch replay is idempotent'
);

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_player_catalog_batch(
        '70000000-0000-0000-0000-000000000001',
        %L::uuid, 1, 500, '2026-08-31T12:00:00Z', 100000,
        jsonb_build_array(pg_temp.player_catalog_record(
          'p0000', '2026-08-31T12:00:00Z', 'Changed'
        ))
      )
    $sql$,
    (select catalog_run_id from first_catalog_start)
  ),
  '22023',
  'A staged Sleeper ID changed across catalog batches.',
  'a changed duplicate Sleeper record fails closed'
);

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_player_catalog_batch(
        '70000000-0000-0000-0000-000000000001',
        %L::uuid, 1, 500, '2026-08-31T12:00:00Z', 100000,
        jsonb_build_array(
          pg_temp.player_catalog_record('duplicate', '2026-08-31T12:00:00Z'),
          pg_temp.player_catalog_record('duplicate', '2026-08-31T12:00:00Z')
        )
      )
    $sql$,
    (select catalog_run_id from first_catalog_start)
  ),
  '22023',
  'A player-catalog batch contains a duplicate Sleeper ID.',
  'duplicate IDs within one batch fail closed'
);

select throws_ok(
  format(
    $sql$
      select * from public.stage_sleeper_player_catalog_batch(
        '70000000-0000-0000-0000-000000000001',
        %L::uuid, 1, 500, '2026-08-31T12:00:00Z', 100000,
        jsonb_build_array(jsonb_build_object('raw', 'provider envelope'))
      )
    $sql$,
    (select catalog_run_id from first_catalog_start)
  ),
  '22023',
  'A normalized player-catalog record is invalid.',
  'raw or unsupported record shapes fail closed'
);

create temporary table completed_catalog as
select completed.*
from first_catalog_start as started
cross join lateral public.complete_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000001',
  started.catalog_run_id
) as completed;

select results_eq(
  $$
    select
      observed_records, created_players, updated_players,
      stale_player_profiles_skipped, created_sleeper_ids,
      reactivated_sleeper_ids, removed_sleeper_ids
    from completed_catalog
  $$,
  $$ values (500, 497, 2, 1, 497, 3, 1) $$,
  'completion reports canonical, monotonic, and primary-ID reconciliation'
);
select results_eq(
  $$
    select
      secondary_ids_created, secondary_ids_refreshed,
      secondary_ids_replaced, ambiguous_secondary_ids_skipped,
      conflicting_secondary_ids_skipped
    from completed_catalog
  $$,
  $$ values (2, 1, 1, 2, 1) $$,
  'secondary mappings are created, refreshed, replaced, or skipped safely'
);
select results_eq(
  $$
    select
      records_with_warnings, normalization_warning_count,
      active_players, team_defenses, unknown_entities
    from completed_catalog
  $$,
  $$ values (1, 1, 500, 1, 1) $$,
  'completion reports bounded warnings and entity categories'
);

select is(
  (select count(*)::integer from public.players p
   inner join public.player_external_ids external_id
     on external_id.player_id = p.id
   where external_id.namespace = 'sleeper'
     and external_id.sport = 'nfl'
     and external_id.is_primary
     and external_id.removed_at is null
     and external_id.external_id like 'p%'),
  500,
  'every observed Sleeper ID has one active canonical primary mapping'
);
select is(
  (
    select count(*)::integer
    from (
      select player_id
      from public.player_external_ids
      where namespace = 'sleeper'
        and sport = 'nfl'
        and is_primary
        and removed_at is null
      group by player_id
      having count(*) > 1
    ) as duplicate_primary
  ),
  0,
  'no canonical player has duplicate active primary mappings'
);
select is(
  (select display_name from public.players
   where id = '72000000-0000-0000-0000-000000000006'),
  'Newer Six',
  'an older completion cannot regress a newer profile'
);
select is(
  (select fantasy_positions from public.players
   inner join public.player_external_ids external_id
     on external_id.player_id = players.id
   where external_id.namespace = 'sleeper'
     and external_id.external_id = 'p0010'),
  array['WR', 'RB'],
  'dual fantasy positions preserve normalized source order'
);
select ok(
  exists (
    select 1 from public.player_external_ids
    where namespace = 'sleeper'
      and external_id = 'p0005'
      and removed_at is null
      and first_seen_at = '2026-08-01T00:00:00Z'
  ),
  'a removed primary Sleeper mapping reactivates without losing first seen'
);
select ok(
  exists (
    select 1 from public.player_external_ids
    where namespace = 'sleeper'
      and external_id = 'absent-from-source'
      and removed_at is not null
  ),
  'an absent primary mapping is retained as removed history'
);
select ok(
  exists (
    select 1 from public.player_external_ids
    where namespace = 'espn'
      and external_id = 'old-five'
      and removed_at is not null
  ) and exists (
    select 1 from public.player_external_ids
    where namespace = 'espn'
      and external_id = 'new-five'
      and removed_at is null
  ),
  'a changed same-player secondary mapping preserves replaced history'
);
select is(
  (select count(*)::integer from public.player_external_ids
   where namespace = 'espn' and external_id = 'shared'),
  0,
  'ambiguous current-source secondary IDs do not publish'
);
select is(
  (select player_id from public.player_external_ids
   where namespace = 'stats' and external_id = 'owned-conflict'),
  '72000000-0000-0000-0000-000000000091'::uuid,
  'a secondary-ID conflict never reassigns or merges its canonical player'
);
select is(
  (select count(*)::integer
   from app_private.sleeper_player_catalog_stage),
  0,
  'successful completion deletes private staging'
);
select results_eq(
  $$
    select status, progress_current, progress_total,
      error_summary = '{}'::jsonb
    from public.provider_catalog_runs
    where id = (select catalog_run_id from first_catalog_start)
  $$,
  $$ values ('succeeded'::text, 500, 500, true) $$,
  'the catalog run becomes a clean succeeded terminal attempt'
);
select is(
  (select count(*)::integer from public.fantasy_accounts
   where last_synced_at is not null),
  0,
  'the shared catalog does not update portfolio synchronization time'
);

create temporary table fresh_catalog_start as
select * from public.start_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000002'
);

select results_eq(
  $$ select created_run, reused_run, catalog_fresh from fresh_catalog_start $$,
  $$ values (false, false, true) $$,
  'a second user receives the globally fresh catalog without a new run'
);
select is(
  (select count(*)::integer from public.provider_catalog_runs),
  1,
  'freshness creates no extra catalog attempt'
);

set local role authenticated;
select lives_ok(
  $$ select count(*) from public.players $$,
  'authenticated users can read the canonical player catalog'
);
select lives_ok(
  $$ select count(*) from public.player_external_ids $$,
  'authenticated users can read active and historical external mappings'
);
select lives_ok(
  $$ select count(*) from public.provider_catalog_runs $$,
  'authenticated users can read sanitized catalog run state'
);
select throws_ok(
  $$ delete from public.players $$,
  '42501',
  null,
  'authenticated users cannot mutate canonical players'
);
reset role;

update public.provider_catalog_runs
set source_fetched_at = now() - interval '25 hours'
where id = (select catalog_run_id from first_catalog_start);

create temporary table old_freshness_start as
select * from public.start_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000001'
);

alter table public.provider_catalog_runs
disable trigger provider_catalog_runs_set_updated_at;
update public.provider_catalog_runs
set updated_at = now() - interval '16 minutes'
where id = (select catalog_run_id from old_freshness_start);
alter table public.provider_catalog_runs
enable trigger provider_catalog_runs_set_updated_at;

insert into app_private.sleeper_player_catalog_stage (
  run_id, external_player_id, player_id, batch_index,
  record_hash, normalized_record
)
select
  catalog_run_id, 'stale-stage', gen_random_uuid(), 0,
  md5(pg_temp.player_catalog_record(
    'stale-stage', '2026-08-31T13:00:00Z'
  )::text),
  pg_temp.player_catalog_record('stale-stage', '2026-08-31T13:00:00Z')
from old_freshness_start;

create temporary table recovered_start as
select * from public.start_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000002'
);

select results_eq(
  $$
    select created_run, reused_run, catalog_fresh, recovered_stale_run
    from recovered_start
  $$,
  $$ values (true, false, false, true) $$,
  'a stale global run is failed and replaced under the catalog lock'
);
select results_eq(
  $$
    select status, error_summary ->> 'code',
      error_summary ->> 'stage', finished_at is not null
    from public.provider_catalog_runs
    where id = (select catalog_run_id from old_freshness_start)
  $$,
  $$ values ('failed'::text, 'stale_catalog_run'::text,
    'player_catalog'::text, true) $$,
  'stale recovery stores only bounded operational metadata'
);
select is(
  (select count(*)::integer
   from app_private.sleeper_player_catalog_stage
   where run_id = (select catalog_run_id from old_freshness_start)),
  0,
  'stale recovery deletes abandoned private staging'
);

insert into app_private.sleeper_player_catalog_stage (
  run_id, external_player_id, player_id, batch_index,
  record_hash, normalized_record
)
select
  catalog_run_id, 'failed-stage', gen_random_uuid(), 0,
  md5(pg_temp.player_catalog_record(
    'failed-stage', '2026-08-31T14:00:00Z'
  )::text),
  pg_temp.player_catalog_record('failed-stage', '2026-08-31T14:00:00Z')
from recovered_start;

create temporary table failed_catalog as
select failed.*
from recovered_start as started
cross join lateral public.fail_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000002',
  started.catalog_run_id,
  'source_unavailable',
  'Sleeper is temporarily unavailable. Try again.',
  true
) as failed;

select results_eq(
  $$ select status, changed_run from failed_catalog $$,
  $$ values ('failed'::text, true) $$,
  'failure makes the replacement run terminal'
);
select is(
  (select count(*)::integer
   from app_private.sleeper_player_catalog_stage
   where run_id = (select catalog_run_id from recovered_start)),
  0,
  'failure deletes only its private staging rows'
);
select is(
  (select count(*)::integer from public.players),
  502,
  'failure preserves the previously successful public player catalog'
);

create temporary table repeated_failure as
select failed.*
from recovered_start as started
cross join lateral public.fail_sleeper_player_catalog_sync(
  '70000000-0000-0000-0000-000000000002',
  started.catalog_run_id,
  'source_unavailable',
  'Sleeper is temporarily unavailable. Try again.',
  true
) as failed;

select results_eq(
  $$ select status, changed_run from repeated_failure $$,
  $$ values ('failed'::text, false) $$,
  'repeated failure on a terminal run is documented and idempotent'
);

select * from finish();

rollback;
