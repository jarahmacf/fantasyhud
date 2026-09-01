begin;

select plan(154);

select has_table('public', 'league_users', 'league users exist');
select has_table('public', 'rosters', 'league-local rosters exist');
select has_table(
  'public',
  'fantasy_account_rosters',
  'tracked-account roster ownership exists'
);
select has_table(
  'public',
  'roster_players',
  'normalized current roster membership exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.league_users'::regclass),
  'league_users has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.rosters'::regclass),
  'rosters has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.fantasy_account_rosters'::regclass
  ),
  'fantasy_account_rosters has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.roster_players'::regclass),
  'roster_players has RLS enabled'
);

select col_type_is(
  'public', 'league_users', 'external_user_id', 'text',
  'league-user external IDs remain text'
);
select col_type_is(
  'public', 'rosters', 'external_roster_id', 'integer',
  'roster IDs are bounded league-local integers'
);
select col_type_is(
  'public', 'rosters', 'co_owner_external_user_ids', 'text[]',
  'co-owner source IDs are exact text arrays'
);
select col_type_is(
  'public', 'rosters', 'source_player_ids', 'text[]',
  'source player IDs are exact text arrays'
);
select col_type_is(
  'public', 'rosters', 'source_starter_ids', 'text[]',
  'source starter IDs are exact ordered text arrays'
);
select col_type_is(
  'public', 'rosters', 'source_reserve_ids', 'text[]',
  'source reserve IDs are exact text arrays'
);
select col_type_is(
  'public', 'rosters', 'source_taxi_ids', 'text[]',
  'source taxi IDs are exact text arrays'
);
select col_type_is(
  'public', 'rosters', 'source_keeper_ids', 'text[]',
  'source keeper IDs are exact text arrays'
);
select col_is_null(
  'public', 'rosters', 'co_owner_external_user_ids',
  'null co-owner arrays preserve an absent source field'
);
select col_is_null(
  'public', 'rosters', 'source_player_ids',
  'null player arrays preserve an absent source field'
);
select col_is_null(
  'public', 'rosters', 'source_starter_ids',
  'null starter arrays preserve an absent source field'
);
select col_is_null(
  'public', 'rosters', 'source_reserve_ids',
  'null reserve arrays preserve an absent source field'
);
select col_is_null(
  'public', 'rosters', 'source_taxi_ids',
  'null taxi arrays preserve an absent source field'
);
select col_is_null(
  'public', 'rosters', 'source_keeper_ids',
  'null keeper arrays preserve an absent source field'
);
select col_type_is(
  'public', 'fantasy_account_rosters', 'fantasy_account_id', 'uuid',
  'ownership associations reference canonical fantasy accounts'
);
select col_type_is(
  'public', 'roster_players', 'player_id', 'uuid',
  'memberships reference canonical players'
);
select col_type_is(
  'public', 'roster_players', 'source_player_external_id_id', 'uuid',
  'memberships reference exact player mappings'
);
select col_type_is(
  'public', 'roster_players', 'is_keeper', 'boolean',
  'keeper state is a normalized current boolean fact'
);

select hasnt_column(
  'public', 'league_users', 'user_id',
  'shared league users contain no app-user ownership'
);
select hasnt_column(
  'public', 'rosters', 'user_id',
  'shared rosters contain no app-user ownership'
);
select hasnt_column(
  'public', 'rosters', 'is_mine',
  'shared rosters contain no derived ownership flag'
);
select hasnt_column(
  'public', 'roster_players', 'user_id',
  'shared memberships contain no app-user ownership'
);
select hasnt_column(
  'public', 'roster_players', 'is_bench',
  'bench remains a derived presentation state'
);
select hasnt_column(
  'public', 'roster_players', 'counts_for_exposure',
  'exposure does not depend on a persisted flag'
);
select hasnt_column(
  'public', 'roster_players', 'is_drafted',
  'current membership is not draft ownership'
);
select has_column(
  'public', 'fantasy_account_rosters', 'fantasy_account_id',
  'tracked-account ownership is explicit and indirect'
);

select is(
  (
    select count(*)::integer
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'drafts',
        'draft_picks',
        'matchup_entries',
        'matchup_player_points',
        'transactions',
        'transaction_players',
        'player_ranking_snapshots',
        'market_adp_snapshots'
      )
  ),
  0,
  'draft, matchup, transaction, ranking, and market tables remain deferred'
);

select has_function(
  'app_private',
  'exact_text_array_is_safe',
  array['text[]', 'integer', 'boolean'],
  'the exact-array constraint helper exists'
);
select is(
  (
    select provolatile
    from pg_proc
    where oid = 'app_private.exact_text_array_is_safe(text[],integer,boolean)'::regprocedure
  ),
  'i'::"char",
  'the exact-array helper is immutable'
);
select is(
  (
    select proconfig
    from pg_proc
    where oid = 'app_private.exact_text_array_is_safe(text[],integer,boolean)'::regprocedure
  ),
  array['search_path=pg_catalog'],
  'the exact-array helper has a fixed safe search path'
);
select is(
  (
    select count(*)::integer
    from (values ('public'), ('anon'), ('authenticated'), ('service_role'))
      as grantee(name)
    where has_function_privilege(
      grantee.name,
      'app_private.exact_text_array_is_safe(text[],integer,boolean)',
      'execute'
    )
  ),
  0,
  'browser and service roles cannot execute the owner-only array helper'
);
select ok(
  app_private.exact_text_array_is_safe('{}'::text[], 1, true),
  'empty exact arrays are valid'
);
select ok(
  app_private.exact_text_array_is_safe(array['a', 'a'], 2, false),
  'duplicate starter sentinel values may be preserved when allowed'
);
select ok(
  not app_private.exact_text_array_is_safe(array['a', 'a'], 2, true),
  'duplicate values are rejected when uniqueness is required'
);
select ok(
  not app_private.exact_text_array_is_safe(array[' padded'], 2, true),
  'array values must remain exact after trimming'
);
select ok(
  not app_private.exact_text_array_is_safe(array[E'bad\nvalue'], 2, true),
  'array values cannot contain control characters'
);
select ok(
  not app_private.exact_text_array_is_safe(null, 2, true),
  'null arrays fail closed'
);
select ok(
  not app_private.exact_text_array_is_safe(array['a'], 0, true),
  'nonpositive helper bounds fail closed'
);
select ok(
  not app_private.exact_text_array_is_safe(array['a'], 2, null),
  'null helper uniqueness arguments fail closed'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.league_users'::regclass
      and conname = 'league_users_league_external_user_key'
      and contype = 'u'
  ),
  'league users are canonical within one league'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.rosters'::regclass
      and conname = 'rosters_league_external_roster_key'
      and contype = 'u'
  ),
  'rosters are canonical by league-local ID'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.rosters'::regclass
      and conname = 'rosters_id_league_key'
      and contype = 'u'
  ),
  'roster UUID plus league supports composite integrity'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.player_external_ids'::regclass
      and conname = 'player_external_ids_id_player_key'
      and contype = 'u'
  ),
  'exact mapping UUID plus canonical player supports composite integrity'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.roster_players'::regclass
      and conname = 'roster_players_roster_player_key'
      and contype = 'u'
  ),
  'one canonical player appears once on one roster'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.roster_players'::regclass
      and conname = 'roster_players_roster_source_mapping_key'
      and contype = 'u'
  ),
  'one exact source mapping appears once on one roster'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.fantasy_account_rosters'::regclass
      and conname = 'fantasy_account_rosters_account_league_fkey'
      and contype = 'f'
      and confrelid = 'public.fantasy_account_leagues'::regclass
  ),
  'ownership requires an exact account-to-league discovery association'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.fantasy_account_rosters'::regclass
      and conname = 'fantasy_account_rosters_roster_league_fkey'
      and contype = 'f'
      and confrelid = 'public.rosters'::regclass
  ),
  'ownership requires the roster and league to agree'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.roster_players'::regclass
      and conname = 'roster_players_roster_league_fkey'
      and contype = 'f'
      and confrelid = 'public.rosters'::regclass
  ),
  'membership requires the roster and league to agree'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.roster_players'::regclass
      and conname = 'roster_players_mapping_player_fkey'
      and contype = 'f'
      and confrelid = 'public.player_external_ids'::regclass
  ),
  'membership proves the exact mapping belongs to its canonical player'
);

select has_index(
  'public', 'league_users', 'league_users_league_removed_external_idx',
  'league-user current and removal reconciliation is indexed'
);
select has_index(
  'public', 'league_users', 'league_users_external_league_idx',
  'league-user exact source lookup is indexed'
);
select has_index(
  'public', 'rosters', 'rosters_league_removed_external_idx',
  'roster current and removal reconciliation is indexed'
);
select has_index(
  'public', 'fantasy_account_rosters',
  'fantasy_account_rosters_one_active_account_league_idx',
  'one active owned roster per account and league is index-enforced'
);
select has_index(
  'public', 'fantasy_account_rosters',
  'fantasy_account_rosters_account_league_removed_idx',
  'account ownership and removal queries are indexed'
);
select has_index(
  'public', 'fantasy_account_rosters',
  'fantasy_account_rosters_roster_account_idx',
  'shared-roster ownership lookup is indexed'
);
select has_index(
  'public', 'roster_players', 'roster_players_one_active_source_order_idx',
  'active source order is unique within one roster'
);
select has_index(
  'public', 'roster_players', 'roster_players_one_active_starter_order_idx',
  'active starter order is unique within one roster'
);
select has_index(
  'public', 'roster_players', 'roster_players_active_player_roster_idx',
  'active player exposure paths are indexed'
);
select has_index(
  'public', 'roster_players',
  'roster_players_active_league_roster_player_idx',
  'active league holdings are indexed'
);
select has_index(
  'public', 'roster_players', 'roster_players_roster_removed_idx',
  'membership removal reconciliation is indexed'
);
select has_index(
  'public', 'sync_runs',
  'sync_runs_one_running_roster_sync_per_account_idx',
  'running roster sync uniqueness is indexed per account'
);
select has_index(
  'public', 'sync_runs',
  'sync_runs_one_running_league_discovery_per_account_idx',
  'existing league-discovery running uniqueness remains intact'
);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'league_users',
        'rosters',
        'fantasy_account_rosters',
        'roster_players'
      )
      and roles @> array['authenticated'::name]
      and cmd = 'SELECT'
  ),
  4,
  'each new public table has one authenticated read policy'
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
  'service_role has no direct CRUD on roster-domain tables'
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
    where has_table_privilege('authenticated', provider_table.name, 'insert')
      or has_table_privilege('authenticated', provider_table.name, 'update')
      or has_table_privilege('authenticated', provider_table.name, 'delete')
  ),
  0,
  'authenticated browsers have no direct roster-domain mutation grants'
);
select is(
  (
    select count(*)::integer
    from (values
      ('id'),
      ('fantasy_account_id'),
      ('provider'),
      ('sport'),
      ('season'),
      ('scope'),
      ('status'),
      ('progress_current'),
      ('progress_total'),
      ('result_counts'),
      ('error_summary'),
      ('started_at'),
      ('finished_at'),
      ('created_at'),
      ('updated_at')
    ) as safe_column(name)
    where has_column_privilege(
      'authenticated', 'public.sync_runs', safe_column.name, 'select'
    )
  ),
  15,
  'authenticated users can read every safe sync-run status column'
);
select ok(
  not has_table_privilege('authenticated', 'public.sync_runs', 'select'),
  'authenticated no longer has table-wide sync-run SELECT'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.sync_runs',
    'triggered_by_user_id',
    'select'
  ),
  'the triggering Auth UUID is not browser-selectable'
);
select ok(
  pg_get_constraintdef(
    (
      select oid from pg_constraint
      where conrelid = 'public.sync_runs'::regclass
        and conname = 'sync_runs_scope_is_known'
    )
  ) like '%league_discovery%'
  and pg_get_constraintdef(
    (
      select oid from pg_constraint
      where conrelid = 'public.sync_runs'::regclass
        and conname = 'sync_runs_scope_is_known'
    )
  ) like '%roster_sync%',
  'sync scope permits exactly the implemented discovery and roster scopes'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'roster-a@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'roster-b@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'roster-c@example.test', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username
)
values
  ('82000000-0000-0000-0000-000000000001', 'sleeper', 'account-a', 'AccountA', 'accounta'),
  ('82000000-0000-0000-0000-000000000002', 'sleeper', 'account-b', 'AccountB', 'accountb'),
  ('82000000-0000-0000-0000-000000000003', 'sleeper', 'account-c', 'AccountC', 'accountc');

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values
  ('81000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', true),
  ('81000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', true),
  ('81000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000002', false),
  ('81000000-0000-0000-0000-000000000003', '82000000-0000-0000-0000-000000000003', true);

insert into public.leagues (
  id, provider, external_league_id, sport, season, name, status,
  season_type, team_count, roster_size, roster_management_type,
  is_best_ball, has_superflex, has_idp, scoring_format, settings,
  scoring_settings, roster_positions, provider_metadata, fetched_at
)
values
  (
    '83000000-0000-0000-0000-000000000001', 'sleeper', 'league-a',
    'nfl', 2026, 'League A', 'in_season', 'regular', 12, 18,
    'dynasty', true, true, false, 'ppr', '{}'::jsonb, '{}'::jsonb,
    '["QB","RB","WR","SUPER_FLEX"]'::jsonb, '{}'::jsonb, now()
  ),
  (
    '83000000-0000-0000-0000-000000000002', 'sleeper', 'league-b',
    'nfl', 2026, 'League B', 'in_season', 'regular', 10, 16,
    'redraft', false, false, false, 'half_ppr', '{}'::jsonb, '{}'::jsonb,
    '["QB","RB","WR","BN"]'::jsonb, '{}'::jsonb, now()
  );

insert into public.fantasy_account_leagues (
  fantasy_account_id, league_id, first_seen_at, last_seen_at
)
values
  ('82000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', now(), now()),
  ('82000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', now(), now()),
  ('82000000-0000-0000-0000-000000000003', '83000000-0000-0000-0000-000000000002', now(), now());

insert into public.league_users (
  id, league_id, external_user_id, username, display_name, team_name,
  fetched_at, first_seen_at, last_seen_at, updated_at
)
values
  (
    '84000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001', 'same-provider-user',
    'member-a', 'Member A', 'Team A', now(), now(), now(),
    '2000-01-01 00:00:00+00'
  ),
  (
    '84000000-0000-0000-0000-000000000002',
    '83000000-0000-0000-0000-000000000002', 'same-provider-user',
    'member-b', 'Member B', 'Team B', now(), now(), now(), now()
  );

insert into public.rosters (
  id, league_id, external_roster_id, owner_external_user_id,
  co_owner_external_user_ids, source_player_ids, source_starter_ids,
  source_reserve_ids, source_taxi_ids, source_keeper_ids, settings, metadata,
  fetched_at, first_seen_at, last_seen_at, updated_at
)
values
  (
    '85000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001', 1, 'account-a',
    array['account-b'], array['player-1', 'player-2'],
    array['player-1', '0', '0'], array['player-1'], array['player-1'],
    array['player-1'], '{"wins":1}'::jsonb, '{}'::jsonb, now(), now(), now(),
    '2000-01-01 00:00:00+00'
  ),
  (
    '85000000-0000-0000-0000-000000000002',
    '83000000-0000-0000-0000-000000000001', 2, 'other-owner',
    null, null, null, null, null, null, '{}'::jsonb, '{}'::jsonb,
    now(), now(), now(), now()
  ),
  (
    '85000000-0000-0000-0000-000000000003',
    '83000000-0000-0000-0000-000000000002', 1, 'account-c',
    '{}', '{}', '{}', '{}', '{}', '{}',
    '{}'::jsonb, '{}'::jsonb, now(), now(), now(), now()
  );

insert into public.fantasy_account_rosters (
  id, fantasy_account_id, league_id, roster_id, ownership_role,
  first_seen_at, last_seen_at, updated_at
)
values
  (
    '86000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001', 'owner', now(), now(),
    '2000-01-01 00:00:00+00'
  ),
  (
    '86000000-0000-0000-0000-000000000002',
    '82000000-0000-0000-0000-000000000002',
    '83000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001', 'co_owner', now(), now(), now()
  ),
  (
    '86000000-0000-0000-0000-000000000003',
    '82000000-0000-0000-0000-000000000003',
    '83000000-0000-0000-0000-000000000002',
    '85000000-0000-0000-0000-000000000003', 'owner', now(), now(), now()
  );

insert into public.players (
  id, sport, entity_type, display_name, profile_source,
  profile_fetched_at, updated_at
)
values
  ('87000000-0000-0000-0000-000000000001', 'nfl', 'player', 'Player One', 'sleeper', now(), now()),
  ('87000000-0000-0000-0000-000000000002', 'nfl', 'player', 'Player Two', 'sleeper', now(), now()),
  ('87000000-0000-0000-0000-000000000003', 'nfl', 'player', 'Player Three', 'sleeper', now(), now());

insert into public.player_external_ids (
  id, player_id, namespace, sport, external_id, reported_by, is_primary,
  first_seen_at, last_seen_at, updated_at
)
values
  (
    '88000000-0000-0000-0000-000000000001',
    '87000000-0000-0000-0000-000000000001', 'sleeper', 'nfl',
    'player-1', 'sleeper', true, now(), now(), now()
  ),
  (
    '88000000-0000-0000-0000-000000000002',
    '87000000-0000-0000-0000-000000000002', 'sleeper', 'nfl',
    'player-2', 'sleeper', true, now(), now(), now()
  ),
  (
    '88000000-0000-0000-0000-000000000003',
    '87000000-0000-0000-0000-000000000003', 'sleeper', 'nfl',
    'player-3', 'sleeper', true, now(), now(), now()
  ),
  (
    '88000000-0000-0000-0000-000000000004',
    '87000000-0000-0000-0000-000000000001', 'espn', 'nfl',
    'espn-player-1', 'sleeper', false, now(), now(), now()
  );

insert into public.roster_players (
  id, roster_id, league_id, player_id, source_player_external_id_id,
  source_order, is_starter, starter_order, starter_slot, is_reserve,
  is_taxi, is_keeper, first_seen_at, last_seen_at, updated_at
)
values
  (
    '89000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '87000000-0000-0000-0000-000000000001',
    '88000000-0000-0000-0000-000000000001', 1, true, 1, 'QB',
    true, true, true, now(), now(), '2000-01-01 00:00:00+00'
  ),
  (
    '89000000-0000-0000-0000-000000000002',
    '85000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '87000000-0000-0000-0000-000000000002',
    '88000000-0000-0000-0000-000000000002', 2, false, null, null,
    false, false, false, now(), now(), now()
  ),
  (
    '89000000-0000-0000-0000-000000000003',
    '85000000-0000-0000-0000-000000000003',
    '83000000-0000-0000-0000-000000000002',
    '87000000-0000-0000-0000-000000000003',
    '88000000-0000-0000-0000-000000000003', 1, true, 1, 'QB',
    false, false, false, now(), now(), now()
  );

select is(
  (
    select count(*)::integer
    from public.fantasy_account_rosters
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  ),
  1,
  'two app users tracking one canonical account share one ownership association'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_rosters
    where roster_id = '85000000-0000-0000-0000-000000000001'
  ),
  2,
  'two fantasy accounts may associate with one shared co-owned roster'
);
select is(
  (
    select count(*)::integer
    from public.league_users
    where external_user_id = 'same-provider-user'
  ),
  2,
  'the same provider user ID remains league-scoped'
);
select is(
  (
    select count(*)::integer
    from public.rosters
    where source_starter_ids = array['player-1', '0', '0']
  ),
  1,
  'repeated provider starter sentinels remain schema-valid'
);
select is(
  (
    select count(*)::integer
    from public.rosters
    where id = '85000000-0000-0000-0000-000000000002'
      and co_owner_external_user_ids is null
      and source_player_ids is null
      and source_starter_ids is null
      and source_reserve_ids is null
      and source_taxi_ids is null
      and source_keeper_ids is null
  ),
  1,
  'source-null arrays remain null instead of becoming empty'
);
select is(
  (
    select count(*)::integer
    from public.rosters
    where id = '85000000-0000-0000-0000-000000000003'
      and co_owner_external_user_ids = '{}'::text[]
      and source_player_ids = '{}'::text[]
      and source_starter_ids = '{}'::text[]
      and source_reserve_ids = '{}'::text[]
      and source_taxi_ids = '{}'::text[]
      and source_keeper_ids = '{}'::text[]
  ),
  1,
  'explicitly empty source arrays remain explicitly empty'
);
select ok(
  (
    select source_player_ids is distinct from (
      select source_player_ids
      from public.rosters
      where id = '85000000-0000-0000-0000-000000000003'
    )
    from public.rosters
    where id = '85000000-0000-0000-0000-000000000002'
  ),
  'source null and explicit empty arrays remain distinguishable'
);
select is(
  (
    select count(*)::integer
    from public.rosters
    where id = '85000000-0000-0000-0000-000000000001'
      and co_owner_external_user_ids = array['account-b']
      and source_player_ids = array['player-1', 'player-2']
      and source_starter_ids = array['player-1', '0', '0']
      and source_reserve_ids = array['player-1']
      and source_taxi_ids = array['player-1']
      and source_keeper_ids = array['player-1']
  ),
  1,
  'nonempty source arrays preserve their exact ordered values'
);
select is(
  (
    select count(*)::integer
    from public.roster_players
    where id = '89000000-0000-0000-0000-000000000001'
      and is_starter and is_reserve and is_taxi and is_keeper
      and removed_at is null
  ),
  1,
  'starter, reserve, taxi, and current keeper facts coexist on one holding'
);
select is(
  (
    select count(*)::integer
    from public.roster_players
    where id in (
      '89000000-0000-0000-0000-000000000001',
      '89000000-0000-0000-0000-000000000002'
    )
      and (
        (is_starter and starter_order = 1 and starter_slot = 'QB')
        or (not is_starter and starter_order is null and starter_slot is null)
      )
  ),
  2,
  'valid starter and nonstarter states are both representable'
);

select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      source_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', 1, now(), now()
    )
  $$,
  '23505', null,
  'duplicate active source order is rejected within one roster'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      source_order, is_starter, starter_order, starter_slot,
      first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', 3, true, 1, 'WR',
      now(), now()
    )
  $$,
  '23505', null,
  'duplicate active starter order is rejected within one roster'
);

select throws_ok(
  $$
    insert into public.fantasy_account_rosters (
      fantasy_account_id, league_id, roster_id, ownership_role,
      first_seen_at, last_seen_at
    ) values (
      '82000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '85000000-0000-0000-0000-000000000002', 'owner', now(), now()
    )
  $$,
  '23505', null,
  'one fantasy account cannot have two active rosters in one league'
);

update public.fantasy_account_rosters
set removed_at = greatest(now(), last_seen_at)
where id = '86000000-0000-0000-0000-000000000001';

select lives_ok(
  $$
    insert into public.fantasy_account_rosters (
      id, fantasy_account_id, league_id, roster_id, ownership_role,
      first_seen_at, last_seen_at
    ) values (
      '86000000-0000-0000-0000-000000000004',
      '82000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '85000000-0000-0000-0000-000000000002', 'owner', now(), now()
    )
  $$,
  'a removed association permits a later different active roster'
);
select is(
  (
    select count(*)::integer from public.rosters
    where id = '85000000-0000-0000-0000-000000000001'
  ),
  1,
  'removing ownership does not delete the shared roster'
);

update public.roster_players
set removed_at = greatest(now(), last_seen_at)
where id = '89000000-0000-0000-0000-000000000001';

select lives_ok(
  $$
    insert into public.roster_players (
      id, roster_id, league_id, player_id, source_player_external_id_id,
      source_order, is_starter, starter_order, starter_slot,
      first_seen_at, last_seen_at
    ) values (
      '89000000-0000-0000-0000-000000000004',
      '85000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', 1, true, 1, 'WR',
      now(), now()
    )
  $$,
  'source and starter orders may be reused after the prior membership is removed'
);

select is(
  (
    select count(*)::integer from public.players
    where id = '87000000-0000-0000-0000-000000000001'
  ),
  1,
  'removing roster membership does not delete the canonical player'
);
select is(
  (
    select count(*)::integer from public.player_external_ids
    where id = '88000000-0000-0000-0000-000000000001'
  ),
  1,
  'removing roster membership does not delete the exact source mapping'
);

select throws_ok(
  $$
    insert into public.league_users (
      league_id, external_user_id, fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 'same-provider-user',
      now(), now(), now()
    )
  $$,
  '23505', null,
  'duplicate league-local provider users are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 1, now(), now(), now()
    )
  $$,
  '23505', null,
  'duplicate league-local roster IDs are rejected'
);
select throws_ok(
  $$
    insert into public.league_users (
      league_id, external_user_id, fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 'bad-time', now(),
      '2026-09-01 02:00:00+00', '2026-09-01 01:00:00+00'
    )
  $$,
  '23514', null,
  'invalid league-user observation order is rejected'
);
select throws_ok(
  $$
    insert into public.fantasy_account_rosters (
      fantasy_account_id, league_id, roster_id, ownership_role,
      first_seen_at, last_seen_at
    ) values (
      '82000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000001',
      '85000000-0000-0000-0000-000000000002', 'manager', now(), now()
    )
  $$,
  '23514', null,
  'unsupported ownership roles are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 0, now(), now(), now()
    )
  $$,
  '23514', null,
  'nonpositive league-local roster IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, source_player_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array[E'bad\nplayer'], now(), now(), now()
    )
  $$,
  '23514', null,
  'invalid exact source-array elements are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, co_owner_external_user_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array['same', 'same'], now(), now(), now()
    )
  $$,
  '23514', null,
  'duplicate co-owner IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, source_player_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array['same', 'same'], now(), now(), now()
    )
  $$,
  '23514', null,
  'duplicate current player IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, source_reserve_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array['same', 'same'], now(), now(), now()
    )
  $$,
  '23514', null,
  'duplicate reserve IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, source_taxi_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array['same', 'same'], now(), now(), now()
    )
  $$,
  '23514', null,
  'duplicate taxi IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, source_keeper_ids,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      array['same', 'same'], now(), now(), now()
    )
  $$,
  '23514', null,
  'duplicate keeper IDs are rejected'
);
select throws_ok(
  $$
    insert into public.rosters (
      league_id, external_roster_id, metadata,
      fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 3,
      '[]'::jsonb, now(), now(), now()
    )
  $$,
  '23514', null,
  'malformed roster metadata is rejected'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', true, now(), now()
    )
  $$,
  '23514', null,
  'starters require a positive starter order'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', false, 1, now(), now()
    )
  $$,
  '23514', null,
  'nonstarters cannot retain a starter order'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_slot, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', false, 'WR', now(), now()
    )
  $$,
  '23514', null,
  'nonstarters cannot retain a starter slot'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000001',
      '88000000-0000-0000-0000-000000000004', false, null, now(), now()
    )
  $$,
  '23505', null,
  'one roster cannot duplicate a canonical player membership'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000001',
      '88000000-0000-0000-0000-000000000001', false, null, now(), now()
    )
  $$,
  '23505', null,
  'one roster cannot duplicate an exact source mapping membership'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000002',
      '87000000-0000-0000-0000-000000000003',
      '88000000-0000-0000-0000-000000000003', false, null, now(), now()
    )
  $$,
  '23503', null,
  'a roster membership cannot cross its roster league'
);
select throws_ok(
  $$
    insert into public.fantasy_account_rosters (
      fantasy_account_id, league_id, roster_id, ownership_role,
      first_seen_at, last_seen_at
    ) values (
      '82000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000002',
      '85000000-0000-0000-0000-000000000003', 'owner', now(), now()
    )
  $$,
  '23503', null,
  'ownership cannot cross an undiscovered account and league pair'
);
select throws_ok(
  $$
    insert into public.roster_players (
      roster_id, league_id, player_id, source_player_external_id_id,
      is_starter, starter_order, first_seen_at, last_seen_at
    ) values (
      '85000000-0000-0000-0000-000000000002',
      '83000000-0000-0000-0000-000000000001',
      '87000000-0000-0000-0000-000000000002',
      '88000000-0000-0000-0000-000000000003', false, null, now(), now()
    )
  $$,
  '23503', null,
  'the exact source mapping must belong to the referenced canonical player'
);

insert into public.sync_runs (
  id, fantasy_account_id, triggered_by_user_id, provider, sport, season,
  scope, status, started_at
)
values
  (
    '8a000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    'sleeper', 'nfl', 2026, 'roster_sync', 'running', now()
  ),
  (
    '8a000000-0000-0000-0000-000000000002',
    '82000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000002',
    'sleeper', 'nfl', 2026, 'roster_sync', 'running', now()
  ),
  (
    '8a000000-0000-0000-0000-000000000003',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    'sleeper', 'nfl', 2026, 'league_discovery', 'running', now()
  );

select is(
  (
    select count(*)::integer from public.sync_runs
    where scope = 'roster_sync' and status = 'running'
  ),
  2,
  'different accounts may each have one running roster sync'
);
select is(
  (
    select count(*)::integer from public.sync_runs
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
      and status = 'running'
  ),
  2,
  'league discovery and roster sync retain independent concurrency scopes'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at
    ) values (
      '82000000-0000-0000-0000-000000000001', 'sleeper', 'nfl',
      'roster_sync', 'running', now()
    )
  $$,
  '23505', null,
  'one account cannot have two running roster syncs'
);
select throws_ok(
  $$
    insert into public.sync_runs (
      fantasy_account_id, provider, sport, scope, status, started_at
    ) values (
      '82000000-0000-0000-0000-000000000003', 'sleeper', 'nfl',
      'full_sync', 'running', now()
    )
  $$,
  '23514', null,
  'unsupported synchronization scopes remain rejected'
);

update public.league_users
set team_name = 'Updated Team A'
where id = '84000000-0000-0000-0000-000000000001';
update public.rosters
set settings = '{"wins":2}'::jsonb
where id = '85000000-0000-0000-0000-000000000001';
update public.fantasy_account_rosters
set source_metadata = '{"updated":true}'::jsonb
where id = '86000000-0000-0000-0000-000000000001';
update public.roster_players
set source_metadata = '{"updated":true}'::jsonb
where id = '89000000-0000-0000-0000-000000000001';

select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.league_users
    where id = '84000000-0000-0000-0000-000000000001'
  ),
  'league-user updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.rosters
    where id = '85000000-0000-0000-0000-000000000001'
  ),
  'roster updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.fantasy_account_rosters
    where id = '86000000-0000-0000-0000-000000000001'
  ),
  'ownership updates refresh updated_at'
);
select ok(
  (
    select updated_at > '2000-01-01 00:00:00+00'
    from public.roster_players
    where id = '89000000-0000-0000-0000-000000000001'
  ),
  'membership updates refresh updated_at'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*)::integer from public.league_users),
  1,
  'User A sees league users in reachable League A'
);
select is(
  (select count(*)::integer from public.rosters),
  2,
  'User A sees every roster in reachable League A'
);
select is(
  (select count(*)::integer from public.roster_players),
  3,
  'User A sees active and removed holdings in reachable League A'
);
select is(
  (select count(*)::integer from public.fantasy_account_rosters),
  2,
  'User A sees only ownership rows for the tracked canonical account'
);
select is(
  (
    select count(*)::integer from public.fantasy_account_rosters
    where fantasy_account_id = '82000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot see another tracked account ownership row in the same league'
);
select is(
  (
    select count(*)::integer from public.rosters
    where league_id = '83000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot see unrelated League B rosters'
);
select is(
  (
    select count(*)::integer from public.sync_runs
    where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  ),
  2,
  'User A can read safe status for both implemented sync scopes'
);
select lives_ok(
  $$
    select id, fantasy_account_id, provider, sport, season, scope, status,
      progress_current, progress_total, result_counts, error_summary,
      started_at, finished_at, created_at, updated_at
    from public.sync_runs
  $$,
  'authenticated users can select the complete safe sync-run projection'
);
select throws_ok(
  $$ select triggered_by_user_id from public.sync_runs $$,
  '42501', null,
  'authenticated selection of the private trigger UUID is denied'
);
select throws_ok(
  $$ delete from public.rosters $$,
  '42501', null,
  'authenticated users cannot delete shared rosters'
);
select throws_ok(
  $$ update public.roster_players set is_reserve = false $$,
  '42501', null,
  'authenticated users cannot update roster membership'
);
select throws_ok(
  $$
    insert into public.league_users (
      league_id, external_user_id, fetched_at, first_seen_at, last_seen_at
    ) values (
      '83000000-0000-0000-0000-000000000001', 'browser-write',
      now(), now(), now()
    )
  $$,
  '42501', null,
  'authenticated users cannot insert league users'
);

reset role;
update public.fantasy_account_leagues
set removed_at = greatest(now(), last_seen_at)
where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  and league_id = '83000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select is(
  (select count(*)::integer from public.league_users),
  0,
  'User A loses shared league users when its only discovery association is removed'
);
select is(
  (select count(*)::integer from public.rosters),
  0,
  'User A loses shared rosters when its only discovery association is removed'
);
select is(
  (select count(*)::integer from public.roster_players),
  0,
  'User A loses shared holdings when its only discovery association is removed'
);
select is(
  (select count(*)::integer from public.fantasy_account_rosters),
  2,
  'User A retains its own historical ownership after discovery removal'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select is(
  (select count(*)::integer from public.league_users),
  1,
  'User B retains shared league users through its other active account association'
);
select is(
  (select count(*)::integer from public.rosters),
  2,
  'User B sees the same shared rosters in reachable League A'
);
select is(
  (select count(*)::integer from public.roster_players),
  3,
  'User B sees the same shared League A holdings'
);
select is(
  (select count(*)::integer from public.fantasy_account_rosters),
  3,
  'User B sees ownership for both fantasy accounts it tracks'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*)::integer from public.league_users),
  1,
  'User C sees only reachable League B users'
);
select is(
  (select count(*)::integer from public.rosters),
  1,
  'User C sees only reachable League B rosters'
);
select is(
  (select count(*)::integer from public.roster_players),
  1,
  'User C sees only reachable League B holdings'
);
select is(
  (select count(*)::integer from public.fantasy_account_rosters),
  1,
  'User C sees only its tracked-account ownership'
);

reset role;
update public.fantasy_account_leagues
set removed_at = null
where fantasy_account_id = '82000000-0000-0000-0000-000000000001'
  and league_id = '83000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select is(
  (select count(*)::integer from public.league_users),
  1,
  'reactivating discovery restores User A league users'
);
select is(
  (select count(*)::integer from public.rosters),
  2,
  'reactivating discovery restores User A rosters'
);
select is(
  (select count(*)::integer from public.roster_players),
  3,
  'reactivating discovery restores User A holdings without duplication'
);

reset role;
set local role anon;
select throws_ok(
  $$ select id from public.league_users $$,
  '42501', null,
  'anon cannot read league users'
);
select throws_ok(
  $$ select id from public.rosters $$,
  '42501', null,
  'anon cannot read rosters'
);
select throws_ok(
  $$ select id from public.fantasy_account_rosters $$,
  '42501', null,
  'anon cannot read tracked-account ownership'
);
select throws_ok(
  $$ select id from public.roster_players $$,
  '42501', null,
  'anon cannot read roster membership'
);
reset role;

select * from finish();
rollback;
