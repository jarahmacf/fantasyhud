begin;

select plan(87);

select has_table('public', 'provider_season_states', 'provider season states exist');
select has_table('public', 'leagues', 'shared leagues exist');
select has_table(
  'public',
  'fantasy_account_leagues',
  'fantasy-account league discovery associations exist'
);
select has_table('public', 'sync_runs', 'sync run observability exists');

select col_type_is(
  'public',
  'provider_season_states',
  'provider',
  'text',
  'provider season-state provider is text'
);
select col_type_is(
  'public',
  'provider_season_states',
  'season',
  'integer',
  'provider season is an integer'
);
select col_type_is(
  'public',
  'provider_season_states',
  'fetched_at',
  'timestamp with time zone',
  'provider fetch time is timezone-aware'
);
select col_type_is(
  'public',
  'leagues',
  'external_league_id',
  'text',
  'external league IDs remain exact text'
);
select col_type_is(
  'public',
  'leagues',
  'settings',
  'jsonb',
  'exact league settings use JSONB'
);
select col_type_is(
  'public',
  'leagues',
  'roster_positions',
  'jsonb',
  'exact roster positions use JSONB'
);
select col_type_is(
  'public',
  'leagues',
  'is_best_ball',
  'boolean',
  'best ball is an independent boolean'
);
select col_type_is(
  'public',
  'fantasy_account_leagues',
  'fantasy_account_id',
  'uuid',
  'discovery associations reference fantasy accounts by UUID'
);
select col_type_is(
  'public',
  'fantasy_account_leagues',
  'league_id',
  'uuid',
  'discovery associations reference leagues by UUID'
);
select col_type_is(
  'public',
  'sync_runs',
  'triggered_by_user_id',
  'uuid',
  'optional triggering app user is a UUID'
);
select col_type_is(
  'public',
  'sync_runs',
  'result_counts',
  'jsonb',
  'sync result counts use bounded JSONB'
);
select col_type_is(
  'public',
  'sync_runs',
  'progress_current',
  'integer',
  'sync progress is an integer'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.provider_season_states'::regclass),
  'provider_season_states has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.leagues'::regclass),
  'leagues has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.fantasy_account_leagues'::regclass),
  'fantasy_account_leagues has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.sync_runs'::regclass),
  'sync_runs has RLS enabled'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.leagues'::regclass
      and conname = 'leagues_provider_external_league_id_key'
      and contype = 'u'
  ),
  'provider and external league ID form one canonical identity'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fantasy_account_leagues'::regclass
      and conname = 'fantasy_account_leagues_account_league_key'
      and contype = 'u'
  ),
  'one fantasy account associates with a league at most once'
);
select ok(
  exists (
    select 1
    from pg_class as index_relation
    inner join pg_index as index_definition
      on index_definition.indexrelid = index_relation.oid
    where index_relation.relname =
        'sync_runs_one_running_league_discovery_per_account_idx'
      and index_definition.indisunique
      and index_definition.indpred is not null
  ),
  'running league-discovery uniqueness is a partial unique index'
);
select ok(
  not exists (
    select 1
    from pg_index as index_definition
    inner join pg_attribute as attribute
      on attribute.attrelid = index_definition.indrelid
      and attribute.attname = 'name'
    where index_definition.indrelid = 'public.leagues'::regclass
      and index_definition.indisunique
      and attribute.attnum = any (index_definition.indkey::smallint[])
  ),
  'league name is not globally unique'
);
select hasnt_column(
  'public',
  'leagues',
  'user_id',
  'shared leagues contain no app-user ownership column'
);
select has_column(
  'public',
  'leagues',
  'roster_management_type',
  'roster management is an independent dimension'
);
select has_column(
  'public',
  'leagues',
  'is_best_ball',
  'best ball is an independent dimension'
);
select has_column(
  'public',
  'leagues',
  'has_superflex',
  'superflex is an independent dimension'
);
select has_column(
  'public',
  'leagues',
  'has_idp',
  'IDP is an independent dimension'
);
select is(
  (
    select count(*)::integer
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'league_users',
        'rosters',
        'roster_players',
        'fantasy_account_rosters',
        'players',
        'player_external_ids',
        'drafts',
        'fantasy_account_drafts',
        'draft_picks',
        'matchup_entries',
        'matchup_player_points',
        'transactions',
        'transaction_players',
        'transaction_draft_picks',
        'playoff_bracket_entries',
        'league_standing_snapshots',
        'player_stat_snapshots',
        'player_ranking_snapshots',
        'market_adp_snapshots',
        'market_adp_values',
        'sync_run_items',
        'provider_resource_cache',
        'scheduled_refreshes'
      )
  ),
  0,
  'future child, cache, queue, ranking, and fact tables are deferred'
);

select has_index(
  'public',
  'fantasy_account_leagues',
  'fantasy_account_leagues_active_account_idx',
  'active league discovery by fantasy account is indexed'
);
select has_index(
  'public',
  'fantasy_account_leagues',
  'fantasy_account_leagues_league_account_idx',
  'league-to-account authorization is indexed'
);
select has_index(
  'public',
  'sync_runs',
  'sync_runs_account_created_at_idx',
  'account sync history is indexed'
);
select has_index(
  'public',
  'sync_runs',
  'sync_runs_scope_status_idx',
  'sync scope and status filtering is indexed'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '50000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'task005-a@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '50000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'task005-b@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

insert into public.fantasy_accounts (
  id,
  provider,
  external_user_id,
  username,
  normalized_username
)
values
  (
    '51000000-0000-0000-0000-000000000001',
    'sleeper',
    '900719925474099312345',
    'TaskFiveA',
    'taskfivea'
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    'sleeper',
    '900719925474099312346',
    'TaskFiveB',
    'taskfiveb'
  );

insert into public.user_fantasy_accounts (
  user_id,
  fantasy_account_id,
  is_primary
)
values
  (
    '50000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    true
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '51000000-0000-0000-0000-000000000002',
    true
  );

insert into public.provider_season_states (
  id,
  provider,
  sport,
  season,
  league_season,
  league_create_season,
  previous_season,
  season_type,
  week,
  leg,
  display_week,
  season_start_date,
  provider_metadata,
  fetched_at,
  updated_at
)
values (
  '52000000-0000-0000-0000-000000000001',
  'sleeper',
  'nfl',
  2026,
  2026,
  2026,
  2025,
  'regular',
  1,
  1,
  1,
  '2026-09-10',
  '{"source":"state"}'::jsonb,
  now(),
  '2000-01-01 00:00:00+00'
);

insert into public.leagues (
  id,
  provider,
  external_league_id,
  sport,
  season,
  name,
  status,
  season_type,
  team_count,
  roster_size,
  roster_management_type,
  is_best_ball,
  has_superflex,
  has_idp,
  scoring_format,
  settings,
  scoring_settings,
  roster_positions,
  provider_metadata,
  provider_updated_at,
  updated_at
)
values
  (
    '53000000-0000-0000-0000-000000000001',
    'sleeper',
    '900719925474099399991',
    'nfl',
    2026,
    'Shared league name',
    'pre_draft',
    'regular',
    12,
    18,
    'dynasty',
    true,
    true,
    false,
    'ppr',
    '{"type":2}'::jsonb,
    '{"rec":1}'::jsonb,
    '["QB","RB","WR","SUPER_FLEX","BN"]'::jsonb,
    '{"source":"league"}'::jsonb,
    now(),
    '2000-01-01 00:00:00+00'
  ),
  (
    '53000000-0000-0000-0000-000000000002',
    'sleeper',
    '900719925474099399992',
    'nfl',
    2026,
    'Shared league name',
    'in_season',
    'regular',
    10,
    16,
    'redraft',
    false,
    false,
    false,
    'half_ppr',
    '{}'::jsonb,
    '{}'::jsonb,
    '["QB","RB","WR","BN"]'::jsonb,
    '{}'::jsonb,
    now(),
    '2000-01-01 00:00:00+00'
  );

insert into public.fantasy_account_leagues (
  id,
  fantasy_account_id,
  league_id,
  first_seen_at,
  last_seen_at,
  updated_at
)
values
  (
    '54000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    '2026-08-31 00:00:00+00',
    '2026-08-31 01:00:00+00',
    '2000-01-01 00:00:00+00'
  ),
  (
    '54000000-0000-0000-0000-000000000002',
    '51000000-0000-0000-0000-000000000002',
    '53000000-0000-0000-0000-000000000001',
    '2026-08-31 00:00:00+00',
    '2026-08-31 01:00:00+00',
    '2000-01-01 00:00:00+00'
  ),
  (
    '54000000-0000-0000-0000-000000000003',
    '51000000-0000-0000-0000-000000000002',
    '53000000-0000-0000-0000-000000000002',
    '2026-08-31 00:00:00+00',
    '2026-08-31 01:00:00+00',
    '2000-01-01 00:00:00+00'
  );

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
  result_counts,
  error_summary,
  started_at,
  finished_at,
  updated_at
)
values
  (
    '55000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    'sleeper',
    'nfl',
    2026,
    'league_discovery',
    'running',
    0,
    0,
    '{}'::jsonb,
    '{}'::jsonb,
    '2026-08-31 02:00:00+00',
    null,
    '2000-01-01 00:00:00+00'
  ),
  (
    '55000000-0000-0000-0000-000000000002',
    '51000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000002',
    'sleeper',
    'nfl',
    2026,
    'league_discovery',
    'succeeded',
    2,
    2,
    '{"leagues":2}'::jsonb,
    '{}'::jsonb,
    '2026-08-31 02:00:00+00',
    '2026-08-31 02:01:00+00',
    '2000-01-01 00:00:00+00'
  );

select is(
  (
    select count(*)::integer
    from public.leagues
    where provider = 'sleeper'
      and external_league_id = '900719925474099399991'
  ),
  1,
  'one provider resource has one shared league row'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_leagues
    where league_id = '53000000-0000-0000-0000-000000000001'
  ),
  2,
  'two fantasy accounts can associate with one shared league'
);
select is(
  (
    select count(distinct fantasy_account_id)::integer
    from public.fantasy_account_leagues
    where league_id = '53000000-0000-0000-0000-000000000001'
  ),
  2,
  'shared-league discovery associations remain distinct'
);
select is(
  (select count(*)::integer from public.leagues where name = 'Shared league name'),
  2,
  'two unrelated leagues may share a display name'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', '900719925474099399991', 'nfl', 2026, 'Duplicate',
      'pre_draft', 'regular', 12, 18, 'dynasty', false, false, false,
      'ppr', '{}'::jsonb, '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23505',
  null,
  'provider and external league identity remains canonical'
);

select throws_ok(
  $$
    insert into public.provider_season_states (
      provider, sport, season, league_season, season_type,
      provider_metadata, fetched_at
    ) values ('Sleeper', 'nfl', 2026, 2026, 'regular', '{}'::jsonb, now())
  $$,
  '23514',
  null,
  'unsafe provider identifiers are rejected'
);
select throws_ok(
  $$
    insert into public.provider_season_states (
      provider, sport, season, league_season, season_type,
      provider_metadata, fetched_at
    ) values ('espn', 'nfl', 999, 2026, 'regular', '{}'::jsonb, now())
  $$,
  '23514',
  null,
  'non-four-digit provider seasons are rejected'
);
select throws_ok(
  $$
    insert into public.provider_season_states (
      provider, sport, season, league_season, season_type,
      provider_metadata, fetched_at
    ) values ('espn', 'nfl', 2026, 2026, 'regular', '[]'::jsonb, now())
  $$,
  '23514',
  null,
  'provider metadata arrays are rejected'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'bad-settings', 'nfl', 2026, 'Bad settings', 'pre_draft',
      'regular', 12, 18, 'dynasty', false, false, false, 'ppr', '[]'::jsonb,
      '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'league settings arrays are rejected'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'bad-roster-positions', 'nfl', 2026, 'Bad positions',
      'pre_draft', 'regular', 12, 18, 'dynasty', false, false, false, 'ppr',
      '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'roster positions must be an array'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'zero-teams', 'nfl', 2026, 'Zero teams', 'pre_draft',
      'regular', 0, 18, 'dynasty', false, false, false, 'ppr', '{}'::jsonb,
      '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'nonpositive team counts are rejected'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'negative-roster', 'nfl', 2026, 'Negative roster',
      'pre_draft', 'regular', 12, -1, 'dynasty', false, false, false, 'ppr',
      '{}'::jsonb, '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'negative roster sizes are rejected'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'bad-management', 'nfl', 2026, 'Bad management',
      'pre_draft', 'regular', 12, 18, 'best_ball', true, false, false, 'ppr',
      '{}'::jsonb, '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'best ball cannot be stored as roster management type'
);
select throws_ok(
  $$
    insert into public.leagues (
      provider, external_league_id, sport, season, name, status, season_type,
      team_count, roster_size, roster_management_type, is_best_ball,
      has_superflex, has_idp, scoring_format, settings, scoring_settings,
      roster_positions, provider_updated_at
    ) values (
      'sleeper', 'bad-scoring', 'nfl', 2026, 'Bad scoring', 'pre_draft',
      'regular', 12, 18, 'dynasty', false, false, false, 'points', '{}'::jsonb,
      '{}'::jsonb, '[]'::jsonb, now()
    )
  $$,
  '23514',
  null,
  'unknown broad scoring values are rejected'
);
select throws_ok(
  $$
    insert into public.fantasy_account_leagues (
      fantasy_account_id, league_id, first_seen_at, last_seen_at
    ) values (
      '51000000-0000-0000-0000-000000000001',
      '53000000-0000-0000-0000-000000000002',
      '2026-08-31 02:00:00+00',
      '2026-08-31 01:00:00+00'
    )
  $$,
  '23514',
  null,
  'last seen cannot precede first seen'
);
select throws_ok(
  $$
    update public.fantasy_account_leagues
    set removed_at = '2026-08-30 23:00:00+00'
    where id = '54000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'removal cannot precede first observation'
);
select throws_ok(
  $$
    update public.fantasy_account_leagues
    set removed_at = '2026-08-31 00:30:00+00'
    where id = '54000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'removal cannot fall between first and last observations'
);
select lives_ok(
  $$
    update public.fantasy_account_leagues
    set removed_at = last_seen_at
    where id = '54000000-0000-0000-0000-000000000001'
  $$,
  'removal may equal the last observation'
);
select lives_ok(
  $$
    update public.fantasy_account_leagues
    set removed_at = '2026-08-31 02:00:00+00'
    where id = '54000000-0000-0000-0000-000000000001'
  $$,
  'removal may follow the last observation'
);
select lives_ok(
  $$
    update public.fantasy_account_leagues
    set removed_at = null
    where id = '54000000-0000-0000-0000-000000000001'
  $$,
  'an active discovery association may have no removal time'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at
    ) values (
      '51000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
      'league_discovery', 'queued', now()
    )
  $$,
  '23514',
  null,
  'invalid sync statuses are rejected'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, progress_current,
      started_at
    ) values (
      '51000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
      'league_discovery', 'running', -1, now()
    )
  $$,
  '23514',
  null,
  'negative sync progress is rejected'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at, finished_at
    ) values (
      '51000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
      'league_discovery', 'running', now(), now()
    )
  $$,
  '23514',
  null,
  'running syncs cannot have a finish time'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at
    ) values (
      '51000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
      'league_discovery', 'failed', now()
    )
  $$,
  '23514',
  null,
  'terminal syncs require a finish time'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, result_counts,
      started_at, finished_at
    ) values (
      '51000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
      'league_discovery', 'partial', '[]'::jsonb, now(), now()
    )
  $$,
  '23514',
  null,
  'sync result counts must be an object'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at
    ) values (
      '51000000-0000-0000-0000-000000000001', 'sleeper', 'nfl',
      'league_discovery', 'running', now()
    )
  $$,
  '23505',
  null,
  'one account cannot have two running league-discovery attempts'
);

update public.provider_season_states
set provider_metadata = '{"refreshed":true}'::jsonb
where id = '52000000-0000-0000-0000-000000000001';
update public.leagues
set status = 'in_season'
where id = '53000000-0000-0000-0000-000000000001';
update public.fantasy_account_leagues
set last_seen_at = '2026-08-31 03:00:00+00'
where id = '54000000-0000-0000-0000-000000000001';
update public.sync_runs
set progress_current = 1, progress_total = 1
where id = '55000000-0000-0000-0000-000000000001';

select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.provider_season_states
    where id = '52000000-0000-0000-0000-000000000001'
  ),
  'provider season-state updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.leagues
    where id = '53000000-0000-0000-0000-000000000001'
  ),
  'league updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.fantasy_account_leagues
    where id = '54000000-0000-0000-0000-000000000001'
  ),
  'league discovery association updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.sync_runs
    where id = '55000000-0000-0000-0000-000000000001'
  ),
  'sync run updates refresh updated_at'
);

select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('anon', new_table.name, 'SELECT')
  ),
  'anon has no read grants on new tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('authenticated', new_table.name, 'INSERT')
  ),
  'authenticated has no insert grants on new tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('authenticated', new_table.name, 'UPDATE')
  ),
  'authenticated has no update grants on new tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('authenticated', new_table.name, 'DELETE')
  ),
  'authenticated has no delete grants on new tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('service_role', new_table.name, 'SELECT')
  ),
  'service_role has no direct SELECT on provider-data tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('service_role', new_table.name, 'INSERT')
  ),
  'service_role has no direct INSERT on provider-data tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('service_role', new_table.name, 'UPDATE')
  ),
  'service_role has no direct UPDATE on provider-data tables'
);
select ok(
  not exists (
    select 1
    from unnest(
      array[
        'public.provider_season_states',
        'public.leagues',
        'public.fantasy_account_leagues',
        'public.sync_runs'
      ]
    ) as new_table(name)
    where has_table_privilege('service_role', new_table.name, 'DELETE')
  ),
  'service_role has no direct DELETE on provider-data tables'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*)::integer from public.provider_season_states),
  1,
  'User A can read shared provider season state'
);
select is(
  (select count(*)::integer from public.fantasy_account_leagues),
  1,
  'User A sees only User A fantasy-account league associations'
);
select is(
  (select count(*)::integer from public.leagues),
  1,
  'User A sees only reachable leagues'
);
select is(
  (
    select count(*)::integer
    from public.leagues
    where id = '53000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot see User B unrelated league'
);
select is(
  (select count(*)::integer from public.sync_runs),
  1,
  'User A sees only User A account sync runs'
);

select set_config(
  'request.jwt.claim.sub',
  '50000000-0000-0000-0000-000000000002',
  true
);

select is(
  (select count(*)::integer from public.fantasy_account_leagues),
  2,
  'User B sees only User B fantasy-account league associations'
);
select is(
  (select count(*)::integer from public.leagues),
  2,
  'User B sees both legitimately reachable leagues'
);
select is(
  (
    select count(*)::integer
    from public.leagues
    where id = '53000000-0000-0000-0000-000000000001'
  ),
  1,
  'both users can see a legitimately shared league'
);
select is(
  (select count(*)::integer from public.sync_runs),
  1,
  'User B sees only User B account sync runs'
);

reset role;
set local role anon;
select throws_ok(
  $$ select * from public.provider_season_states $$,
  '42501',
  null,
  'anon cannot read provider season state'
);
select throws_ok(
  $$ select * from public.leagues $$,
  '42501',
  null,
  'anon cannot read leagues'
);
select throws_ok(
  $$ select * from public.fantasy_account_leagues $$,
  '42501',
  null,
  'anon cannot read league discovery associations'
);
select throws_ok(
  $$ select * from public.sync_runs $$,
  '42501',
  null,
  'anon cannot read sync runs'
);

reset role;
delete from public.fantasy_account_leagues
where id = '54000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)::integer
    from public.leagues
    where id = '53000000-0000-0000-0000-000000000001'
  ),
  1,
  'removing one account association does not delete the shared league'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_leagues
    where league_id = '53000000-0000-0000-0000-000000000001'
  ),
  1,
  'other account associations survive removal independently'
);

select * from finish();

rollback;
