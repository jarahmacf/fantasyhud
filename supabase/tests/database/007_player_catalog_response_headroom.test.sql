begin;

select plan(18);

select lives_ok(
  $$
    insert into public.provider_catalog_runs (
      id, provider, sport, catalog, status, source_bytes,
      started_at, finished_at
    ) values (
      '73000000-0000-0000-0000-000000000001',
      'sleeper', 'nfl', 'players', 'failed', 15000001, now(), now()
    )
  $$,
  'the run table accepts a source one byte above the former limit'
);
select lives_ok(
  $$
    insert into public.provider_catalog_runs (
      id, provider, sport, catalog, status, source_bytes,
      started_at, finished_at
    ) values (
      '73000000-0000-0000-0000-000000000002',
      'sleeper', 'nfl', 'players', 'failed', 25000000, now(), now()
    )
  $$,
  'the run table accepts the exact new source-byte limit'
);
select throws_ok(
  $$
    insert into public.provider_catalog_runs (
      id, provider, sport, catalog, status, source_bytes,
      started_at, finished_at
    ) values (
      '73000000-0000-0000-0000-000000000003',
      'sleeper', 'nfl', 'players', 'failed', 25000001, now(), now()
    )
  $$,
  '23514',
  null,
  'the run table rejects one byte above the new limit'
);
select lives_ok(
  $$
    insert into public.provider_catalog_runs (
      id, provider, sport, catalog, status, source_record_count,
      started_at, finished_at
    ) values (
      '73000000-0000-0000-0000-000000000004',
      'sleeper', 'nfl', 'players', 'failed', 50000, now(), now()
    )
  $$,
  'the existing 50000-record table maximum remains accepted'
);
select throws_ok(
  $$
    insert into public.provider_catalog_runs (
      id, provider, sport, catalog, status, source_record_count,
      started_at, finished_at
    ) values (
      '73000000-0000-0000-0000-000000000005',
      'sleeper', 'nfl', 'players', 'failed', 50001, now(), now()
    )
  $$,
  '23514',
  null,
  'the existing record-count maximum remains enforced'
);

select has_function(
  'public',
  'stage_sleeper_player_catalog_batch',
  array['uuid', 'uuid', 'integer', 'integer', 'timestamptz', 'integer', 'jsonb'],
  'the stage function retains its exact argument signature'
);
select is(
  pg_get_function_result(
    'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure
  ),
  'TABLE(catalog_run_id uuid, staged_records integer, total_staged_records integer, progress_total integer, replayed_batch boolean)',
  'the stage function retains its exact result shape'
);
select ok(
  (
    select prosecdef
    from pg_proc
    where oid =
      'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure
  ),
  'the stage function remains SECURITY DEFINER'
);
select ok(
  (
    select proconfig @> array[
      'search_path=pg_catalog',
      'statement_timeout=10s'
    ]
    from pg_proc
    where oid =
      'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)'::regprocedure
  ),
  'the stage function retains its fixed path and timeout'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)',
    'execute'
  ),
  'browser roles cannot execute the stage function'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)',
    'execute'
  )
  and has_function_privilege(
    'postgres',
    'public.stage_sleeper_player_catalog_batch(uuid,uuid,integer,integer,timestamptz,integer,jsonb)',
    'execute'
  ),
  'server roles can execute the stage function'
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
  'service_role retains no direct CRUD on player catalog tables'
);
select col_type_is(
  'public',
  'provider_catalog_runs',
  'source_bytes',
  'integer',
  'the source-byte column type remains unchanged'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '74000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'task007a1@example.test', '', now(),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  now(), now(), '', '', '', ''
);

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, updated_at
)
values (
  '74000000-0000-0000-0000-000000000002',
  'sleeper', 'task007a1', 'Task007A1', 'task007a1', '{}'::jsonb, now()
);

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  true
);

insert into public.provider_catalog_runs (
  id, provider, sport, catalog, triggered_by_user_id, status, started_at
)
values (
  '74000000-0000-0000-0000-000000000003',
  'sleeper', 'nfl', 'players',
  '74000000-0000-0000-0000-000000000001',
  'running', now()
);

create function pg_temp.player_catalog_record(
  p_external_id text,
  p_fetched_at timestamptz
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'external_player_id', p_external_id,
    'profile', jsonb_build_object(
      'sport', 'nfl',
      'entity_type', 'player',
      'display_name', 'Headroom Fixture',
      'first_name', 'Headroom',
      'last_name', 'Fixture',
      'full_name', 'Headroom Fixture',
      'primary_position', 'WR',
      'fantasy_positions', jsonb_build_array('WR'),
      'nfl_team', null,
      'active', true,
      'status', 'Active',
      'jersey_number', 10,
      'age', 25,
      'height', '6-1',
      'weight', '205',
      'years_experience', 3,
      'college', null,
      'high_school', null,
      'birth_country', null,
      'depth_chart_position', null,
      'depth_chart_order', null,
      'injury_status', null,
      'injury_body_part', null,
      'injury_start_date', null,
      'practice_participation', null,
      'news_updated_at', null,
      'search_rank', 100,
      'profile_source', 'sleeper',
      'source_metadata', jsonb_build_object(
        'normalization_warning_fields', '[]'::jsonb,
        'unmodeled_fields', '{}'::jsonb
      ),
      'profile_fetched_at', p_fetched_at
    ),
    'external_ids', '[]'::jsonb,
    'normalization_warning_count', 0
  );
$$;

select results_eq(
  $$
    select staged_records, total_staged_records, progress_total, replayed_batch
    from public.stage_sleeper_player_catalog_batch(
      '74000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000003',
      0,
      500,
      '2026-09-01T05:30:00Z',
      20000000,
      jsonb_build_array(
        pg_temp.player_catalog_record(
          'headroom-0001',
          '2026-09-01T05:30:00Z'
        )
      )
    )
  $$,
  $$ values (1, 1, 500, false) $$,
  'a valid first batch establishes a source envelope above 15 MB'
);
select is(
  (
    select source_bytes
    from public.provider_catalog_runs
    where id = '74000000-0000-0000-0000-000000000003'
  ),
  20000000,
  'the run stores the exact expanded test envelope'
);
select throws_ok(
  $$
    select *
    from public.stage_sleeper_player_catalog_batch(
      '74000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000003',
      1,
      500,
      '2026-09-01T05:30:00Z',
      20000001,
      jsonb_build_array(
        pg_temp.player_catalog_record(
          'headroom-0002',
          '2026-09-01T05:30:00Z'
        )
      )
    )
  $$,
  '22023',
  'The player-catalog source envelope changed between batches.',
  'later batches cannot change the established source envelope'
);
select throws_ok(
  $$
    select *
    from public.stage_sleeper_player_catalog_batch(
      '74000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000003',
      1,
      500,
      '2026-09-01T05:30:00Z',
      25000001,
      jsonb_build_array(
        pg_temp.player_catalog_record(
          'headroom-0002',
          '2026-09-01T05:30:00Z'
        )
      )
    )
  $$,
  '22023',
  'The player-catalog batch envelope is invalid.',
  'the stage function rejects one byte above the new limit'
);
select results_eq(
  $$
    select
      (select count(*)::integer
       from app_private.sleeper_player_catalog_stage),
      (select count(*)::integer from public.players)
  $$,
  $$ values (1, 0) $$,
  'expanded-envelope staging remains private and publishes no player rows'
);

select * from finish();

rollback;
