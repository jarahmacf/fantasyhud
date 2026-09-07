begin;

select plan(255);

-- Helper and object contract -------------------------------------------------

select has_function(
  'app_private',
  'draft_order_map_is_safe',
  array['jsonb', 'integer', 'integer'],
  'the exact draft-order validator exists'
);
select has_function(
  'app_private',
  'slot_to_roster_map_is_safe',
  array['jsonb', 'integer', 'integer', 'integer'],
  'the exact slot-to-roster validator exists'
);
select has_function(
  'app_private',
  'exact_text_array_is_sorted_unique',
  array['text[]', 'integer'],
  'the deterministic source-user-array validator exists'
);
select has_function(
  'app_private',
  'classify_sleeper_draft_environment_v1',
  array[
    'text', 'text', 'text', 'text', 'text', 'text', 'text', 'jsonb',
    'integer', 'integer', 'integer'
  ],
  'the version-one Sleeper draft-environment classifier exists'
);

select is(
  (
    select count(*)::integer
    from pg_proc
    where oid in (
      'app_private.draft_order_map_is_safe(jsonb,integer,integer)'::regprocedure,
      'app_private.slot_to_roster_map_is_safe(jsonb,integer,integer,integer)'::regprocedure,
      'app_private.exact_text_array_is_sorted_unique(text[],integer)'::regprocedure,
      'app_private.classify_sleeper_draft_environment_v1(text,text,text,text,text,text,text,jsonb,integer,integer,integer)'::regprocedure
    )
      and provolatile = 'i'
  ),
  4,
  'all draft helpers and the classifier are immutable'
);
select is(
  (
    select count(*)::integer
    from pg_proc
    where oid in (
      'app_private.draft_order_map_is_safe(jsonb,integer,integer)'::regprocedure,
      'app_private.slot_to_roster_map_is_safe(jsonb,integer,integer,integer)'::regprocedure,
      'app_private.exact_text_array_is_sorted_unique(text[],integer)'::regprocedure,
      'app_private.classify_sleeper_draft_environment_v1(text,text,text,text,text,text,text,jsonb,integer,integer,integer)'::regprocedure
    )
      and proconfig @> array['search_path=pg_catalog']
  ),
  4,
  'all draft helpers and the classifier fix search_path to pg_catalog'
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('app_private.draft_order_map_is_safe(jsonb,integer,integer)'),
        ('app_private.slot_to_roster_map_is_safe(jsonb,integer,integer,integer)'),
        ('app_private.exact_text_array_is_sorted_unique(text[],integer)'),
        ('app_private.classify_sleeper_draft_environment_v1(text,text,text,text,text,text,text,jsonb,integer,integer,integer)')
    ) as helper(signature)
    where has_function_privilege('postgres', helper.signature, 'execute')
      and not has_function_privilege('anon', helper.signature, 'execute')
      and not has_function_privilege('authenticated', helper.signature, 'execute')
      and not has_function_privilege('service_role', helper.signature, 'execute')
      and not exists (
        select 1
        from pg_proc
        cross join lateral aclexplode(proacl) as acl
        where oid = helper.signature::regprocedure
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
  ),
  4,
  'all draft helpers and the classifier are owner-only'
);

select results_eq(
  $$
    select
      app_private.draft_order_map_is_safe('{}'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe(
        '{"user-a":1,"user-b":1,"user-c":2}'::jsonb, 1000, 1000
      ),
      app_private.draft_order_map_is_safe(null, 1000, 1000),
      app_private.draft_order_map_is_safe('[]'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe('{" user":1}'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe('{"user":0}'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe('{"user":1.5}'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe('{"user":1001}'::jsonb, 1000, 1000),
      app_private.draft_order_map_is_safe('{"user":1}'::jsonb, 0, 1000)
  $$,
  $$ values (true, true, false, false, false, false, false, false, false) $$,
  'draft-order validation preserves empty and shared slots while rejecting malformed maps and bounds'
);
select results_eq(
  $$
    select
      app_private.slot_to_roster_map_is_safe('{}'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe(
        '{"1":42,"2":43}'::jsonb, 1000, 1000, 1000000
      ),
      app_private.slot_to_roster_map_is_safe(null, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('[]'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('{"01":1}'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('{"+1":1}'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('{"1":0}'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('{"1001":1}'::jsonb, 1000, 1000, 1000000),
      app_private.slot_to_roster_map_is_safe('{"1":1000001}'::jsonb, 1000, 1000, 1000000)
  $$,
  $$ values (true, true, false, false, false, false, false, false, false) $$,
  'slot-to-roster validation accepts canonical integer maps and rejects malformed keys and values'
);
select results_eq(
  $$
    select
      app_private.exact_text_array_is_sorted_unique(array[]::text[], 1000),
      app_private.exact_text_array_is_sorted_unique(array['A', 'a', 'z'], 1000),
      app_private.exact_text_array_is_sorted_unique(null, 1000),
      app_private.exact_text_array_is_sorted_unique(array['b', 'a'], 1000),
      app_private.exact_text_array_is_sorted_unique(array['a', 'a'], 1000),
      app_private.exact_text_array_is_sorted_unique(array[' a'], 1000),
      app_private.exact_text_array_is_sorted_unique(array['a', null], 1000),
      app_private.exact_text_array_is_sorted_unique(array['a'], 0)
  $$,
  $$ values (true, true, false, false, false, false, false, false) $$,
  'source-user arrays preserve null versus empty and require exact C-sorted unique identifiers'
);

select results_eq(
  $$
    select
      draft_type_family collate "C" = 'snake' collate "C",
      capital_type collate "C" = 'overall_pick' collate "C",
      environment_quality collate "C" = 'exact' collate "C",
      (derived_dimensions ->> 'draft_pool_type') collate "C"
        = 'all_players' collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1', 64), repeat('2', 64), 'exact',
      'snake', 'all_players', '{"teams":12,"rounds":18,"pick_timer":60}',
      12, 18, 60
    )
  $$,
  $$ values (true, true, true, true) $$,
  'snake drafts classify to exact overall-pick environments'
);
select results_eq(
  $$
    select
      snake.draft_type_family collate "C" = 'snake' collate "C",
      snake.capital_type collate "C" = 'overall_pick' collate "C",
      linear.draft_type_family collate "C" = 'linear' collate "C",
      linear.capital_type collate "C" = 'overall_pick' collate "C",
      auction.draft_type_family collate "C" = 'auction' collate "C",
      auction.capital_type collate "C" = 'auction_value' collate "C",
      unknown_type.draft_type_family collate "C" = 'unknown' collate "C",
      unknown_type.capital_type collate "C" = 'unknown' collate "C",
      unknown_type.environment_quality collate "C" = 'unknown' collate "C",
      unknown_pool.environment_quality collate "C" = 'unknown' collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as snake
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'linear', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as linear
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'auction', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as auction
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'future_type', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as unknown_type
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'unknown', '{}'::jsonb, 12, 18, 60
    ) as unknown_pool
  $$,
  $$ values (true, true, true, true, true, true, true, true, true, true) $$,
  'draft type, capital type, future type, and unknown pool remain conservative'
);
select ok(
  (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"teams":12,"rounds":18}', 12, 18, 60
    )
  ) = (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"rounds":18,"teams":12}', 12, 18, 60
    )
  ),
  'JSON object key order does not change exact draft-environment identity'
);
select ok(
  (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"rounds":18,"custom":1}',
      12, 18, 60
    )
  ) <> (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"rounds":18,"custom":2}',
      12, 18, 60
    )
  ),
  'one exact draft-setting change changes exact environment identity'
);
select ok(
  (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    )
  ) <> (
    select draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('3',64), repeat('4',64), 'exact',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    )
  ),
  'one exact league-format context change changes exact environment identity'
);
select results_eq(
  $$
    select
      exact.environment_quality collate "C" = 'exact' collate "C",
      partial.environment_quality collate "C" = 'partial' collate "C",
      unknown_context.environment_quality collate "C" = 'unknown' collate "C",
      exact.draft_environment_fingerprint collate "C"
        <> partial.draft_environment_fingerprint collate "C",
      partial.draft_environment_fingerprint collate "C"
        <> unknown_context.draft_environment_fingerprint collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as exact
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'partial',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as partial
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', null, null, 'unknown',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    ) as unknown_context
  $$,
  $$ values (true, true, true, true, true) $$,
  'exact, partial, and unknown historical context remain distinct'
);
select throws_ok(
  $$
    select * from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', null, null, 'exact', 'snake', 'all_players',
      '{}'::jsonb, 12, 18, 60
    )
  $$,
  '22023',
  'The Sleeper draft environment input is invalid.',
  'exact context fails closed without exact format identities'
);
select throws_ok(
  $$
    select * from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'unknown',
      'snake', 'all_players', '{}'::jsonb, 12, 18, 60
    )
  $$,
  '22023',
  'The Sleeper draft environment input is invalid.',
  'unknown context fails closed when context identities are supplied'
);
select throws_ok(
  $$
    select * from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"teams":10}'::jsonb, 12, 18, 60
    )
  $$,
  '23514',
  'The typed draft team count disagrees with exact settings.',
  'typed team count must agree with a valid exact source setting'
);
select results_eq(
  $$
    select
      wrong_type.environment_quality collate "C" = 'unknown' collate "C",
      wrong_type.draft_settings_fingerprint collate "C" =
        app_private.context_sha256(
        'draft_settings:sleeper:nfl', 1, '{"teams":"2"}'::jsonb
      ) collate "C",
      noninteger.environment_quality collate "C" = 'unknown' collate "C",
      noninteger.draft_settings_fingerprint collate "C" =
        app_private.context_sha256(
        'draft_settings:sleeper:nfl', 1, '{"rounds":1.5}'::jsonb
      ) collate "C",
      out_of_range.environment_quality collate "C" = 'unknown' collate "C",
      out_of_range.draft_settings_fingerprint collate "C" =
        app_private.context_sha256(
        'draft_settings:sleeper:nfl', 1, '{"pick_timer":86401}'::jsonb
      ) collate "C"
    from app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"teams":"2"}'::jsonb, 2, 2, 60
    ) as wrong_type
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"rounds":1.5}'::jsonb, 2, 2, 60
    ) as noninteger
    cross join app_private.classify_sleeper_draft_environment_v1(
      'sleeper', 'nfl', repeat('1',64), repeat('2',64), 'exact',
      'snake', 'all_players', '{"pick_timer":86401}'::jsonb, 2, 2, 60
    ) as out_of_range
  $$,
  $$ values (true, true, true, true, true, true) $$,
  'malformed exact setting values remain fingerprinted and fail closed to unknown without cast errors'
);

select has_column(
  'public', 'leagues', 'draft_collection_fetched_at',
  'leagues record the draft-collection fetch watermark'
);
select has_column(
  'public', 'leagues', 'draft_collection_count',
  'leagues record the complete draft-collection count'
);
select has_column(
  'public', 'leagues', 'draft_collection_fingerprint',
  'leagues record the complete draft-collection fingerprint'
);
select col_is_null(
  'public', 'leagues', 'draft_collection_fetched_at',
  'an unobserved league draft collection has no fetch watermark'
);
select col_is_null(
  'public', 'leagues', 'draft_collection_count',
  'an unobserved league draft collection has no count'
);
select col_is_null(
  'public', 'leagues', 'draft_collection_fingerprint',
  'an unobserved league draft collection has no fingerprint'
);

select has_table(
  'public', 'fantasy_account_draft_collections',
  'account draft collection state exists'
);
select has_table('public', 'drafts', 'shared canonical drafts exist');
select has_table('public', 'draft_slots', 'normalized draft slots exist');
select has_table(
  'public', 'fantasy_account_drafts',
  'tracked-account draft participation exists'
);
select has_table('public', 'draft_picks', 'historical draft picks exist');

select results_eq(
  $$
    select array_agg(column_name order by ordinal_position)::text[] collate "C"
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fantasy_account_draft_collections'
  $$,
  $$ values (array[
    'fantasy_account_id', 'sport', 'season', 'source_fetched_at',
    'source_draft_count', 'collection_fingerprint', 'source_metadata',
    'created_at', 'updated_at'
  ]::text[] collate "C") $$,
  'account draft collections expose exactly the reviewed storage shape'
);
select results_eq(
  $$
    select array_agg(column_name order by ordinal_position)::text[] collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'drafts'
  $$,
  $$ values (array[
    'id', 'provider', 'external_draft_id', 'context_type', 'league_id',
    'sport', 'season', 'season_type', 'draft_type', 'draft_type_family',
    'status', 'name', 'description', 'team_count', 'round_count',
    'pick_timer_seconds', 'start_time', 'provider_created_at',
    'last_picked_at', 'last_message_at', 'last_message_id',
    'source_creators', 'source_draft_order', 'source_slot_to_roster_id',
    'settings', 'metadata', 'league_format_context_id',
    'context_resolution_status', 'context_observed_at',
    'draft_environment_version', 'draft_settings_fingerprint',
    'draft_environment_fingerprint', 'draft_environment_compatibility_key',
    'draft_environment_quality', 'draft_pool_type', 'capital_type',
    'context_metadata', 'draft_fetched_at', 'first_seen_at', 'last_seen_at',
    'removed_at', 'board_state', 'board_fetched_at', 'board_slot_count',
    'board_pick_count', 'board_fingerprint_version', 'board_fingerprint',
    'board_finalized_at', 'contains_keeper_picks', 'created_at', 'updated_at'
  ]::text[] collate "C") $$,
  'drafts expose exactly the reviewed shared identity and board shape'
);
select results_eq(
  $$
    select array_agg(column_name order by ordinal_position)::text[] collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'draft_slots'
  $$,
  $$ values (array[
    'id', 'draft_id', 'draft_slot', 'source_user_ids',
    'external_roster_id', 'roster_id', 'source_metadata', 'fetched_at',
    'first_seen_at', 'last_seen_at', 'removed_at', 'created_at', 'updated_at'
  ]::text[] collate "C") $$,
  'draft slots expose exactly the reviewed normalized slot shape'
);
select results_eq(
  $$
    select array_agg(column_name order by ordinal_position)::text[] collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'fantasy_account_drafts'
  $$,
  $$ values (array[
    'id', 'fantasy_account_id', 'draft_id', 'participation_status',
    'draft_slot', 'source_metadata', 'observed_at', 'first_seen_at',
    'last_seen_at', 'removed_at', 'created_at', 'updated_at'
  ]::text[] collate "C") $$,
  'participation exposes exactly the reviewed account-scoped shape'
);
select results_eq(
  $$
    select array_agg(column_name order by ordinal_position)::text[] collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'draft_picks'
  $$,
  $$ values (array[
    'id', 'draft_id', 'draft_slot', 'pick_no', 'round', 'player_id',
    'source_player_external_id_id', 'picked_by_external_user_id',
    'external_roster_id', 'roster_id', 'is_keeper', 'auction_amount',
    'picked_at', 'player_display_name_at_draft',
    'player_entity_type_at_draft', 'player_primary_position_at_draft',
    'player_fantasy_positions_at_draft', 'nfl_team_at_draft',
    'player_status_at_draft', 'injury_status_at_draft',
    'source_player_metadata', 'source_metadata', 'source_fetched_at',
    'first_seen_at', 'last_seen_at', 'removed_at', 'created_at', 'updated_at'
  ]::text[] collate "C") $$,
  'draft picks expose exactly the reviewed historical selection shape'
);

select is(
  (
    select count(*)::integer
    from pg_class
    where oid in (
      'public.fantasy_account_draft_collections'::regclass,
      'public.drafts'::regclass,
      'public.draft_slots'::regclass,
      'public.fantasy_account_drafts'::regclass,
      'public.draft_picks'::regclass
    )
      and relrowsecurity
  ),
  5,
  'RLS is enabled on all five draft-domain tables'
);

select has_function(
  'app_private', 'enforce_draft_board_lifecycle', array[]::text[],
  'the draft board lifecycle trigger function exists'
);
select has_function(
  'app_private', 'protect_finalized_draft_delete', array[]::text[],
  'the finalized draft deletion trigger function exists'
);
select has_function(
  'app_private', 'reject_finalized_draft_child_mutation', array[]::text[],
  'the draft child lifecycle trigger function exists'
);
select has_function(
  'app_private', 'protect_finalized_confirmed_participation',
  array[]::text[],
  'the finalized participation trigger function exists'
);
select is(
  (
    select count(*)::integer
    from pg_proc
    where oid in (
      'app_private.enforce_draft_board_lifecycle()'::regprocedure,
      'app_private.protect_finalized_draft_delete()'::regprocedure,
      'app_private.reject_finalized_draft_child_mutation()'::regprocedure,
      'app_private.protect_finalized_confirmed_participation()'::regprocedure
    )
      and proconfig @> array['search_path=pg_catalog']
  ),
  4,
  'all draft lifecycle trigger functions fix search_path to pg_catalog'
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('app_private.enforce_draft_board_lifecycle()'),
        ('app_private.protect_finalized_draft_delete()'),
        ('app_private.reject_finalized_draft_child_mutation()'),
        ('app_private.protect_finalized_confirmed_participation()')
    ) as lifecycle(signature)
    where has_function_privilege('postgres', lifecycle.signature, 'execute')
      and not has_function_privilege('anon', lifecycle.signature, 'execute')
      and not has_function_privilege('authenticated', lifecycle.signature, 'execute')
      and not has_function_privilege('service_role', lifecycle.signature, 'execute')
      and not exists (
        select 1
        from pg_proc
        cross join lateral aclexplode(proacl) as acl
        where oid = lifecycle.signature::regprocedure
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
  ),
  4,
  'all draft lifecycle trigger functions are owner-only'
);
select has_trigger(
  'public', 'drafts', 'drafts_enforce_board_lifecycle',
  'drafts enforce the board lifecycle before writes'
);
select has_trigger(
  'public', 'drafts', 'drafts_protect_finalized_delete',
  'drafts protect finalized rows from deletion'
);
select has_trigger(
  'public', 'draft_slots', 'draft_slots_protect_board_lifecycle',
  'draft slots enforce parent board lifecycle'
);
select has_trigger(
  'public', 'draft_picks', 'draft_picks_protect_board_lifecycle',
  'draft picks enforce parent board lifecycle'
);
select has_trigger(
  'public', 'fantasy_account_drafts',
  'fantasy_account_drafts_protect_finalized_confirmation',
  'participation protects finalized confirmed relationships'
);
select is(
  (
    select count(*)::integer
    from pg_trigger
    where tgrelid in (
      'public.fantasy_account_draft_collections'::regclass,
      'public.drafts'::regclass,
      'public.draft_slots'::regclass,
      'public.fantasy_account_drafts'::regclass,
      'public.draft_picks'::regclass
    )
      and not tgisinternal
      and tgname in (
        'fantasy_account_draft_collections_set_updated_at',
        'drafts_set_updated_at',
        'draft_slots_set_updated_at',
        'fantasy_account_drafts_set_updated_at',
        'draft_picks_set_updated_at'
      )
  ),
  5,
  'all five draft-domain tables retain automatic updated_at maintenance'
);

select policies_are(
  'public', 'fantasy_account_draft_collections',
  array['authenticated users can select their draft collections']
);
select policies_are(
  'public', 'fantasy_account_drafts',
  array['authenticated users can select their draft participation']
);
select policies_are(
  'public', 'drafts',
  array['authenticated users can select confirmed shared drafts']
);
select policies_are(
  'public', 'draft_slots',
  array['authenticated users can select confirmed draft slots']
);
select policies_are(
  'public', 'draft_picks',
  array['authenticated users can select confirmed draft picks']
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('fantasy_account_draft_collections', 8),
        ('fantasy_account_drafts', 11),
        ('drafts', 44),
        ('draft_slots', 10),
        ('draft_picks', 24)
    ) as expected(table_name, safe_column_count)
    where (
      select count(*)::integer
      from information_schema.columns as column_definition
      where column_definition.table_schema = 'public'
        and column_definition.table_name = expected.table_name
        and has_column_privilege(
          'authenticated',
          format('public.%I', expected.table_name),
          column_definition.column_name,
          'select'
        )
    ) = expected.safe_column_count
  ),
  5,
  'authenticated receives exactly the reviewed safe-column grant count on every draft table'
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('fantasy_account_draft_collections'),
        ('fantasy_account_drafts'),
        ('drafts'),
        ('draft_slots'),
        ('draft_picks')
    ) as provider_table(name)
    where not has_table_privilege(
      'authenticated', format('public.%I', provider_table.name), 'select'
    )
  ),
  5,
  'authenticated has no table-wide SELECT on draft-domain tables'
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('fantasy_account_draft_collections'),
        ('fantasy_account_drafts'),
        ('drafts'),
        ('draft_slots'),
        ('draft_picks')
    ) as provider_table(name)
    where not has_table_privilege(
      'service_role', format('public.%I', provider_table.name), 'select'
    )
      and not has_table_privilege(
        'service_role', format('public.%I', provider_table.name), 'insert'
      )
      and not has_table_privilege(
        'service_role', format('public.%I', provider_table.name), 'update'
      )
      and not has_table_privilege(
        'service_role', format('public.%I', provider_table.name), 'delete'
      )
  ),
  5,
  'service_role has no direct CRUD privilege on any draft-domain table'
);
select is(
  (
    select count(*)::integer
    from (
      values
        ('fantasy_account_draft_collections'),
        ('fantasy_account_drafts'),
        ('drafts'),
        ('draft_slots'),
        ('draft_picks')
    ) as provider_table(name)
    where not has_table_privilege(
      'anon', format('public.%I', provider_table.name), 'select'
    )
  ),
  5,
  'anon has no direct read privilege on any draft-domain table'
);
select has_index(
  'public', 'fantasy_account_draft_collections',
  'fantasy_account_draft_collections_pkey',
  'account collection RLS starts from its account-leading primary key'
);
select has_index(
  'public', 'fantasy_account_drafts',
  'fantasy_account_drafts_account_status_removed_idx',
  'participation account visibility has an account-leading index'
);
select has_index(
  'public', 'fantasy_account_drafts',
  'fantasy_account_drafts_visible_draft_account_idx',
  'shared draft visibility has a selective draft-leading participation index'
);
select has_index(
  'public', 'draft_slots', 'draft_slots_draft_removed_slot_idx',
  'visible draft-slot traversal is draft-leading and removal-aware'
);
select has_index(
  'public', 'draft_picks', 'draft_picks_board_coordinate_idx',
  'visible board traversal has a draft-leading coordinate index'
);

-- Generated IDs keep this contract safe to reuse against a rollback-only host.
select set_config('test.user_a', gen_random_uuid()::text, true);
select set_config('test.user_b', gen_random_uuid()::text, true);
select set_config('test.user_c', gen_random_uuid()::text, true);
select set_config('test.account_a', gen_random_uuid()::text, true);
select set_config('test.account_b', gen_random_uuid()::text, true);
select set_config('test.account_c', gen_random_uuid()::text, true);
select set_config('test.league_a', gen_random_uuid()::text, true);
select set_config('test.league_b', gen_random_uuid()::text, true);
select set_config('test.roster_a', gen_random_uuid()::text, true);
select set_config('test.roster_b', gen_random_uuid()::text, true);
select set_config('test.player_a', gen_random_uuid()::text, true);
select set_config('test.player_b', gen_random_uuid()::text, true);
select set_config('test.player_wrong_sport', gen_random_uuid()::text, true);
select set_config('test.player_nonprimary', gen_random_uuid()::text, true);
select set_config('test.mapping_a', gen_random_uuid()::text, true);
select set_config('test.mapping_b', gen_random_uuid()::text, true);
select set_config('test.mapping_wrong_provider', gen_random_uuid()::text, true);
select set_config('test.mapping_wrong_sport', gen_random_uuid()::text, true);
select set_config('test.mapping_nonprimary', gen_random_uuid()::text, true);
select set_config('test.mapping_removed', gen_random_uuid()::text, true);
select set_config('test.draft_shared', gen_random_uuid()::text, true);
select set_config('test.draft_unrelated', gen_random_uuid()::text, true);
select set_config('test.draft_not_fetched', gen_random_uuid()::text, true);
select set_config('test.draft_second', gen_random_uuid()::text, true);
select set_config('test.draft_partial', gen_random_uuid()::text, true);
select set_config('test.draft_standalone', gen_random_uuid()::text, true);
select set_config(
  'test.suffix', replace(gen_random_uuid()::text, '-', ''), true
);

create temporary table last_synced_before as
select id, last_synced_at
from public.fantasy_accounts;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  source.id,
  'authenticated',
  'authenticated',
  source.label || '-' || current_setting('test.suffix') || '@example.test',
  '',
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(), now(), '', '', '', ''
from (
  values
    (current_setting('test.user_a')::uuid, 'draft-user-a'),
    (current_setting('test.user_b')::uuid, 'draft-user-b'),
    (current_setting('test.user_c')::uuid, 'draft-user-c')
) as source(id, label);

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata
)
select
  source.id,
  'sleeper',
  source.external_prefix || current_setting('test.suffix'),
  source.username,
  source.username,
  '{}'::jsonb
from (
  values
    (current_setting('test.account_a')::uuid, 'draft-account-a-', 'draft_account_a'),
    (current_setting('test.account_b')::uuid, 'draft-account-b-', 'draft_account_b'),
    (current_setting('test.account_c')::uuid, 'draft-account-c-', 'draft_account_c')
) as source(id, external_prefix, username);

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values
  (
    current_setting('test.user_a')::uuid,
    current_setting('test.account_a')::uuid,
    true
  ),
  (
    current_setting('test.user_a')::uuid,
    current_setting('test.account_b')::uuid,
    false
  ),
  (
    current_setting('test.user_b')::uuid,
    current_setting('test.account_a')::uuid,
    true
  ),
  (
    current_setting('test.user_c')::uuid,
    current_setting('test.account_c')::uuid,
    true
  );

select set_config(
  'test.format_context',
  app_private.ensure_sleeper_league_format_context(
    'sleeper', 'nfl',
    '{"rec":1,"pass_td":4}'::jsonb,
    '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
    '{"type":0,"best_ball":0}'::jsonb,
    2, 6, 'redraft', false, false, false
  )::text,
  true
);

insert into public.leagues (
  id, provider, external_league_id, sport, season, name, status,
  season_type, team_count, roster_size, roster_management_type,
  is_best_ball, has_superflex, has_idp, scoring_format,
  settings, scoring_settings, roster_positions, provider_metadata,
  provider_updated_at, fetched_at, current_format_context_id
)
select
  source.id,
  'sleeper',
  source.external_prefix || current_setting('test.suffix'),
  'nfl', 2026, source.name, 'in_season', 'regular', 2, 6, 'redraft',
  false, false, false, 'ppr',
  '{"type":0,"best_ball":0}'::jsonb,
  '{"rec":1,"pass_td":4}'::jsonb,
  '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
  '{}'::jsonb, null, '2026-08-01 00:00:00+00'::timestamptz,
  current_setting('test.format_context')::uuid
from (
  values
    (current_setting('test.league_a')::uuid, 'draft-league-a-', 'Draft League A'),
    (current_setting('test.league_b')::uuid, 'draft-league-b-', 'Draft League B')
) as source(id, external_prefix, name);

insert into public.league_format_observations (
  league_id, format_context_id, observed_at, source, normalization_version
)
values
  (
    current_setting('test.league_a')::uuid,
    current_setting('test.format_context')::uuid,
    '2026-08-01 00:00:00+00', 'migration_backfill', 1
  ),
  (
    current_setting('test.league_b')::uuid,
    current_setting('test.format_context')::uuid,
    '2026-08-01 00:00:00+00', 'migration_backfill', 1
  ),
  (
    current_setting('test.league_a')::uuid,
    current_setting('test.format_context')::uuid,
    '2026-09-01 00:00:00+00', 'migration_backfill', 1
  );

insert into public.fantasy_account_leagues (
  fantasy_account_id, league_id, first_seen_at, last_seen_at
)
values
  (
    current_setting('test.account_a')::uuid,
    current_setting('test.league_a')::uuid,
    '2026-08-01', '2026-08-02'
  ),
  (
    current_setting('test.account_b')::uuid,
    current_setting('test.league_a')::uuid,
    '2026-08-01', '2026-08-02'
  ),
  (
    current_setting('test.account_c')::uuid,
    current_setting('test.league_b')::uuid,
    '2026-08-01', '2026-08-02'
  );

insert into public.rosters (
  id, league_id, external_roster_id,
  fetched_at, first_seen_at, last_seen_at
)
values
  (
    current_setting('test.roster_a')::uuid,
    current_setting('test.league_a')::uuid,
    1, '2026-08-02', '2026-08-01', '2026-08-02'
  ),
  (
    current_setting('test.roster_b')::uuid,
    current_setting('test.league_b')::uuid,
    1, '2026-08-02', '2026-08-01', '2026-08-02'
  );

insert into public.players (
  id, sport, entity_type, display_name, primary_position,
  fantasy_positions, nfl_team, profile_source, profile_fetched_at
)
values
  (
    current_setting('test.player_a')::uuid,
    'nfl', 'player', 'Draft Player A', 'QB', array['QB'], 'SEA',
    'sleeper', '2026-08-01'
  ),
  (
    current_setting('test.player_b')::uuid,
    'nfl', 'player', 'Draft Player B', 'RB', array['RB'], 'LAR',
    'sleeper', '2026-08-01'
  ),
  (
    current_setting('test.player_wrong_sport')::uuid,
    'cfb', 'player', 'Wrong Sport Player', 'QB', array['QB'], null,
    'sleeper', '2026-08-01'
  ),
  (
    current_setting('test.player_nonprimary')::uuid,
    'nfl', 'player', 'Nonprimary Mapping Player', 'WR', array['WR'], 'SF',
    'sleeper', '2026-08-01'
  );

insert into public.player_external_ids (
  id, player_id, namespace, sport, external_id, reported_by,
  is_primary, source_metadata, first_seen_at, last_seen_at, removed_at
)
values
  (
    current_setting('test.mapping_a')::uuid,
    current_setting('test.player_a')::uuid,
    'sleeper', 'nfl', 'draft-player-a-' || current_setting('test.suffix'),
    'sleeper', true, '{}'::jsonb, '2026-08-01', '2026-08-02', null
  ),
  (
    current_setting('test.mapping_b')::uuid,
    current_setting('test.player_b')::uuid,
    'sleeper', 'nfl', 'draft-player-b-' || current_setting('test.suffix'),
    'sleeper', true, '{}'::jsonb, '2026-08-01', '2026-08-02', null
  ),
  (
    current_setting('test.mapping_wrong_provider')::uuid,
    current_setting('test.player_a')::uuid,
    'other', 'nfl', 'wrong-provider-' || current_setting('test.suffix'),
    'other', false, '{}'::jsonb, '2026-08-01', '2026-08-02', null
  ),
  (
    current_setting('test.mapping_wrong_sport')::uuid,
    current_setting('test.player_wrong_sport')::uuid,
    'sleeper', 'cfb', 'wrong-sport-' || current_setting('test.suffix'),
    'sleeper', false, '{}'::jsonb, '2026-08-01', '2026-08-02', null
  ),
  (
    current_setting('test.mapping_nonprimary')::uuid,
    current_setting('test.player_nonprimary')::uuid,
    'sleeper', 'nfl', 'nonprimary-' || current_setting('test.suffix'),
    'sleeper', false, '{}'::jsonb, '2026-08-01', '2026-08-02', null
  ),
  (
    current_setting('test.mapping_removed')::uuid,
    current_setting('test.player_a')::uuid,
    'sleeper', 'nfl', 'removed-' || current_setting('test.suffix'),
    'sleeper', true, '{}'::jsonb, '2026-08-01', '2026-08-02', '2026-08-03'
  );

-- Collection-state contract -------------------------------------------------

select results_eq(
  format(
    $$
      select draft_collection_fetched_at, draft_collection_count,
        draft_collection_fingerprint
      from public.leagues where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  $$ values (null::timestamptz, null::integer, null::text) $$,
  'an unobserved league draft collection is represented by three nulls'
);
select lives_ok(
  format(
    $$
      update public.leagues
      set draft_collection_fetched_at = '2026-08-03 00:00:00+00',
        draft_collection_count = 0,
        draft_collection_fingerprint = repeat('0', 64)
      where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  'an explicitly empty complete league draft collection is representable'
);
select throws_ok(
  format(
    $$
      update public.leagues set draft_collection_count = null
      where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  '23514', null,
  'a partial league draft collection state is rejected'
);
select throws_ok(
  format(
    $$
      update public.leagues set draft_collection_count = -1
      where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  '23514', null,
  'a negative league collection count is rejected'
);
select throws_ok(
  format(
    $$
      update public.leagues set draft_collection_fingerprint = 'BAD'
      where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  '23514', null,
  'a malformed league collection fingerprint is rejected'
);
select throws_ok(
  format(
    $$
      update public.leagues set draft_collection_fetched_at = 'infinity'
      where id = %L::uuid
    $$,
    current_setting('test.league_a')
  ),
  '23514', null,
  'a nonfinite league collection timestamp is rejected'
);

insert into public.fantasy_account_draft_collections (
  fantasy_account_id, sport, season, source_fetched_at,
  source_draft_count, collection_fingerprint, source_metadata
)
values
  (
    current_setting('test.account_a')::uuid, 'nfl', 2025,
    '2026-08-03', 0, repeat('1', 64), '{}'
  ),
  (
    current_setting('test.account_a')::uuid, 'nfl', 2026,
    '2026-08-04', 2, repeat('2', 64), '{"source":"user_drafts"}'
  ),
  (
    current_setting('test.account_b')::uuid, 'nfl', 2026,
    '2026-08-04', 1, repeat('3', 64), '{}'
  ),
  (
    current_setting('test.account_c')::uuid, 'nfl', 2026,
    '2026-08-04', 1, repeat('4', 64), '{}'
  );

select is(
  (
    select count(*)::integer
    from public.fantasy_account_draft_collections
    where fantasy_account_id = current_setting('test.account_a')::uuid
  ),
  2,
  'account collection grain preserves independent seasons'
);
select is(
  (
    select source_draft_count
    from public.fantasy_account_draft_collections
    where fantasy_account_id = current_setting('test.account_a')::uuid
      and season = 2025
  ),
  0,
  'zero user drafts is a valid explicit account collection'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_draft_collections (
        fantasy_account_id, sport, season, source_fetched_at,
        source_draft_count, collection_fingerprint
      ) values (%L::uuid, 'nfl', 2026, now(), 0, repeat('5',64))
    $$,
    current_setting('test.account_a')
  ),
  '23505', null,
  'one account sport and season has only one latest collection row'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_draft_collections (
        fantasy_account_id, sport, season, source_fetched_at,
        source_draft_count, collection_fingerprint
      ) values (%L::uuid, 'nfl', 2027, now(), 10001, repeat('5',64))
    $$,
    current_setting('test.account_a')
  ),
  '23514', null,
  'account collection counts are bounded'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_draft_collections (
        fantasy_account_id, sport, season, source_fetched_at,
        source_draft_count, collection_fingerprint
      ) values (%L::uuid, 'nfl', 2027, now(), 0, 'bad')
    $$,
    current_setting('test.account_a')
  ),
  '23514', null,
  'account collection fingerprints are exact lowercase SHA-256 values'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_draft_collections (
        fantasy_account_id, sport, season, source_fetched_at,
        source_draft_count, collection_fingerprint, source_metadata
      ) values (%L::uuid, 'nfl', 2027, now(), 0, repeat('5',64), '[]')
    $$,
    current_setting('test.account_a')
  ),
  '23514', null,
  'account collection source metadata must be a bounded object'
);

-- Canonical draft identity and historical environment -----------------------

create function pg_temp.create_test_draft(
  p_id uuid,
  p_external_draft_id text,
  p_league_id uuid,
  p_format_context_id uuid,
  p_context_observed_at timestamptz,
  p_context_resolution_status text,
  p_draft_type text,
  p_draft_pool_type text,
  p_board_state text,
  p_status text
)
returns void
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_format_fingerprint text;
  v_format_compatibility_key text;
  v_classification record;
begin
  if p_context_resolution_status in ('exact', 'partial') then
    select format.format_fingerprint, format.compatibility_key
    into v_format_fingerprint, v_format_compatibility_key
    from public.league_format_contexts as format
    where format.id = p_format_context_id;
  end if;

  select classified.*
  into v_classification
  from app_private.classify_sleeper_draft_environment_v1(
    'sleeper', 'nfl', v_format_fingerprint, v_format_compatibility_key,
    p_context_resolution_status, p_draft_type, p_draft_pool_type,
    '{"teams":2,"rounds":2,"pick_timer":60}'::jsonb,
    2, 2, 60
  ) as classified;

  insert into public.drafts (
    id, provider, external_draft_id, context_type, league_id,
    sport, season, season_type, draft_type, draft_type_family,
    status, name, description, team_count, round_count,
    pick_timer_seconds, start_time, provider_created_at,
    source_creators, source_draft_order, source_slot_to_roster_id,
    settings, metadata, league_format_context_id,
    context_resolution_status, context_observed_at,
    draft_environment_version, draft_settings_fingerprint,
    draft_environment_fingerprint, draft_environment_compatibility_key,
    draft_environment_quality, draft_pool_type, capital_type,
    context_metadata, draft_fetched_at, first_seen_at, last_seen_at,
    board_state, board_fetched_at, board_slot_count, board_pick_count,
    board_fingerprint_version, board_fingerprint, board_finalized_at,
    contains_keeper_picks
  )
  values (
    p_id, 'sleeper', p_external_draft_id,
    case when p_league_id is null then 'standalone' else 'league' end,
    p_league_id, 'nfl', 2026, 'regular', p_draft_type,
    v_classification.draft_type_family, p_status, 'Reusable Draft Name',
    'A bounded historical draft fixture', 2, 2, 60,
    '2026-08-15 00:00:00+00', '2026-08-10 00:00:00+00',
    array['creator-b', 'creator-a'],
    '{"creator-a":1,"creator-b":1}'::jsonb,
    '{"1":1,"2":2}'::jsonb,
    '{"teams":2,"rounds":2,"pick_timer":60}'::jsonb,
    '{"scoring_type":"metadata-must-not-drive-context"}'::jsonb,
    p_format_context_id, p_context_resolution_status,
    p_context_observed_at, 1,
    v_classification.draft_settings_fingerprint,
    v_classification.draft_environment_fingerprint,
    v_classification.draft_environment_compatibility_key,
    v_classification.environment_quality,
    p_draft_pool_type,
    v_classification.capital_type,
    '{}'::jsonb,
    '2026-08-16 00:00:00+00',
    '2026-08-16 00:00:00+00',
    '2026-08-16 00:00:00+00',
    p_board_state,
    case when p_board_state = 'not_fetched' then null
      else '2026-08-16 00:00:00+00'::timestamptz end,
    case when p_board_state = 'not_fetched' then null else 0 end,
    case when p_board_state = 'not_fetched' then null else 0 end,
    case when p_board_state = 'not_fetched' then null else 1 end,
    case when p_board_state = 'not_fetched' then null else repeat('a', 64) end,
    null,
    case when p_board_state = 'not_fetched' then null else false end
  );
end;
$$;

select pg_temp.create_test_draft(
  current_setting('test.draft_shared')::uuid,
  'shared-' || current_setting('test.suffix'),
  current_setting('test.league_a')::uuid,
  current_setting('test.format_context')::uuid,
  '2026-08-01', 'exact', 'snake', 'all_players', 'mutable', 'complete'
);
select pg_temp.create_test_draft(
  current_setting('test.draft_unrelated')::uuid,
  'unrelated-' || current_setting('test.suffix'),
  current_setting('test.league_b')::uuid,
  current_setting('test.format_context')::uuid,
  '2026-08-01', 'exact', 'linear', 'all_players', 'mutable', 'complete'
);
select pg_temp.create_test_draft(
  current_setting('test.draft_not_fetched')::uuid,
  'not-fetched-' || current_setting('test.suffix'),
  current_setting('test.league_a')::uuid,
  current_setting('test.format_context')::uuid,
  '2026-08-01', 'exact', 'snake', 'rookies', 'not_fetched', 'pre_draft'
);
select pg_temp.create_test_draft(
  current_setting('test.draft_second')::uuid,
  'second-' || current_setting('test.suffix'),
  current_setting('test.league_a')::uuid,
  current_setting('test.format_context')::uuid,
  '2026-08-01', 'exact', 'snake', 'all_players', 'not_fetched', 'pre_draft'
);
select pg_temp.create_test_draft(
  current_setting('test.draft_partial')::uuid,
  'partial-' || current_setting('test.suffix'),
  current_setting('test.league_a')::uuid,
  current_setting('test.format_context')::uuid,
  '2026-09-01', 'partial', 'auction', 'all_players', 'not_fetched', 'complete'
);
select pg_temp.create_test_draft(
  current_setting('test.draft_standalone')::uuid,
  'standalone-' || current_setting('test.suffix'),
  null, null, null, 'unknown', 'future_type', 'unknown',
  'not_fetched', 'future_status'
);

select results_eq(
  format(
    $$
      select context_resolution_status, draft_environment_quality,
        draft_type_family, capital_type
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values ('exact'::text, 'exact'::text, 'snake'::text, 'overall_pick'::text) $$,
  'a real same-league context observed before the anchor produces exact environment identity'
);
select results_eq(
  format(
    $$
      select context_resolution_status, draft_environment_quality,
        draft_type_family, capital_type
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_partial')
  ),
  $$ values ('partial'::text, 'partial'::text, 'auction'::text, 'auction_value'::text) $$,
  'a real context observed after the anchor remains explicitly partial'
);
select results_eq(
  format(
    $$
      select context_type, league_id, league_format_context_id,
        context_observed_at, draft_environment_quality,
        draft_type_family, capital_type
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_standalone')
  ),
  $$ values (
    'standalone'::text, null::uuid, null::uuid, null::timestamptz,
    'unknown'::text, 'unknown'::text, 'unknown'::text
  ) $$,
  'standalone future source values remain representable without invented context'
);
select is(
  (
    select count(*)::integer
    from public.drafts
    where league_id = current_setting('test.league_a')::uuid
  ),
  4,
  'one league supports multiple canonical drafts'
);
select is(
  (
    select count(distinct name)::integer
    from public.drafts
    where league_id = current_setting('test.league_a')::uuid
  ),
  1,
  'draft display names are intentionally nonunique'
);
select throws_ok(
  format(
    $$
      select pg_temp.create_test_draft(
        gen_random_uuid(), %L, %L::uuid, %L::uuid, '2026-08-01',
        'exact', 'snake', 'all_players', 'not_fetched', 'pre_draft'
      )
    $$,
    'shared-' || current_setting('test.suffix'),
    current_setting('test.league_a'),
    current_setting('test.format_context')
  ),
  '23505', null,
  'provider plus exact external draft ID is canonical and unique'
);
select throws_ok(
  format(
    $$
      select pg_temp.create_test_draft(
        gen_random_uuid(), %L, %L::uuid, %L::uuid, '2026-09-01',
        'exact', 'snake', 'all_players', 'not_fetched', 'pre_draft'
      )
    $$,
    'late-exact-' || current_setting('test.suffix'),
    current_setting('test.league_a'),
    current_setting('test.format_context')
  ),
  '23514', null,
  'a context observed after the draft anchor cannot claim exact resolution'
);
select throws_ok(
  format(
    $$
      update public.drafts set context_type = 'standalone'
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'standalone context rejects a league identity'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set league_format_context_id = %L::uuid,
        context_observed_at = '2026-08-01'
      where id = %L::uuid
    $$,
    current_setting('test.format_context'),
    current_setting('test.draft_standalone')
  ),
  '23514', null,
  'unknown context requires null context evidence fields'
);
select throws_ok(
  format(
    $$ update public.drafts set sport = 'nba' where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '22023', null,
  'a linked draft cannot drift from its reviewed provider sport namespace'
);
select throws_ok(
  format(
    $$ update public.drafts set season = 2025 where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '23503', null,
  'a linked draft season must match the canonical league'
);
select throws_ok(
  format(
    $$ update public.drafts set external_draft_id = ' bad' where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'source draft tokens reject outer whitespace'
);
select throws_ok(
  format(
    $$ update public.drafts set name = E'bad\nname' where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'draft display fields reject control characters'
);
select throws_ok(
  format(
    $$ update public.drafts set team_count = 1001 where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '22023', null,
  'typed draft dimensions are conservatively bounded'
);
select throws_ok(
  format(
    $$ update public.drafts set settings = '[]'::jsonb where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  '22023', null,
  'exact draft settings must be a bounded object'
);
select lives_ok(
  format(
    $$
      update public.drafts
      set source_creators = null,
        source_draft_order = null,
        source_slot_to_roster_id = null
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  'absent exact creators and maps remain null'
);
select lives_ok(
  format(
    $$
      update public.drafts
      set source_creators = array[]::text[],
        source_draft_order = '{}'::jsonb,
        source_slot_to_roster_id = '{}'::jsonb
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  'explicitly empty exact creators and maps remain empty values'
);
select results_eq(
  format(
    $$
      select source_creators, source_draft_order, source_slot_to_roster_id
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  $$ values (array[]::text[], '{}'::jsonb, '{}'::jsonb) $$,
  'null and explicit-empty exact source collections stay distinguishable'
);
select lives_ok(
  format(
    $$
      update public.drafts
      set source_creators = array['creator-z','creator-a'],
        source_draft_order = '{"creator-a":1,"creator-z":1}'::jsonb,
        source_slot_to_roster_id = '{"1":1}'::jsonb
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  'exact creator order is preserved and several users may map to one slot'
);
select results_eq(
  format(
    $$ select source_creators from public.drafts where id = %L::uuid $$,
    current_setting('test.draft_second')
  ),
  $$ values (array['creator-z','creator-a']::text[]) $$,
  'creator order is not normalized away'
);
select throws_ok(
  format(
    $$
      update public.drafts set source_creators = array['same','same']
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'duplicate exact creator IDs are rejected'
);
select throws_ok(
  format(
    $$
      update public.drafts set source_draft_order = '{"creator":0}'
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'malformed draft-order slot values are rejected'
);
select throws_ok(
  format(
    $$
      update public.drafts set source_slot_to_roster_id = '{"01":1}'
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'malformed slot-to-roster canonical keys are rejected'
);
select throws_ok(
  format(
    $$
      update public.drafts set removed_at = '2026-08-15'
      where id = %L::uuid
    $$,
    current_setting('test.draft_second')
  ),
  '23514', null,
  'draft observation watermarks cannot move backward'
);

select results_eq(
  format(
    $$
      select metadata ->> 'scoring_type', context_resolution_status,
        league_format_context_id is not null
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values ('metadata-must-not-drive-context'::text, 'exact'::text, true) $$,
  'draft metadata scoring_type is retained but never substitutes for exact league context'
);

-- Slots and explicit account participation ----------------------------------

select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 1, now(), now(), now())
    $$,
    current_setting('test.draft_not_fetched')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'a not-fetched draft cannot accept board children'
);

insert into public.draft_slots (
  draft_id, draft_slot, source_user_ids, external_roster_id, roster_id,
  source_metadata, fetched_at, first_seen_at, last_seen_at
)
values
  (
    current_setting('test.draft_shared')::uuid,
    1, array['source-a','source-b'], 1,
    current_setting('test.roster_a')::uuid,
    '{"source":"draft_order"}', '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.draft_shared')::uuid,
    2, array[]::text[], null, null,
    '{}', '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.draft_unrelated')::uuid,
    1, array['unrelated-user'], 1,
    current_setting('test.roster_b')::uuid,
    '{}', '2026-08-17', '2026-08-17', '2026-08-17'
  );

select results_eq(
  format(
    $$
      select draft_slot, source_user_ids, roster_id
      from public.draft_slots
      where draft_id = %L::uuid
      order by draft_slot
    $$,
    current_setting('test.draft_shared')
  ),
  format(
    $$ values
      (1, array['source-a','source-b']::text[], %L::uuid),
      (2, array[]::text[], null::uuid)
    $$,
    current_setting('test.roster_a')
  ),
  'one row per slot preserves shared users, explicit empty assignment, and optional roster resolution'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 1, now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23505', null,
  'one draft has at most one row for each slot number'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, source_user_ids,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, array['z','a'], now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'non-null slot source users must be deterministically C-sorted'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, source_user_ids,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, array['same','same'], now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'slot source-user assignments must be unique'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, source_user_ids,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, array[' bad'], now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'slot source-user identifiers must be exact and trimmed'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 0, now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'draft slots are positively bounded'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, external_roster_id, roster_id,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, 1, %L::uuid, now(), now(), now())
    $$,
    current_setting('test.draft_shared'),
    current_setting('test.roster_b')
  ),
  '23514',
  'The draft slot roster resolution is inconsistent.',
  'a draft slot cannot resolve to a roster in another league'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, external_roster_id, roster_id,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, 2, %L::uuid, now(), now(), now())
    $$,
    current_setting('test.draft_shared'),
    current_setting('test.roster_a')
  ),
  '23514',
  'The draft slot roster resolution is inconsistent.',
  'a canonical slot roster must match the exact external roster ID'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, source_metadata,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, '[]', now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'slot source metadata must be a bounded object'
);
select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, now(), '2026-08-18', '2026-08-17')
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'slot observation timestamps cannot regress'
);
select lives_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, source_user_ids,
        fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, null, now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  'mutable boards accept unresolved slot assignments'
);
select lives_ok(
  format(
    $$
      update public.draft_slots
      set source_metadata = '{"refreshed":true}', last_seen_at = now()
      where draft_id = %L::uuid and draft_slot = 3
    $$,
    current_setting('test.draft_shared')
  ),
  'mutable board slots accept observation updates'
);
select lives_ok(
  format(
    $$
      update public.draft_slots set removed_at = now()
      where draft_id = %L::uuid and draft_slot = 3
    $$,
    current_setting('test.draft_shared')
  ),
  'unreferenced mutable board slots may be soft-removed'
);
select lives_ok(
  format(
    $$
      delete from public.draft_slots
      where draft_id = %L::uuid and draft_slot = 3
    $$,
    current_setting('test.draft_shared')
  ),
  'unreferenced mutable board slots may be deleted'
);

insert into public.fantasy_account_drafts (
  fantasy_account_id, draft_id, participation_status, draft_slot,
  source_metadata, observed_at, first_seen_at, last_seen_at
)
values
  (
    current_setting('test.account_a')::uuid,
    current_setting('test.draft_shared')::uuid,
    'confirmed', 1, '{"evidence":"draft_order"}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.account_b')::uuid,
    current_setting('test.draft_shared')::uuid,
    'confirmed', 1, '{"evidence":"user_drafts"}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.account_c')::uuid,
    current_setting('test.draft_unrelated')::uuid,
    'confirmed', 1, '{"evidence":"draft_order"}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.account_b')::uuid,
    current_setting('test.draft_unrelated')::uuid,
    'unresolved', null, '{"evidence":"user_drafts"}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  );

select is(
  (
    select count(*)::integer
    from public.fantasy_account_drafts
    where draft_id = current_setting('test.draft_shared')::uuid
      and participation_status = 'confirmed'
  ),
  2,
  'different canonical fantasy accounts retain independent participation truth for one draft'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_drafts (
        fantasy_account_id, draft_id, participation_status, draft_slot,
        observed_at, first_seen_at, last_seen_at
      ) values (%L::uuid, %L::uuid, 'confirmed', null, now(), now(), now())
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_unrelated')
  ),
  '23514', null,
  'confirmed participation requires one real slot'
);
select throws_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set participation_status = 'not_participant', draft_slot = 1
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_unrelated')
  ),
  '23514', null,
  'negative participation cannot retain a slot'
);
select throws_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set participation_status = 'confirmed', draft_slot = 999
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_unrelated')
  ),
  '23514', null,
  'confirmed participation rejects an unknown or inactive slot'
);
select lives_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set participation_status = 'confirmed', draft_slot = 1,
        source_metadata = '{"evidence":"combined"}',
        observed_at = '2026-08-18', last_seen_at = '2026-08-18'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_unrelated')
  ),
  'unresolved participation may become confirmed when stronger evidence appears'
);
select lives_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set participation_status = 'unresolved', draft_slot = null,
        observed_at = '2026-08-19', last_seen_at = '2026-08-19'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_unrelated')
  ),
  'mutable boards permit a participation correction before finalization'
);
select throws_ok(
  format(
    $$
      insert into public.fantasy_account_drafts (
        fantasy_account_id, draft_id, participation_status, draft_slot,
        observed_at, first_seen_at, last_seen_at
      ) values (%L::uuid, %L::uuid, 'unresolved', null, now(), now(), now())
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  '23505', null,
  'one account and draft has one participation relationship'
);
select lives_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set removed_at = '2026-08-18 00:00:00+00'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_shared')
  ),
  'mutable confirmed participation may be soft-removed during collection reconciliation'
);
select lives_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set removed_at = null,
        observed_at = '2026-08-19 00:00:00+00',
        last_seen_at = '2026-08-19 00:00:00+00'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_b'),
    current_setting('test.draft_shared')
  ),
  'mutable confirmed participation may be reactivated when active-slot evidence returns'
);

-- Draft picks and exact historical player context ---------------------------

insert into public.draft_picks (
  draft_id, draft_slot, pick_no, round, player_id,
  source_player_external_id_id, picked_by_external_user_id,
  external_roster_id, roster_id, is_keeper, auction_amount, picked_at,
  player_display_name_at_draft, player_entity_type_at_draft,
  player_primary_position_at_draft, player_fantasy_positions_at_draft,
  nfl_team_at_draft, player_status_at_draft, injury_status_at_draft,
  source_player_metadata, source_metadata, source_fetched_at,
  first_seen_at, last_seen_at
)
values
  (
    current_setting('test.draft_shared')::uuid,
    1, 1, 1,
    current_setting('test.player_a')::uuid,
    current_setting('test.mapping_a')::uuid,
    null, 1, current_setting('test.roster_a')::uuid,
    null, null, '2026-08-17 00:01:00+00',
    'Draft Player A', 'player', 'QB', null, 'SEA', 'Active', null,
    '{"source":"catalog"}', '{"picked_by":""}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.draft_shared')::uuid,
    2, 2, 1,
    current_setting('test.player_b')::uuid,
    current_setting('test.mapping_b')::uuid,
    'source-b', null, null,
    false, 0, '2026-08-17 00:02:00+00',
    'Draft Player B', 'player', 'RB', array[]::text[], 'DEN', 'Active', null,
    '{"source":"catalog"}', '{}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.draft_shared')::uuid,
    1, 3, 1,
    current_setting('test.player_a')::uuid,
    current_setting('test.mapping_a')::uuid,
    'source-a', 1, current_setting('test.roster_a')::uuid,
    true, 10, '2026-08-17 00:03:00+00',
    'Draft Player A', 'player', 'QB', array['QB','SUPER_FLEX'],
    'SEA', 'Active', 'Questionable',
    '{"source":"catalog"}', '{}',
    '2026-08-17', '2026-08-17', '2026-08-17'
  ),
  (
    current_setting('test.draft_unrelated')::uuid,
    1, 1, 1,
    current_setting('test.player_b')::uuid,
    current_setting('test.mapping_b')::uuid,
    'unrelated-user', 1, current_setting('test.roster_b')::uuid,
    false, null, '2026-08-17 00:01:00+00',
    'Draft Player B', 'player', 'RB', array['RB'], 'LAR', 'Active', null,
    '{}', '{}', '2026-08-17', '2026-08-17', '2026-08-17'
  );

select results_eq(
  format(
    $$
      select pick_no, is_keeper, auction_amount,
        player_fantasy_positions_at_draft
      from public.draft_picks where draft_id = %L::uuid order by pick_no
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values
    (1, null::boolean, null::numeric, null::text[]),
    (2, false, 0::numeric, array[]::text[]),
    (3, true, 10::numeric, array['QB','SUPER_FLEX']::text[])
  $$,
  'keeper, auction, and draft-time position null/empty/value states remain distinct'
);
select results_eq(
  format(
    $$
      select picked_by_external_user_id, source_metadata ->> 'picked_by'
      from public.draft_picks where draft_id = %L::uuid and pick_no = 1
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values (null::text, ''::text) $$,
  'an empty source picked-by value normalizes to null while exact source state remains metadata'
);
select results_eq(
  format(
    $$
      select nfl_team_at_draft,
        (select nfl_team from public.players where id = pick.player_id)
      from public.draft_picks as pick
      where pick.draft_id = %L::uuid and pick.pick_no = 2
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values ('DEN'::text, 'LAR'::text) $$,
  'NFL team at draft remains independent from the mutable current player team'
);
select is(
  (
    select count(*)::integer
    from public.draft_picks
    where draft_id = current_setting('test.draft_shared')::uuid
      and round = 1 and draft_slot = 1
  ),
  2,
  'draft pick identity does not assume unique round and slot cells'
);

create function pg_temp.insert_shared_pick(
  p_pick_no integer,
  p_draft_slot integer default 1,
  p_round integer default 1,
  p_player_id uuid default null,
  p_mapping_id uuid default null,
  p_picked_by text default 'source-a',
  p_external_roster_id integer default 1,
  p_roster_id uuid default null,
  p_auction_amount numeric default 1,
  p_entity_type text default 'player',
  p_primary_position text default 'QB',
  p_fantasy_positions text[] default array['QB'],
  p_source_player_metadata jsonb default '{}'::jsonb,
  p_source_metadata jsonb default '{}'::jsonb,
  p_removed_at timestamptz default null
)
returns void
language plpgsql
set search_path = pg_catalog
as $$
begin
  insert into public.draft_picks (
    draft_id, draft_slot, pick_no, round, player_id,
    source_player_external_id_id, picked_by_external_user_id,
    external_roster_id, roster_id, is_keeper, auction_amount, picked_at,
    player_display_name_at_draft, player_entity_type_at_draft,
    player_primary_position_at_draft, player_fantasy_positions_at_draft,
    nfl_team_at_draft, player_status_at_draft,
    source_player_metadata, source_metadata, source_fetched_at,
    first_seen_at, last_seen_at, removed_at
  )
  values (
    current_setting('test.draft_shared')::uuid,
    p_draft_slot, p_pick_no, p_round,
    coalesce(p_player_id, current_setting('test.player_a')::uuid),
    coalesce(p_mapping_id, current_setting('test.mapping_a')::uuid),
    p_picked_by, p_external_roster_id,
    coalesce(p_roster_id, current_setting('test.roster_a')::uuid),
    false, p_auction_amount, '2026-08-17 00:10:00+00',
    'Draft Test Player', p_entity_type, p_primary_position,
    p_fantasy_positions, 'SEA', 'Active',
    p_source_player_metadata, p_source_metadata,
    '2026-08-17', '2026-08-17', '2026-08-17', p_removed_at
  );
end;
$$;

select throws_ok(
  $$ select pg_temp.insert_shared_pick(1) $$,
  '23505', null,
  'one draft has only one canonical row per exact pick number'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_draft_slot => 99) $$,
  '23514',
  'An active draft pick requires an active draft slot.',
  'active picks require one real active draft slot'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(0) $$,
  '23514', null,
  'pick number is positively bounded'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_round => 0) $$,
  '23514', null,
  'draft round is positively bounded'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_player_id => %L::uuid, p_mapping_id => %L::uuid
      )
    $$,
    current_setting('test.player_a'),
    current_setting('test.mapping_b')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'a pick mapping must belong to the same canonical player'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_player_id => %L::uuid, p_mapping_id => %L::uuid
      )
    $$,
    current_setting('test.player_a'),
    current_setting('test.mapping_wrong_provider')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'a pick mapping must match the draft provider namespace'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_player_id => %L::uuid, p_mapping_id => %L::uuid
      )
    $$,
    current_setting('test.player_wrong_sport'),
    current_setting('test.mapping_wrong_sport')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'a pick mapping and player must match the draft sport'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_player_id => %L::uuid, p_mapping_id => %L::uuid
      )
    $$,
    current_setting('test.player_nonprimary'),
    current_setting('test.mapping_nonprimary')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'a non-primary provider mapping cannot identify a draft pick'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_player_id => %L::uuid, p_mapping_id => %L::uuid
      )
    $$,
    current_setting('test.player_a'),
    current_setting('test.mapping_removed')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'a removed provider mapping cannot identify an active draft pick'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100,
        p_player_id => %L::uuid,
        p_mapping_id => %L::uuid,
        p_removed_at => '2026-08-18 00:00:00+00'
      )
    $$,
    current_setting('test.player_a'),
    current_setting('test.mapping_removed')
  ),
  '23514',
  'The draft pick player mapping is inconsistent.',
  'removed pick history still requires its canonical provider mapping to remain active'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_picked_by => ' bad') $$,
  '23514', null,
  'picked-by source identifiers must be exact and trimmed'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_auction_amount => -1) $$,
  '23514', null,
  'auction value cannot be negative'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_auction_amount => 'NaN'::numeric) $$,
  '23514', null,
  'auction value rejects numeric NaN'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_auction_amount => 'Infinity'::numeric) $$,
  '23514', null,
  'auction value rejects positive infinity'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_auction_amount => '-Infinity'::numeric) $$,
  '23514', null,
  'auction value rejects negative infinity'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_entity_type => 'future') $$,
  '23514', null,
  'draft-time entity type is conservative and explicit'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_primary_position => 'qb') $$,
  '23514', null,
  'draft-time primary position is an exact uppercase token'
);
select throws_ok(
  $$
    select pg_temp.insert_shared_pick(
      100, p_fantasy_positions => array['QB','QB']
    )
  $$,
  '23514', null,
  'draft-time fantasy positions preserve exact unique array values'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100, p_source_metadata => '[]') $$,
  '23514', null,
  'pick source metadata must be a bounded object'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_roster_id => %L::uuid, p_external_roster_id => 1
      )
    $$,
    current_setting('test.roster_b')
  ),
  '23514',
  'The draft pick roster resolution is inconsistent.',
  'a pick cannot resolve to a roster in another league'
);
select throws_ok(
  format(
    $$
      select pg_temp.insert_shared_pick(
        100, p_roster_id => %L::uuid, p_external_roster_id => 2
      )
    $$,
    current_setting('test.roster_a')
  ),
  '23514',
  'The draft pick roster resolution is inconsistent.',
  'a pick roster must match the exact external roster ID'
);
select throws_ok(
  format(
    $$
      update public.draft_picks
      set player_display_name_at_draft = E'bad\nname'
      where draft_id = %L::uuid and pick_no = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'historical pick display context rejects control characters'
);
select throws_ok(
  format(
    $$
      update public.draft_picks
      set first_seen_at = '2026-08-18', last_seen_at = '2026-08-17'
      where draft_id = %L::uuid and pick_no = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'pick observation watermarks cannot regress'
);
select lives_ok(
  $$ select pg_temp.insert_shared_pick(100) $$,
  'mutable boards accept new picks'
);
select lives_ok(
  format(
    $$
      update public.draft_picks
      set source_metadata = '{"refreshed":true}', last_seen_at = now()
      where draft_id = %L::uuid and pick_no = 100
    $$,
    current_setting('test.draft_shared')
  ),
  'mutable board picks accept observation updates'
);
select lives_ok(
  format(
    $$
      update public.draft_picks set removed_at = now()
      where draft_id = %L::uuid and pick_no = 100
    $$,
    current_setting('test.draft_shared')
  ),
  'mutable board picks may be soft-removed'
);
select lives_ok(
  format(
    $$
      delete from public.draft_picks
      where draft_id = %L::uuid and pick_no = 100
    $$,
    current_setting('test.draft_shared')
  ),
  'mutable board picks may be deleted'
);

-- Monotonic board lifecycle and finalized immutability ----------------------

select throws_ok(
  format(
    $$
      update public.drafts set board_fetched_at = now()
      where id = %L::uuid
    $$,
    current_setting('test.draft_not_fetched')
  ),
  '23514', null,
  'not-fetched board state requires every board field to remain null'
);
select throws_ok(
  format(
    $$
      update public.drafts set board_state = 'mutable'
      where id = %L::uuid
    $$,
    current_setting('test.draft_not_fetched')
  ),
  '23514', null,
  'mutable board state requires one complete paired board watermark'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set board_state = 'mutable', board_fetched_at = '2026-08-17',
        board_slot_count = 0, board_pick_count = 0,
        board_fingerprint_version = 1, board_fingerprint = 'bad',
        contains_keeper_picks = false
      where id = %L::uuid
    $$,
    current_setting('test.draft_not_fetched')
  ),
  '23514', null,
  'board fingerprints are exact lowercase SHA-256 values'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set board_state = 'not_fetched', board_fetched_at = null,
        board_slot_count = null, board_pick_count = null,
        board_fingerprint_version = null, board_fingerprint = null,
        contains_keeper_picks = null
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A draft board cannot regress.',
  'a mutable board cannot regress to not-fetched'
);
select throws_ok(
  format(
    $$
      update public.drafts set board_fetched_at = '2026-08-15'
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A draft board observation cannot move backward.',
  'a mutable board watermark cannot move backward'
);
select throws_ok(
  format(
    $$
      update public.drafts set board_fingerprint = repeat('b',64)
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A changed mutable board requires a newer observation.',
  'a changed mutable board fingerprint requires a newer observation'
);
select lives_ok(
  format(
    $$
      update public.drafts
      set board_fetched_at = '2026-08-18', board_fingerprint = repeat('b',64)
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  'a changed mutable board is accepted under a newer complete observation'
);
select throws_ok(
  format(
    $$
      update public.draft_slots set removed_at = '2026-08-18'
      where draft_id = %L::uuid and draft_slot = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '23514',
  'An active draft relationship still references this slot.',
  'an active pick or confirmed participation prevents slot removal'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set board_state = 'finalized', board_slot_count = 99,
        board_pick_count = 3, board_finalized_at = '2026-08-18',
        contains_keeper_picks = true
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '23514',
  'The finalized draft board summary is inconsistent.',
  'finalization rejects an incorrect active slot count'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set board_state = 'finalized', board_slot_count = 2,
        board_pick_count = 99, board_finalized_at = '2026-08-18',
        contains_keeper_picks = true
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '23514',
  'The finalized draft board summary is inconsistent.',
  'finalization rejects an incorrect active pick count'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set board_state = 'finalized', board_slot_count = 2,
        board_pick_count = 3, board_finalized_at = '2026-08-18',
        contains_keeper_picks = false
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '23514',
  'The finalized draft board summary is inconsistent.',
  'finalization rejects an incorrect keeper summary'
);
select throws_ok(
  format(
    $$
      update public.drafts
      set status = 'in_progress', board_state = 'finalized',
        board_slot_count = 2, board_pick_count = 3,
        board_finalized_at = '2026-08-18', contains_keeper_picks = true
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'only a source-complete draft may finalize'
);
select lives_ok(
  format(
    $$
      update public.drafts
      set board_state = 'finalized', board_slot_count = 2,
        board_pick_count = 3, board_finalized_at = '2026-08-18',
        contains_keeper_picks = true
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  'a complete board finalizes when active slots, picks, and keeper truth match'
);
select results_eq(
  format(
    $$
      select board_state, board_slot_count, board_pick_count,
        contains_keeper_picks, board_finalized_at >= board_fetched_at
      from public.drafts where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  $$ values ('finalized'::text, 2, 3, true, true) $$,
  'finalized board state stores one internally consistent source-complete summary'
);

select throws_ok(
  format(
    $$
      insert into public.draft_slots (
        draft_id, draft_slot, fetched_at, first_seen_at, last_seen_at
      ) values (%L::uuid, 3, now(), now(), now())
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized slot insert is rejected'
);
select throws_ok(
  format(
    $$
      update public.draft_slots set source_metadata = '{"changed":true}'
      where draft_id = %L::uuid and draft_slot = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized slot update is rejected'
);
select throws_ok(
  format(
    $$
      delete from public.draft_slots
      where draft_id = %L::uuid and draft_slot = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized slot delete is rejected'
);
select throws_ok(
  $$ select pg_temp.insert_shared_pick(100) $$,
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized pick insert is rejected'
);
select throws_ok(
  format(
    $$
      update public.draft_picks set source_metadata = '{"changed":true}'
      where draft_id = %L::uuid and pick_no = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized pick update is rejected'
);
select throws_ok(
  format(
    $$
      delete from public.draft_picks
      where draft_id = %L::uuid and pick_no = 1
    $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'Draft children may change only while the board is mutable.',
  'finalized pick delete is rejected'
);
select throws_ok(
  format(
    $$ update public.drafts set board_state = 'mutable' where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft board is immutable.',
  'a finalized board cannot revert'
);
select throws_ok(
  format(
    $$ update public.drafts set board_fingerprint = repeat('c',64) where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft board is immutable.',
  'a finalized board fingerprint cannot change'
);
select throws_ok(
  format(
    $$ update public.drafts set board_pick_count = 4 where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft board is immutable.',
  'a finalized board count cannot change'
);
select throws_ok(
  format(
    $$ update public.drafts set source_draft_order = '{}' where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft board is immutable.',
  'a finalized exact source map cannot change'
);
select throws_ok(
  format(
    $$ update public.drafts set metadata = '{"changed":true}' where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft board is immutable.',
  'finalized raw source metadata cannot drift'
);
select throws_ok(
  format(
    $$ update public.drafts set team_count = 3 where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '23514', null,
  'a finalized typed environment cannot drift'
);
select lives_ok(
  format(
    $$
      update public.drafts set last_seen_at = '2026-08-20'
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  'documented finalized observation bookkeeping remains mutable'
);
select lives_ok(
  format(
    $$
      update public.drafts set removed_at = '2026-08-21'
      where id = %L::uuid
    $$,
    current_setting('test.draft_shared')
  ),
  'documented finalized soft-removal bookkeeping remains mutable'
);
select throws_ok(
  format(
    $$ delete from public.drafts where id = %L::uuid $$,
    current_setting('test.draft_shared')
  ),
  '55000',
  'A finalized draft cannot be deleted.',
  'a finalized canonical draft cannot be deleted'
);

select throws_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set participation_status = 'not_participant', draft_slot = null
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  '55000',
  'Finalized confirmed participation is immutable.',
  'finalized confirmed participation cannot become negative'
);
select throws_ok(
  format(
    $$
      update public.fantasy_account_drafts set draft_slot = 2
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  '55000',
  'Finalized confirmed participation is immutable.',
  'finalized confirmed participation cannot change slots'
);
select throws_ok(
  format(
    $$
      update public.fantasy_account_drafts set removed_at = '2026-08-21'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  '55000',
  'Finalized confirmed participation is immutable.',
  'finalized confirmed participation cannot be soft-removed'
);
select throws_ok(
  format(
    $$
      delete from public.fantasy_account_drafts
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  '55000',
  'Finalized confirmed participation is immutable.',
  'finalized confirmed participation cannot be deleted'
);
select lives_ok(
  format(
    $$
      update public.fantasy_account_drafts
      set source_metadata = '{"evidence":"combined","refreshed":true}',
        observed_at = '2026-08-20', last_seen_at = '2026-08-20'
      where fantasy_account_id = %L::uuid and draft_id = %L::uuid
    $$,
    current_setting('test.account_a'),
    current_setting('test.draft_shared')
  ),
  'same-slot finalized participation evidence may refresh'
);

select lives_ok(
  format(
    $$
      update public.drafts
      set board_state = 'finalized', board_fetched_at = '2026-09-02',
        board_slot_count = 0, board_pick_count = 0,
        board_fingerprint_version = 1, board_fingerprint = repeat('d',64),
        board_finalized_at = '2026-09-02', contains_keeper_picks = false
      where id = %L::uuid
    $$,
    current_setting('test.draft_partial')
  ),
  'a source-complete zero-pick board remains representable'
);

-- Synchronization scope remains independent and observable -----------------

insert into public.sync_runs (
  fantasy_account_id, triggered_by_user_id, provider, sport, season,
  scope, status, started_at
)
values (
  current_setting('test.account_a')::uuid,
  current_setting('test.user_a')::uuid,
  'sleeper', 'nfl', 2026, 'draft_sync', 'running', now()
);
select is(
  (
    select count(*)::integer
    from public.sync_runs
    where fantasy_account_id = current_setting('test.account_a')::uuid
      and scope = 'draft_sync' and status = 'running'
  ),
  1,
  'draft_sync is an accepted independent running scope'
);
select throws_ok(
  format(
    $$
      insert into public.sync_runs (
        fantasy_account_id, provider, sport, season, scope, status,
        started_at
      ) values (%L::uuid, 'sleeper', 'nfl', 2026, 'draft_sync',
        'running', now())
    $$,
    current_setting('test.account_a')
  ),
  '23505', null,
  'one account has at most one running draft synchronization'
);
select lives_ok(
  format(
    $$
      insert into public.sync_runs (
        fantasy_account_id, provider, sport, season, scope, status,
        started_at
      ) values (%L::uuid, 'sleeper', 'nfl', 2026, 'draft_sync',
        'running', now())
    $$,
    current_setting('test.account_b')
  ),
  'different accounts may each run draft synchronization'
);
select lives_ok(
  format(
    $$
      insert into public.sync_runs (
        fantasy_account_id, provider, sport, season, scope, status,
        started_at, finished_at
      ) values
        (%L::uuid, 'sleeper', 'nfl', 2026, 'league_discovery',
          'succeeded', now(), now()),
        (%L::uuid, 'sleeper', 'nfl', 2026, 'roster_sync',
          'succeeded', now(), now())
    $$,
    current_setting('test.account_c'),
    current_setting('test.account_c')
  ),
  'league discovery and roster synchronization remain accepted scopes'
);
select throws_ok(
  format(
    $$
      insert into public.sync_runs (
        fantasy_account_id, provider, sport, season, scope, status,
        started_at
      ) values (%L::uuid, 'sleeper', 'nfl', 2026, 'full_sync',
        'running', now())
    $$,
    current_setting('test.account_c')
  ),
  '23514', null,
  'unsupported generic synchronization scopes remain rejected'
);
select has_index(
  'public', 'sync_runs',
  'sync_runs_one_running_league_discovery_per_account_idx',
  'league discovery retains its independent running-account guard'
);
select has_index(
  'public', 'sync_runs',
  'sync_runs_one_running_roster_sync_per_account_idx',
  'roster synchronization retains its independent running-account guard'
);
select has_index(
  'public', 'sync_runs',
  'sync_runs_one_running_draft_sync_per_account_idx',
  'draft synchronization has its own running-account guard'
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
  ) like '%roster_sync%'
  and pg_get_constraintdef(
    (
      select oid from pg_constraint
      where conrelid = 'public.sync_runs'::regclass
        and conname = 'sync_runs_scope_is_known'
    )
  ) like '%draft_sync%'
  and pg_get_constraintdef(
    (
      select oid from pg_constraint
      where conrelid = 'public.sync_runs'::regclass
        and conname = 'sync_runs_scope_is_known'
    )
  ) not like '%full_sync%',
  'sync scope is restricted to the three implemented independent operations'
);

-- Browser RLS and exact safe projections ------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.user_a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$
    select
      (select count(fantasy_account_id)::integer
       from public.fantasy_account_draft_collections),
      (select count(id)::integer from public.fantasy_account_drafts),
      (select count(id)::integer from public.drafts),
      (select count(id)::integer from public.draft_slots),
      (select count(id)::integer from public.draft_picks)
  $$,
  $$ values (3, 3, 1, 2, 3) $$,
  'User A sees only tracked-account collections and participation plus the complete confirmed shared board'
);
select results_eq(
  format(
    $$
      select
        (select count(id)::integer from public.drafts
         where id = %L::uuid),
        (select count(id)::integer from public.draft_slots
         where draft_id = %L::uuid),
        (select count(id)::integer from public.draft_picks
         where draft_id = %L::uuid)
    $$,
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated')
  ),
  $$ values (0, 0, 0) $$,
  'unresolved participation exposes no shared draft, slot, or pick'
);

reset role;
update public.fantasy_account_drafts
set participation_status = 'not_participant', draft_slot = null,
  observed_at = '2026-08-20 00:00:00+00',
  last_seen_at = '2026-08-20 00:00:00+00'
where fantasy_account_id = current_setting('test.account_b')::uuid
  and draft_id = current_setting('test.draft_unrelated')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.user_a'), true);
select results_eq(
  format(
    $$
      select
        (select count(id)::integer from public.drafts
         where id = %L::uuid),
        (select count(id)::integer from public.draft_slots
         where draft_id = %L::uuid),
        (select count(id)::integer from public.draft_picks
         where draft_id = %L::uuid)
    $$,
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated')
  ),
  $$ values (0, 0, 0) $$,
  'explicit not-participant truth exposes no shared draft, slot, or pick'
);

reset role;
update public.fantasy_account_drafts
set participation_status = 'confirmed', draft_slot = 1,
  observed_at = '2026-08-21 00:00:00+00',
  last_seen_at = '2026-08-21 00:00:00+00',
  removed_at = '2026-08-21 00:00:00+00'
where fantasy_account_id = current_setting('test.account_b')::uuid
  and draft_id = current_setting('test.draft_unrelated')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.user_a'), true);
select results_eq(
  format(
    $$
      select
        (select count(id)::integer from public.drafts
         where id = %L::uuid),
        (select count(id)::integer from public.draft_slots
         where draft_id = %L::uuid),
        (select count(id)::integer from public.draft_picks
         where draft_id = %L::uuid)
    $$,
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated'),
    current_setting('test.draft_unrelated')
  ),
  $$ values (0, 0, 0) $$,
  'removed confirmed participation exposes no shared draft, slot, or pick'
);
select lives_ok(
  $$
    select fantasy_account_id, sport, season, source_fetched_at,
      source_draft_count, collection_fingerprint, created_at, updated_at
    from public.fantasy_account_draft_collections
  $$,
  'authenticated account-collection safe projection succeeds'
);
select lives_ok(
  $$
    select id, fantasy_account_id, draft_id, participation_status,
      draft_slot, observed_at, first_seen_at, last_seen_at, removed_at,
      created_at, updated_at
    from public.fantasy_account_drafts
  $$,
  'authenticated participation safe projection succeeds'
);
select lives_ok(
  $$
    select id, provider, external_draft_id, context_type, league_id,
      sport, season, season_type, draft_type, draft_type_family, status,
      name, description, team_count, round_count, pick_timer_seconds,
      start_time, provider_created_at, last_picked_at,
      league_format_context_id, context_resolution_status,
      context_observed_at, draft_environment_version,
      draft_settings_fingerprint, draft_environment_fingerprint,
      draft_environment_compatibility_key, draft_environment_quality,
      draft_pool_type, capital_type, settings, draft_fetched_at,
      first_seen_at, last_seen_at, removed_at, board_state,
      board_fetched_at, board_slot_count, board_pick_count,
      board_fingerprint_version, board_fingerprint, board_finalized_at,
      contains_keeper_picks, created_at, updated_at
    from public.drafts
  $$,
  'authenticated draft safe projection succeeds'
);
select lives_ok(
  $$
    select id, draft_id, draft_slot, roster_id, fetched_at, first_seen_at,
      last_seen_at, removed_at, created_at, updated_at
    from public.draft_slots
  $$,
  'authenticated slot safe projection succeeds'
);
select lives_ok(
  $$
    select id, draft_id, draft_slot, pick_no, round, player_id,
      source_player_external_id_id, roster_id, is_keeper, auction_amount,
      picked_at, player_display_name_at_draft,
      player_entity_type_at_draft, player_primary_position_at_draft,
      player_fantasy_positions_at_draft, nfl_team_at_draft,
      player_status_at_draft, injury_status_at_draft, source_fetched_at,
      first_seen_at, last_seen_at, removed_at, created_at, updated_at
    from public.draft_picks
  $$,
  'authenticated pick safe projection succeeds'
);
select lives_ok(
  $$
    select id, fantasy_account_id, provider, sport, season, scope, status,
      progress_current, progress_total, result_counts, error_summary,
      started_at, finished_at, created_at, updated_at
    from public.sync_runs where scope = 'draft_sync'
  $$,
  'authenticated users retain the safe sync-run projection for draft_sync'
);
select throws_ok(
  $$ select triggered_by_user_id from public.sync_runs $$,
  '42501', null,
  'the triggering Auth UUID remains browser-inaccessible'
);

select throws_ok(
  $$ select source_metadata from public.fantasy_account_draft_collections $$,
  '42501', null, 'account collection source metadata is private'
);
select throws_ok(
  $$ select source_metadata from public.fantasy_account_drafts $$,
  '42501', null, 'participation evidence metadata is private'
);
select throws_ok(
  $$ select last_message_id from public.drafts $$,
  '42501', null, 'draft source message identity is private'
);
select throws_ok(
  $$ select source_creators from public.drafts $$,
  '42501', null, 'draft creator IDs are private'
);
select throws_ok(
  $$ select source_draft_order from public.drafts $$,
  '42501', null, 'draft-order participant map is private'
);
select throws_ok(
  $$ select source_slot_to_roster_id from public.drafts $$,
  '42501', null, 'source slot-to-roster map is private'
);
select throws_ok(
  $$ select metadata from public.drafts $$,
  '42501', null, 'raw draft source metadata is private'
);
select throws_ok(
  $$ select context_metadata from public.drafts $$,
  '42501', null, 'raw draft context evidence is private'
);
select throws_ok(
  $$ select source_user_ids from public.draft_slots $$,
  '42501', null, 'normalized source participant IDs are private'
);
select throws_ok(
  $$ select external_roster_id from public.draft_slots $$,
  '42501', null, 'slot source roster identity is private'
);
select throws_ok(
  $$ select source_metadata from public.draft_slots $$,
  '42501', null, 'slot source metadata is private'
);
select throws_ok(
  $$ select picked_by_external_user_id from public.draft_picks $$,
  '42501', null, 'pick attribution source identity is private'
);
select throws_ok(
  $$ select external_roster_id from public.draft_picks $$,
  '42501', null, 'pick source roster identity is private'
);
select throws_ok(
  $$ select source_player_metadata from public.draft_picks $$,
  '42501', null, 'raw source player-at-draft metadata is private'
);
select throws_ok(
  $$ select source_metadata from public.draft_picks $$,
  '42501', null, 'raw pick source metadata is private'
);
select throws_ok(
  $$
    insert into public.fantasy_account_draft_collections (
      fantasy_account_id, sport, season, source_fetched_at,
      source_draft_count, collection_fingerprint
    ) values (gen_random_uuid(), 'nfl', 2026, now(), 0, repeat('1',64))
  $$,
  '42501', null,
  'authenticated browsers cannot insert provider draft data'
);
select throws_ok(
  $$ update public.drafts set last_seen_at = now() $$,
  '42501', null,
  'authenticated browsers cannot update shared draft data'
);
select throws_ok(
  $$ delete from public.draft_picks $$,
  '42501', null,
  'authenticated browsers cannot delete draft picks'
);

reset role;
update public.fantasy_account_leagues
set removed_at = '2026-08-22'
where fantasy_account_id = current_setting('test.account_a')::uuid
  and league_id = current_setting('test.league_a')::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.user_a'), true);
select is(
  (select count(id)::integer from public.drafts),
  1,
  'explicit draft participation preserves historical visibility after current league discovery removal'
);

select set_config('request.jwt.claim.sub', current_setting('test.user_b'), true);
select results_eq(
  $$
    select
      (select count(fantasy_account_id)::integer
       from public.fantasy_account_draft_collections),
      (select count(id)::integer from public.fantasy_account_drafts),
      (select count(id)::integer from public.drafts),
      (select count(id)::integer from public.draft_slots),
      (select count(id)::integer from public.draft_picks)
  $$,
  $$ values (2, 1, 1, 2, 3) $$,
  'User B tracking the same canonical account sees the same participation and complete board'
);

select set_config('request.jwt.claim.sub', current_setting('test.user_c'), true);
select results_eq(
  $$
    select
      (select count(fantasy_account_id)::integer
       from public.fantasy_account_draft_collections),
      (select count(id)::integer from public.fantasy_account_drafts),
      (select count(id)::integer from public.drafts),
      (select count(id)::integer from public.draft_slots),
      (select count(id)::integer from public.draft_picks)
  $$,
  $$ values (1, 1, 1, 1, 1) $$,
  'User C sees only its unrelated account collection, participation, draft, slot, and pick'
);

reset role;
set local role anon;
select throws_ok(
  $$ select fantasy_account_id from public.fantasy_account_draft_collections $$,
  '42501', null, 'anon cannot read account draft collections'
);
select throws_ok(
  $$ select id from public.fantasy_account_drafts $$,
  '42501', null, 'anon cannot read draft participation'
);
select throws_ok(
  $$ select id from public.drafts $$,
  '42501', null, 'anon cannot read drafts'
);
select throws_ok(
  $$ select id from public.draft_slots $$,
  '42501', null, 'anon cannot read draft slots'
);
select throws_ok(
  $$ select id from public.draft_picks $$,
  '42501', null, 'anon cannot read draft picks'
);

reset role;
set local role service_role;
select throws_ok(
  $$ select id from public.drafts $$,
  '42501', null, 'service_role cannot directly read shared drafts'
);
select throws_ok(
  $$ select id from public.draft_slots $$,
  '42501', null, 'service_role cannot directly read draft slots'
);
select throws_ok(
  $$ select id from public.fantasy_account_drafts $$,
  '42501', null, 'service_role cannot directly read participation'
);
select throws_ok(
  $$ select id from public.draft_picks $$,
  '42501', null, 'service_role cannot directly read draft picks'
);
select throws_ok(
  $$ select fantasy_account_id from public.fantasy_account_draft_collections $$,
  '42501', null, 'service_role cannot directly read account collections'
);
select throws_ok(
  $$
    insert into public.drafts (
      provider, external_draft_id, context_type, sport, season,
      season_type, draft_type, draft_type_family, status,
      context_resolution_status, draft_environment_version,
      draft_settings_fingerprint, draft_environment_fingerprint,
      draft_environment_compatibility_key, draft_environment_quality,
      draft_pool_type, capital_type, draft_fetched_at, first_seen_at,
      last_seen_at
    ) values (
      'sleeper','blocked','standalone','nfl',2026,'regular','snake',
      'snake','pre_draft','unknown',1,repeat('1',64),repeat('2',64),
      repeat('3',64),'unknown','unknown','overall_pick',now(),now(),now()
    )
  $$,
  '42501', null,
  'service_role cannot directly insert draft data'
);
select throws_ok(
  $$ update public.drafts set last_seen_at = now() $$,
  '42501', null,
  'service_role cannot directly update draft data'
);
select throws_ok(
  $$ delete from public.draft_picks $$,
  '42501', null,
  'service_role cannot directly delete draft data'
);

reset role;

-- Existing-domain regressions and deferred scope ----------------------------

select throws_ok(
  format(
    $$ update public.league_format_contexts set context_quality = 'partial' where id = %L::uuid $$,
    current_setting('test.format_context')
  ),
  '55000',
  'Scoring and league format contexts are immutable.',
  'league format contexts remain immutable'
);
select throws_ok(
  format(
    $$ delete from public.league_format_contexts where id = %L::uuid $$,
    current_setting('test.format_context')
  ),
  '55000',
  'Scoring and league format contexts are immutable.',
  'league format contexts remain deletion-protected'
);
select throws_ok(
  format(
    $$
      update public.scoring_contexts set broad_scoring_format = 'custom'
      where id = (
        select scoring_context_id from public.league_format_contexts
        where id = %L::uuid
      )
    $$,
    current_setting('test.format_context')
  ),
  '55000',
  'Scoring and league format contexts are immutable.',
  'scoring contexts remain immutable'
);
select throws_ok(
  format(
    $$
      delete from public.scoring_contexts where id = (
        select scoring_context_id from public.league_format_contexts
        where id = %L::uuid
      )
    $$,
    current_setting('test.format_context')
  ),
  '55000',
  'Scoring and league format contexts are immutable.',
  'scoring contexts remain deletion-protected'
);
select is(
  (
    select count(*)::integer
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'league_users', 'rosters', 'fantasy_account_rosters',
        'roster_players'
      )
  ),
  4,
  'the existing roster domain remains intact'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.draft_picks'::regclass
      and conname = 'draft_picks_mapping_player_fkey'
      and contype = 'f'
  ),
  'draft picks retain composite canonical player-mapping identity'
);
select is(
  (
    select count(*)::integer
    from information_schema.tables
    where table_schema = 'public'
      and (
        table_name like '%traded_pick%'
        or table_name like '%transaction%'
        or table_name like '%matchup%'
        or table_name like '%statistics%'
        or table_name like '%ranking%'
        or table_name like '%adp%'
        or table_name like '%market%'
      )
  ),
  0,
  'traded-pick, transaction, matchup, statistics, ranking, ADP, and market tables remain deferred'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public' and table_name = 'players'
      and column_name in (
        'adp', 'average_draft_position', 'positional_adp_rank',
        'market_value', 'fantasy_rank', 'draft_capital'
      )
  ),
  0,
  'no global player ADP, ranking, value, or draft-capital field is introduced'
);
select ok(
  not exists (
    select 1 from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in (
        'start_sleeper_draft_sync', 'stage_sleeper_draft',
        'complete_sleeper_draft_sync', 'fail_sleeper_draft_sync'
      )
  ),
  'Task 008A.2 adds no public draft-import lifecycle RPC'
);
select ok(
  not exists (
    select 1
    from pg_class as relation
    join pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'app_private'
      and relation.relname like '%draft%stage%'
  ),
  'Task 008A.2 adds no private draft staging relation'
);
select ok(
  not exists (
    select 1
    from last_synced_before as baseline
    join public.fantasy_accounts as account on account.id = baseline.id
    where account.last_synced_at is distinct from baseline.last_synced_at
  )
  and not exists (
    select 1 from public.fantasy_accounts
    where id in (
      current_setting('test.account_a')::uuid,
      current_setting('test.account_b')::uuid,
      current_setting('test.account_c')::uuid
    )
      and last_synced_at is not null
  ),
  'draft architecture never advances fantasy_accounts.last_synced_at'
);

select * from finish();
rollback;
