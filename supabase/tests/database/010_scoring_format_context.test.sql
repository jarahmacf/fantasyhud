begin;

select plan(167);

-- Preserve populated hosted state as well as clean-reset state. The final
-- regression assertions compare these provider-domain counts after every
-- context helper and discovery fixture has run.
create temporary table task008_domain_counts_before as
select
  (select count(*)::integer from public.rosters) as rosters,
  (
    select count(*)::integer
    from public.fantasy_account_rosters
  ) as fantasy_account_rosters,
  (select count(*)::integer from public.roster_players) as roster_players;

-- Deterministic, owner-only identity helpers.
select has_function(
  'app_private', 'context_sha256', array['text', 'integer', 'jsonb'],
  'canonical JSON context fingerprint helper exists'
);
select has_function(
  'app_private', 'context_text_array_sha256',
  array['text', 'integer', 'text[]'],
  'ordered text-array context fingerprint helper exists'
);
select has_function(
  'app_private', 'sleeper_effective_scoring_v1', array['jsonb'],
  'version-one effective Sleeper scoring projection exists'
);
select has_function(
  'app_private', 'league_format_fingerprint',
  array[
    'integer', 'text', 'text', 'text', 'text', 'text[]', 'integer',
    'integer', 'text', 'boolean', 'boolean', 'boolean'
  ],
  'combined league-format fingerprint helper exists'
);
select has_function(
  'app_private', 'classify_sleeper_scoring_settings', array['jsonb'],
  'version-one Sleeper scoring classifier exists'
);
select has_function(
  'app_private', 'classify_sleeper_league_format_v1',
  array[
    'text', 'text[]', 'jsonb', 'integer', 'integer', 'text', 'boolean',
    'boolean', 'boolean'
  ],
  'shared version-one Sleeper league-format classifier exists'
);
select has_function(
  'app_private', 'exact_roster_positions_are_safe', array['text[]'],
  'exact roster-position constraint helper exists'
);
select has_function(
  'app_private', 'lineup_profile_is_safe', array['jsonb'],
  'bounded lineup-profile constraint helper exists'
);
select has_function(
  'app_private', 'ensure_sleeper_league_format_context',
  array[
    'text', 'text', 'jsonb', 'jsonb', 'jsonb', 'integer', 'integer', 'text',
    'boolean', 'boolean', 'boolean'
  ],
  'owner-only context ensure helper exists'
);

select is(
  (
    select count(*)::integer
    from (values
      ('app_private.context_sha256(text,integer,jsonb)'::regprocedure),
      ('app_private.context_text_array_sha256(text,integer,text[])'::regprocedure),
      ('app_private.sleeper_effective_scoring_v1(jsonb)'::regprocedure),
      ('app_private.league_format_fingerprint(integer,text,text,text,text,text[],integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.classify_sleeper_scoring_settings(jsonb)'::regprocedure),
      ('app_private.classify_sleeper_league_format_v1(text,text[],jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.exact_roster_positions_are_safe(text[])'::regprocedure),
      ('app_private.lineup_profile_is_safe(jsonb)'::regprocedure)
    ) as expected(procedure_oid)
    inner join pg_catalog.pg_proc as procedure
      on procedure.oid = expected.procedure_oid
    where procedure.provolatile = 'i'
  ),
  8,
  'all deterministic classification and fingerprint helpers are immutable'
);
select is(
  (
    select count(*)::integer
    from (values
      ('app_private.context_sha256(text,integer,jsonb)'::regprocedure),
      ('app_private.context_text_array_sha256(text,integer,text[])'::regprocedure),
      ('app_private.sleeper_effective_scoring_v1(jsonb)'::regprocedure),
      ('app_private.league_format_fingerprint(integer,text,text,text,text,text[],integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.classify_sleeper_scoring_settings(jsonb)'::regprocedure),
      ('app_private.classify_sleeper_league_format_v1(text,text[],jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.exact_roster_positions_are_safe(text[])'::regprocedure),
      ('app_private.lineup_profile_is_safe(jsonb)'::regprocedure),
      ('app_private.ensure_sleeper_league_format_context(text,text,jsonb,jsonb,jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure)
    ) as expected(procedure_oid)
    inner join pg_catalog.pg_proc as procedure
      on procedure.oid = expected.procedure_oid
    where procedure.proconfig @> array['search_path=pg_catalog']
  ),
  9,
  'all context helpers fix search_path to pg_catalog'
);
select is(
  (
    select count(*)::integer
    from (values
      ('app_private.context_sha256(text,integer,jsonb)'::regprocedure),
      ('app_private.context_text_array_sha256(text,integer,text[])'::regprocedure),
      ('app_private.sleeper_effective_scoring_v1(jsonb)'::regprocedure),
      ('app_private.league_format_fingerprint(integer,text,text,text,text,text[],integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.classify_sleeper_scoring_settings(jsonb)'::regprocedure),
      ('app_private.classify_sleeper_league_format_v1(text,text[],jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.exact_roster_positions_are_safe(text[])'::regprocedure),
      ('app_private.lineup_profile_is_safe(jsonb)'::regprocedure),
      ('app_private.ensure_sleeper_league_format_context(text,text,jsonb,jsonb,jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure)
    ) as expected(procedure_oid)
    cross join (values ('anon'), ('authenticated'), ('service_role')) as denied(role_name)
    where pg_catalog.has_function_privilege(
      denied.role_name,
      expected.procedure_oid,
      'execute'
    )
  ),
  0,
  'browser and service roles cannot execute owner-only context helpers'
);
select is(
  (
    select count(*)::integer
    from (values
      ('app_private.context_sha256(text,integer,jsonb)'::regprocedure),
      ('app_private.context_text_array_sha256(text,integer,text[])'::regprocedure),
      ('app_private.sleeper_effective_scoring_v1(jsonb)'::regprocedure),
      ('app_private.league_format_fingerprint(integer,text,text,text,text,text[],integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.classify_sleeper_scoring_settings(jsonb)'::regprocedure),
      ('app_private.classify_sleeper_league_format_v1(text,text[],jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure),
      ('app_private.exact_roster_positions_are_safe(text[])'::regprocedure),
      ('app_private.lineup_profile_is_safe(jsonb)'::regprocedure),
      ('app_private.ensure_sleeper_league_format_context(text,text,jsonb,jsonb,jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure)
    ) as expected(procedure_oid)
    where pg_catalog.has_function_privilege(
      'postgres',
      expected.procedure_oid,
      'execute'
    )
  ),
  9,
  'the migration owner can execute every context helper'
);
select ok(
  (
    select procedure.prosecdef
    from pg_catalog.pg_proc as procedure
    where procedure.oid =
      'app_private.ensure_sleeper_league_format_context(text,text,jsonb,jsonb,jsonb,integer,integer,text,boolean,boolean,boolean)'::regprocedure
  ),
  'the context ensure boundary is SECURITY DEFINER'
);

select ok(
  app_private.context_sha256(
    'fixture', 1, '{"b":2,"a":1}'::jsonb
  ) ~ '^[0-9a-f]{64}$',
  'the canonical JSON fingerprint is lowercase SHA-256'
);
select is(
  app_private.context_sha256(
    'fixture', 1, '{"b":2,"a":1}'::jsonb
  ),
  '40c1caa84b1ef398f6445cffda30f04359fdaa37cb06ba3653437edb287fd651',
  'canonical JSON fingerprint matches the reviewed byte-for-byte vector'
);
select is(
  app_private.context_sha256(
    'fixture', 1, '{"b":2,"a":1}'::jsonb
  ),
  app_private.context_sha256(
    'fixture', 1, '{"a":1,"b":2}'::jsonb
  ),
  'JSON object key order does not alter exact identity'
);
select isnt(
  app_private.context_sha256('fixture', 1, '{"a":1}'::jsonb),
  app_private.context_sha256('other', 1, '{"a":1}'::jsonb),
  'the namespace participates in exact identity'
);
select isnt(
  app_private.context_sha256('fixture', 1, '{"a":1}'::jsonb),
  app_private.context_sha256('fixture', 2, '{"a":1}'::jsonb),
  'the normalization version participates in exact identity'
);
select ok(
  app_private.context_text_array_sha256(
    'lineup:sleeper:nfl', 1, array['QB', 'RB', 'WR']
  ) ~ '^[0-9a-f]{64}$',
  'the ordered-array fingerprint is lowercase SHA-256'
);
select is(
  app_private.context_text_array_sha256(
    'lineup:sleeper:nfl', 1, array['QB', 'RB', 'WR']
  ),
  '651708cbf8ce36f16b1141e62ada3a856e21e6b8b4637c55ced059df5e16d8c2',
  'ordered-array fingerprint matches the reviewed byte-for-byte vector'
);
select isnt(
  app_private.context_text_array_sha256(
    'lineup:sleeper:nfl', 1, array['QB', 'RB', 'WR']
  ),
  app_private.context_text_array_sha256(
    'lineup:sleeper:nfl', 1, array['RB', 'QB', 'WR']
  ),
  'roster-position order changes the lineup fingerprint'
);
select ok(
  app_private.league_format_fingerprint(
    1,
    'sleeper',
    'nfl',
    app_private.context_sha256(
      'scoring_context:sleeper:nfl', 1, '{"rec":1,"pass_td":4}'::jsonb
    ),
    app_private.context_sha256(
      'league_settings:sleeper:nfl', 1, '{"type":0,"best_ball":0}'::jsonb
    ),
    array['QB', 'RB', 'WR'],
    12,
    3,
    'redraft',
    false,
    false,
    false
  ) ~ '^[0-9a-f]{64}$',
  'the combined league-format fingerprint is lowercase SHA-256'
);
select is(
  app_private.league_format_fingerprint(
    1,
    'sleeper',
    'nfl',
    '99d325ec145f03c4f12ce4edd30491a165d305517129a91e6476052ee733371c',
    'b09872d9ca06e2dc5a71c6da7ab71bb8f11e80a57bdfb46becd01f0adb8e58dd',
    array['QB', 'RB', 'WR'],
    12,
    3,
    'redraft',
    false,
    false,
    false
  ),
  'c853bfdc0171b4a51ea15dbeed438bbbce7aae705827f39489840241b96190a6',
  'combined format fingerprint matches the reviewed byte-for-byte vector'
);
select isnt(
  app_private.league_format_fingerprint(
    1, 'sleeper', 'nfl',
    app_private.context_sha256(
      'scoring_context:sleeper:nfl', 1, '{"rec":1,"pass_td":4}'::jsonb
    ),
    app_private.context_sha256(
      'league_settings:sleeper:nfl', 1, '{"type":0,"best_ball":0}'::jsonb
    ),
    array['QB', 'RB', 'WR'], 12, 3, 'redraft', false, false, false
  ),
  app_private.league_format_fingerprint(
    1, 'sleeper', 'nfl',
    app_private.context_sha256(
      'scoring_context:sleeper:nfl', 1, '{"rec":1,"pass_td":4}'::jsonb
    ),
    app_private.context_sha256(
      'league_settings:sleeper:nfl', 1, '{"type":0,"best_ball":0}'::jsonb
    ),
    array['QB', 'RB', 'WR'], 10, 3, 'redraft', false, false, false
  ),
  'every combined dimension, including team count, participates in identity'
);
select throws_ok(
  $$ select app_private.context_sha256('fixture', 1, '[]'::jsonb) $$,
  '22023',
  'The context fingerprint input is invalid.',
  'non-object JSON fingerprint input fails closed'
);
select throws_ok(
  $$ select app_private.context_sha256(' fixture', 1, '{}'::jsonb) $$,
  '22023',
  'The context fingerprint input is invalid.',
  'non-canonical fingerprint namespace fails closed'
);
select throws_ok(
  $$
    select app_private.context_text_array_sha256(
      'fixture', 1, array['QB', null]::text[]
    )
  $$,
  '22023',
  'The context array fingerprint input is invalid.',
  'null array elements fail closed'
);
select throws_ok(
  $$
    select app_private.league_format_fingerprint(
      1, 'sleeper', 'nfl', repeat('a', 64),
      repeat('b', 64),
      array['QB', 'RB'], 12, 3, 'redraft', false, false, false
    )
  $$,
  '22023',
  'The league format fingerprint input is invalid.',
  'inconsistent roster size fails closed'
);

-- Public immutable context storage and history.
select has_table(
  'public', 'scoring_contexts',
  'scoring contexts table exists'
);
select ok(
  (
    select class.relrowsecurity
    from pg_catalog.pg_class as class
    where class.oid = 'public.scoring_contexts'::regclass
  ),
  'scoring contexts have RLS enabled'
);
select set_eq(
  $$
    select column_name::text
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'scoring_contexts'
  $$,
  $$ values
    ('id'::text),
    ('provider'::text),
    ('sport'::text),
    ('normalization_version'::text),
    ('scoring_fingerprint'::text),
    ('exact_scoring_settings'::text),
    ('broad_scoring_format'::text),
    ('reception_points'::text),
    ('passing_touchdown_points'::text),
    ('tight_end_reception_bonus'::text),
    ('has_position_specific_reception'::text),
    ('has_bonus_scoring'::text),
    ('has_idp_scoring'::text),
    ('compatibility_key'::text),
    ('derived_dimensions'::text),
    ('created_at'::text)
  $$,
  'scoring contexts expose exactly the reviewed columns'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.scoring_contexts'::regclass
      and constraint_record.contype = 'u'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (provider, sport, normalization_version, scoring_fingerprint)'
  ),
  'scoring exact identity has the required unique constraint'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'scoring_contexts'
      and indexdef like '%(provider, sport, broad_scoring_format)%'
  ),
  'broad scoring lookup has a supporting index'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'scoring_contexts'
      and indexdef like '%(provider, sport, normalization_version, compatibility_key)%'
  ),
  'scoring compatibility lookup has a supporting index'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_index as index_record
    inner join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = index_record.indrelid
      and attribute.attnum = any(index_record.indkey)
    where index_record.indrelid = 'public.scoring_contexts'::regclass
      and index_record.indisunique
      and attribute.attname = 'compatibility_key'
  ),
  'scoring compatibility key is not unique identity'
);

select has_table(
  'public', 'league_format_contexts',
  'league format contexts table exists'
);
select ok(
  (
    select class.relrowsecurity
    from pg_catalog.pg_class as class
    where class.oid = 'public.league_format_contexts'::regclass
  ),
  'league format contexts have RLS enabled'
);
select set_eq(
  $$
    select column_name::text
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'league_format_contexts'
  $$,
  $$ values
    ('id'::text),
    ('provider'::text),
    ('sport'::text),
    ('normalization_version'::text),
    ('scoring_context_id'::text),
    ('format_fingerprint'::text),
    ('lineup_fingerprint'::text),
    ('league_settings_fingerprint'::text),
    ('lineup_profile_fingerprint'::text),
    ('lineup_profile'::text),
    ('exact_roster_positions'::text),
    ('exact_league_settings'::text),
    ('team_count'::text),
    ('roster_size'::text),
    ('roster_management_type'::text),
    ('is_best_ball'::text),
    ('has_superflex'::text),
    ('has_idp'::text),
    ('quarterback_format'::text),
    ('compatibility_key'::text),
    ('context_quality'::text),
    ('derived_dimensions'::text),
    ('created_at'::text)
  $$,
  'league format contexts expose exactly the reviewed columns'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.league_format_contexts'::regclass
      and constraint_record.contype = 'u'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (provider, sport, normalization_version, format_fingerprint)'
  ),
  'league-format exact identity has the required unique constraint'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.league_format_contexts'::regclass
      and constraint_record.conname = 'league_format_contexts_quality_is_known'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like
        '%context_quality%exact%partial%unknown%'
  ),
  'exact, partial, and unknown context quality are representable'
);
select has_column(
  'public', 'leagues', 'current_format_context_id',
  'leagues expose the current immutable format-context pointer'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.leagues'::regclass
      and constraint_record.contype = 'f'
      and constraint_record.confrelid =
        'public.league_format_contexts'::regclass
      and constraint_record.confdeltype = 'r'
  ),
  'the current league pointer restricts format-context deletion'
);

select has_table(
  'public', 'league_format_observations',
  'append-only league format observations table exists'
);
select ok(
  (
    select class.relrowsecurity
    from pg_catalog.pg_class as class
    where class.oid = 'public.league_format_observations'::regclass
  ),
  'league format observations have RLS enabled'
);
select set_eq(
  $$
    select column_name::text
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'league_format_observations'
  $$,
  $$ values
    ('id'::text),
    ('league_id'::text),
    ('format_context_id'::text),
    ('observed_at'::text),
    ('source'::text),
    ('normalization_version'::text),
    ('created_at'::text)
  $$,
  'format observations expose exactly the reviewed columns'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid =
      'public.league_format_observations'::regclass
      and constraint_record.contype = 'u'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (league_id, observed_at)'
  ),
  'one league observation timestamp accepts at most one format context'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid =
      'public.league_format_observations'::regclass
      and constraint_record.conname =
        'league_format_observations_source_is_known'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like
        '%league_discovery%migration_backfill%'
  ),
  'observations distinguish discovery from migration backfill'
);
select ok(
  not exists (
    select 1
    from public.leagues as league
    where league.current_format_context_id is null
  ),
  'migration backfill assigns every pre-existing league a current context'
);

select has_function(
  'public', 'complete_sleeper_league_discovery',
  array['uuid', 'uuid', 'uuid', 'jsonb', 'jsonb'],
  'league discovery completion retains its public signature'
);
select ok(
  (
    select procedure.prosecdef
    from pg_catalog.pg_proc as procedure
    where procedure.oid =
      'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure
  ),
  'league discovery completion remains SECURITY DEFINER'
);
select ok(
  (
    select procedure.proconfig @> array['search_path=pg_catalog']
    from pg_catalog.pg_proc as procedure
    where procedure.oid =
      'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure
  ),
  'league discovery completion fixes search_path'
);
select ok(
  (
    select procedure.proconfig @> array['statement_timeout=60s']
    from pg_catalog.pg_proc as procedure
    where procedure.oid =
      'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure
  ),
  'league discovery completion has the reviewed 60-second timeout'
);
select is(
  has_function_privilege(
    'service_role',
    'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)',
    'execute'
  ),
  true,
  'service role retains execute-only discovery access'
);
select is(
  (
    select count(*)::integer
    from (values ('PUBLIC'), ('anon'), ('authenticated')) as denied(role_name)
    where case
      when denied.role_name = 'PUBLIC' then exists (
        select 1
        from pg_catalog.pg_proc as procedure
        cross join lateral pg_catalog.aclexplode(procedure.proacl) as acl
        where procedure.oid =
          'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
      else has_function_privilege(
        denied.role_name,
        'public.complete_sleeper_league_discovery(uuid,uuid,uuid,jsonb,jsonb)',
        'execute'
      )
    end
  ),
  0,
  'PUBLIC and browser roles cannot execute discovery completion'
);

-- Version-one scoring classification is deterministic and conservative.
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      passing_touchdown_points, tight_end_reception_bonus,
      has_position_specific_reception, has_bonus_scoring,
      has_idp_scoring
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4}'::jsonb
    )
  $$,
  $$ values (
    'ppr'::text, 1::numeric, 4::numeric, null::numeric,
    false, false, false
  ) $$,
  'base one-point reception scoring classifies as PPR'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":0.5}'::jsonb
    )
  $$,
  $$ values ('half_ppr'::text, 0.5::numeric) $$,
  'half-point reception scoring classifies as half-PPR'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":0}'::jsonb
    )
  $$,
  $$ values ('standard'::text, 0::numeric) $$,
  'zero-point reception scoring classifies as standard'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      tight_end_reception_bonus, has_position_specific_reception,
      has_bonus_scoring
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"bonus_rec_te":0.5}'::jsonb
    )
  $$,
  $$ values ('custom'::text, 1::numeric, 0.5::numeric, true, true) $$,
  'tight-end premium remains separate from base PPR'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      has_idp_scoring
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":0.5,"idp_sack":2}'::jsonb
    )
  $$,
  $$ values ('half_ppr'::text, 0.5::numeric, true) $$,
  'explicit idp_* scoring is recognized without changing broad reception format'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      has_idp_scoring
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":0.5,"sack":2}'::jsonb
    )
  $$,
  $$ values ('half_ppr'::text, 0.5::numeric, false) $$,
  'ordinary team-defense scoring is not mislabeled as IDP'
);
select results_eq(
  $$
    select
      redundant.broad_scoring_format,
      redundant.has_position_specific_reception,
      redundant.compatibility_key = base.compatibility_key
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4,"rec_fb":1}'::jsonb
    ) as redundant
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4}'::jsonb
    ) as base
  $$,
  $$ values ('ppr'::text, true, true) $$,
  'redundant fullback reception scoring stays exact and diagnostic but normalizes out of compatibility'
);
select results_eq(
  $$
    select
      zero_bonus.tight_end_reception_bonus,
      zero_bonus.has_position_specific_reception,
      zero_bonus.has_bonus_scoring,
      zero_bonus.compatibility_key = base.compatibility_key
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4,"bonus_rec_te":0}'::jsonb
    ) as zero_bonus
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4}'::jsonb
    ) as base
  $$,
  $$ values (0::numeric, true, false, true) $$,
  'zero TE premium remains exact while normalizing out of compatibility'
);
select results_eq(
  $$
    select
      individual.has_idp_scoring,
      team_defense.has_idp_scoring
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"qb_hit":1}'::jsonb
    ) as individual
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"sack":1}'::jsonb
    ) as team_defense
  $$,
  $$ values (true, false) $$,
  'reviewed individual-defense keys remain distinct from team-defense scoring'
);
select is(
  (
    select (derived_dimensions ->> 'unknown_key_count')::integer
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"fg_ret_yd":0.04}'::jsonb
    )
  ),
  0,
  'the audited fg_ret_yd source key is recognized as ordinary scoring'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      derived_dimensions ->> 'unknown_key_count',
      derived_dimensions -> 'unknown_keys'
    from app_private.classify_sleeper_scoring_settings(
      '{"mystery_metric":7}'::jsonb
    )
  $$,
  $$ values (
    'unknown'::text,
    null::numeric,
    '1'::text,
    '["mystery_metric"]'::jsonb
  ) $$,
  'unknown scoring keys remain bounded diagnostics and do not destroy exact input'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      derived_dimensions -> 'malformed_reviewed_keys'
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":"one"}'::jsonb
    )
  $$,
  $$ values ('unknown'::text, null::numeric, '["rec"]'::jsonb) $$,
  'malformed reviewed scoring is preserved but never silently coerced'
);
create temporary table material_scoring_cases (
  label text primary key,
  left_settings jsonb not null,
  right_settings jsonb not null
);

insert into material_scoring_cases (label, left_settings, right_settings)
values
  ('bonus_nonzero', '{"rec":1,"bonus_rush_yd_100":3}', '{"rec":1,"bonus_rush_yd_100":4}'),
  ('first_down', '{"rec":1,"rush_fd":0.5}', '{"rec":1,"rush_fd":1}'),
  ('idp', '{"rec":1,"idp_sack":2}', '{"rec":1,"idp_sack":3}'),
  ('kicking', '{"rec":1,"fgm":3}', '{"rec":1,"fgm":4}'),
  ('pass_int', '{"rec":1,"pass_int":-2}', '{"rec":1,"pass_int":-1}'),
  ('pass_td', '{"rec":1,"pass_td":4}', '{"rec":1,"pass_td":6}'),
  ('pass_yd', '{"rec":1,"pass_yd":0.04}', '{"rec":1,"pass_yd":0.05}'),
  ('rec_td', '{"rec":1,"rec_td":6}', '{"rec":1,"rec_td":5}'),
  ('rec_yd', '{"rec":1,"rec_yd":0.1}', '{"rec":1,"rec_yd":0.2}'),
  ('rush_td', '{"rec":1,"rush_td":6}', '{"rec":1,"rush_td":5}'),
  ('rush_yd', '{"rec":1,"rush_yd":0.1}', '{"rec":1,"rush_yd":0.2}'),
  ('team_defense', '{"rec":1,"sack":1}', '{"rec":1,"sack":2}');

select results_eq(
  $$
    select test_case.label,
      app_private.sleeper_effective_scoring_v1(test_case.left_settings)
        <> app_private.sleeper_effective_scoring_v1(test_case.right_settings),
      left_result.compatibility_key <> right_result.compatibility_key,
      (left_result.derived_dimensions ->> 'unknown_key_count')::integer = 0
        and (right_result.derived_dimensions ->> 'unknown_key_count')::integer = 0
    from material_scoring_cases as test_case
    cross join lateral app_private.classify_sleeper_scoring_settings(
      test_case.left_settings
    ) as left_result
    cross join lateral app_private.classify_sleeper_scoring_settings(
      test_case.right_settings
    ) as right_result
    order by test_case.label
  $$,
  $$ values
    ('bonus_nonzero'::text, true, true, true),
    ('first_down'::text, true, true, true),
    ('idp'::text, true, true, true),
    ('kicking'::text, true, true, true),
    ('pass_int'::text, true, true, true),
    ('pass_td'::text, true, true, true),
    ('pass_yd'::text, true, true, true),
    ('rec_td'::text, true, true, true),
    ('rec_yd'::text, true, true, true),
    ('rush_td'::text, true, true, true),
    ('rush_yd'::text, true, true, true),
    ('team_defense'::text, true, true, true)
  $$,
  'every audited material scoring-value difference remains compatibility-distinct'
);
select results_eq(
  $$
    select
      app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"bonus_rush_yd_100":0}'::jsonb
      ) = app_private.sleeper_effective_scoring_v1('{"rec":1}'::jsonb),
      app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"rec_fb":1}'::jsonb
      ) = app_private.sleeper_effective_scoring_v1('{"rec":1}'::jsonb),
      app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"bonus_future_rule":0}'::jsonb
      ) ? 'bonus_future_rule',
      (
        select compatibility_key
        from app_private.classify_sleeper_scoring_settings(
          '{"rec":1,"bonus_future_rule":0}'::jsonb
        )
      ) <> (
        select compatibility_key
        from app_private.classify_sleeper_scoring_settings('{"rec":1}'::jsonb)
      ),
      (
        select derived_dimensions -> 'unknown_keys'
        from app_private.classify_sleeper_scoring_settings(
          '{"rec":1,"bonus_future_rule":0}'::jsonb
        )
      ) = '["bonus_future_rule"]'::jsonb,
      app_private.sleeper_effective_scoring_v1(
        '{"pass_td":4,"rec":1}'::jsonb
      ) = app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"pass_td":4}'::jsonb
      )
  $$,
  $$ values (true, true, true, true, true, true) $$,
  'only allowlisted zero bonuses, redundant receptions, and JSON order normalize'
);
select results_eq(
  $$
    select
      unknown_left.compatibility_key <> unknown_right.compatibility_key,
      malformed_left.compatibility_key <> malformed_right.compatibility_key,
      app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"mystery_metric":7}'::jsonb
      ) <> app_private.sleeper_effective_scoring_v1(
        '{"rec":1,"mystery_metric":8}'::jsonb
      ),
      app_private.sleeper_effective_scoring_v1(
        '{"rec":"one"}'::jsonb
      ) <> app_private.sleeper_effective_scoring_v1(
        '{"rec":"two"}'::jsonb
      )
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"mystery_metric":7}'::jsonb
    ) as unknown_left
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"mystery_metric":8}'::jsonb
    ) as unknown_right
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":"one"}'::jsonb
    ) as malformed_left
    cross join app_private.classify_sleeper_scoring_settings(
      '{"rec":"two"}'::jsonb
    ) as malformed_right
  $$,
  $$ values (true, true, true, true) $$,
  'unknown and malformed scoring values retain conservative exact fallback identity'
);
select is(
  (
    select compatibility_key
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"rush_yd":0.1}'::jsonb
    )
  ),
  app_private.context_sha256(
    'fantasyhud:nfl:scoring_compatibility',
    1,
    app_private.sleeper_effective_scoring_v1(
      '{"rec":1,"rush_yd":0.1}'::jsonb
    )
  ),
  'scoring compatibility uses the provider-neutral FANTASY HUD namespace'
);
select results_eq(
  $$
    select
      derived_dimensions ->> 'effective_scoring_fingerprint',
      derived_dimensions -> 'reviewed_noop_keys',
      derived_dimensions ->> 'reviewed_noop_key_count'
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"bonus_rush_yd_100":0}'::jsonb
    )
  $$,
  $$ values (
    app_private.context_sha256(
      'fantasyhud:nfl:effective_scoring', 1, '{"rec":1}'::jsonb
    ),
    '["bonus_rush_yd_100"]'::jsonb,
    '1'::text
  ) $$,
  'effective scoring exposes bounded diagnostics for each reviewed semantic no-op'
);
select isnt(
  app_private.context_sha256(
    'scoring_context:sleeper:nfl', 1, '{"rec":1}'::jsonb
  ),
  app_private.context_sha256(
    'scoring_context:other:nfl', 1, '{"rec":1}'::jsonb
  ),
  'exact scoring identity remains provider-specific'
);
select isnt(
  (
    select compatibility_key
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":4}'::jsonb
    )
  ),
  (
    select compatibility_key
    from app_private.classify_sleeper_scoring_settings(
      '{"rec":1,"pass_td":6}'::jsonb
    )
  ),
  'four- and six-point passing touchdowns remain compatibility-distinct'
);
select throws_ok(
  $$
    select *
    from app_private.classify_sleeper_scoring_settings('[]'::jsonb)
  $$,
  '22023',
  'The Sleeper scoring settings are invalid.',
  'non-object scoring settings fail closed'
);

create temporary table context_cases (
  label text primary key,
  format_context_id uuid not null
);

insert into context_cases (label, format_context_id)
values
  (
    'base',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'base_reordered_json',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"pass_td":4,"rec":1}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"best_ball":0,"type":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'ordinary_scoring_difference',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4,"rush_yd":0.1}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'half_ppr',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":0.5,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'six_point_pass_td',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":6}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'tight_end_premium',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4,"bonus_rec_te":0.5}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'unknown_scoring_key',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4,"mystery_metric":7}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'roster_order',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","WR","RB","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'ten_team',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      10, 6, 'redraft', false, false, false
    )
  ),
  (
    'best_ball',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":1}'::jsonb,
      12, 6, 'redraft', true, false, false
    )
  ),
  (
    'superflex',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","SUPER_FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, true, false
    )
  ),
  (
    'idp',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4,"idp_sack":2}'::jsonb,
      '["QB","RB","WR","TE","LB","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, true
    )
  ),
  (
    'reviewed_draft_setting',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0,"draft_rounds":18}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'unknown_league_setting',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0,"task008_unknown_setting":7}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  ),
  (
    'lineup_2wr',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","TE","FLEX","BN","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'lineup_3wr',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'lineup_2te',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","TE","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'lineup_2flex',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","TE","FLEX","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'lineup_unknown_one',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","TE","FLEX","MYSTERY","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'lineup_unknown_two',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","RB","WR","WR","TE","MYSTERY","MYSTERY","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 9, 'redraft', false, false, false
    )
  ),
  (
    'idp_one_qb',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4,"idp_sack":2}'::jsonb,
      '["QB","RB","WR","TE","FLEX","LB","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 7, 'redraft', false, false, true
    )
  ),
  (
    'idp_superflex',
    app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{"rec":1,"pass_td":4,"idp_sack":2}'::jsonb,
      '["QB","RB","WR","TE","SUPER_FLEX","LB","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 7, 'redraft', false, true, true
    )
  );

select is(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'base_reordered_json'),
  'semantically identical reordered JSON reuses one exact format context'
);
select results_eq(
  $$
    select
      base.exact_league_settings,
      changed.exact_league_settings,
      base.league_settings_fingerprint <>
        changed.league_settings_fingerprint,
      base.format_fingerprint <> changed.format_fingerprint,
      base.compatibility_key <> changed.compatibility_key,
      changed.derived_dimensions -> 'draft_relevant_settings'
    from public.league_format_contexts as base
    cross join public.league_format_contexts as changed
    where base.id = (
        select format_context_id from context_cases where label = 'base'
      )
      and changed.id = (
        select format_context_id from context_cases
        where label = 'reviewed_draft_setting'
      )
  $$,
  $$ values (
    '{"type":0,"best_ball":0}'::jsonb,
    '{"type":0,"best_ball":0,"draft_rounds":18}'::jsonb,
    true,
    true,
    true,
    '{"type":0,"best_ball":0,"draft_rounds":18}'::jsonb
  ) $$,
  'a reviewed league-setting change retains both exact objects and changes exact format identity'
);
select results_eq(
  $$
    select
      unknown_format.exact_league_settings -> 'task008_unknown_setting',
      unknown_format.compatibility_key <> base.compatibility_key,
      unknown_format.context_quality,
      unknown_format.derived_dimensions -> 'unknown_league_setting_keys',
      unknown_format.derived_dimensions ->> 'unknown_league_setting_key_count',
      unknown_format.derived_dimensions ->>
        'unknown_league_setting_keys_truncated',
      unknown_format.derived_dimensions ->>
        'unknown_league_settings_fingerprint'
    from public.league_format_contexts as base
    cross join public.league_format_contexts as unknown_format
    where base.id = (
        select format_context_id from context_cases where label = 'base'
      )
      and unknown_format.id = (
        select format_context_id from context_cases
        where label = 'unknown_league_setting'
      )
  $$,
  $$ values (
    '7'::jsonb,
    true,
    'exact'::text,
    '["task008_unknown_setting"]'::jsonb,
    '1'::text,
    'false'::text,
    app_private.context_sha256(
      'fantasyhud:nfl:league_settings_unknown',
      1,
      '{"task008_unknown_setting":7}'::jsonb
    )
  ) $$,
  'an unclassified league setting is retained and narrows compatibility through exact fallback'
);

create temporary table base_reuse_fault_snapshot as
select id, compatibility_key
from public.league_format_contexts
where id = (
  select format_context_id from context_cases where label = 'base'
);

alter table public.league_format_contexts
disable trigger league_format_contexts_reject_mutation;
update public.league_format_contexts as format
set compatibility_key = 'task008-corrupted-compatibility'
from base_reuse_fault_snapshot as snapshot
where format.id = snapshot.id;
alter table public.league_format_contexts
enable trigger league_format_contexts_reject_mutation;

select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl',
      '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 6, 'redraft', false, false, false
    )
  $$,
  '55000',
  'The immutable league format context identity is inconsistent.',
  'exact-context conflict reuse rejects a corrupted derived field'
);

alter table public.league_format_contexts
disable trigger league_format_contexts_reject_mutation;
update public.league_format_contexts as format
set compatibility_key = snapshot.compatibility_key
from base_reuse_fault_snapshot as snapshot
where format.id = snapshot.id;
alter table public.league_format_contexts
enable trigger league_format_contexts_reject_mutation;

select is(
  (
    select format.compatibility_key
    from public.league_format_contexts as format
    inner join base_reuse_fault_snapshot as snapshot on snapshot.id = format.id
  ),
  (select compatibility_key from base_reuse_fault_snapshot),
  'the fault-injected immutable format row is restored before later tests'
);
select is(
  (
    select count(*)::integer
    from public.scoring_contexts
    where provider = 'sleeper'
      and sport = 'nfl'
      and normalization_version = 1
      and exact_scoring_settings = '{"rec":1,"pass_td":4}'::jsonb
  ),
  1,
  'reordered exact scoring JSON deduplicates to one scoring context'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'half_ppr'),
  'one reception-scoring value change creates distinct exact format identity'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points
    from public.scoring_contexts
    where provider = 'sleeper'
      and sport = 'nfl'
      and normalization_version = 1
      and exact_scoring_settings in (
      '{"rec":1,"pass_td":4}'::jsonb,
      '{"rec":0.5,"pass_td":4}'::jsonb
    )
    order by reception_points desc
  $$,
  $$ values
    ('ppr'::text, 1::numeric),
    ('half_ppr'::text, 0.5::numeric)
  $$,
  'persisted broad scoring classifications match exact settings'
);
select isnt(
  (
    select scoring_context_id
    from public.league_format_contexts
    where id = (
      select format_context_id from context_cases
      where label = 'base'
    )
  ),
  (
    select scoring_context_id
    from public.league_format_contexts
    where id = (
      select format_context_id from context_cases
      where label = 'six_point_pass_td'
    )
  ),
  'passing-touchdown scoring changes exact scoring identity'
);
select results_eq(
  $$
    select broad_scoring_format, reception_points,
      tight_end_reception_bonus, has_position_specific_reception,
      has_bonus_scoring
    from public.scoring_contexts
    where id = (
      select scoring_context_id
      from public.league_format_contexts
      where id = (
        select format_context_id from context_cases
        where label = 'tight_end_premium'
      )
    )
  $$,
  $$ values ('custom'::text, 1::numeric, 0.5::numeric, true, true) $$,
  'persisted tight-end premium remains distinct and queryable'
);
select is(
  (
    select exact_scoring_settings -> 'mystery_metric'
    from public.scoring_contexts
    where id = (
      select scoring_context_id
      from public.league_format_contexts
      where id = (
        select format_context_id from context_cases
        where label = 'unknown_scoring_key'
      )
    )
  ),
  '7'::jsonb,
  'unknown scoring keys survive exact context persistence'
);
select results_eq(
  $$
    select
      base.compatibility_key <> ordinary.compatibility_key,
      base.scoring_fingerprint <> ordinary.scoring_fingerprint
    from public.scoring_contexts as base
    cross join public.scoring_contexts as ordinary
    where base.provider = 'sleeper'
      and base.sport = 'nfl'
      and base.normalization_version = 1
      and ordinary.provider = 'sleeper'
      and ordinary.sport = 'nfl'
      and ordinary.normalization_version = 1
      and base.exact_scoring_settings = '{"rec":1,"pass_td":4}'::jsonb
      and ordinary.exact_scoring_settings =
        '{"rec":1,"pass_td":4,"rush_yd":0.1}'::jsonb
  $$,
  $$ values (true, true) $$,
  'material rush-yard scoring differs in both compatibility and exact identity'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'roster_order'),
  'exact roster-position order changes format identity'
);
select isnt(
  (
    select lineup_fingerprint
    from public.league_format_contexts
    where id = (
      select format_context_id from context_cases where label = 'base'
    )
  ),
  (
    select lineup_fingerprint
    from public.league_format_contexts
    where id = (
      select format_context_id from context_cases where label = 'roster_order'
    )
  ),
  'exact roster-position order changes the persisted lineup fingerprint'
);
select results_eq(
  $$
    select
      base.lineup_profile = reordered.lineup_profile,
      base.lineup_profile_fingerprint =
        reordered.lineup_profile_fingerprint,
      base.compatibility_key = reordered.compatibility_key
    from public.league_format_contexts as base
    cross join public.league_format_contexts as reordered
    where base.id = (
        select format_context_id from context_cases where label = 'base'
      )
      and reordered.id = (
        select format_context_id from context_cases
        where label = 'roster_order'
      )
  $$,
  $$ values (true, true, true) $$,
  'the same slot counts in different order share one compatible lineup profile'
);
select results_eq(
  $$
    with comparison(label, left_case, right_case) as (
      values
        ('2WR versus 3WR'::text, 'lineup_2wr'::text, 'lineup_3wr'::text),
        ('1TE versus 2TE'::text, 'lineup_2wr'::text, 'lineup_2te'::text),
        ('1FLEX versus 2FLEX'::text, 'lineup_2wr'::text, 'lineup_2flex'::text),
        (
          'one versus two unknown slots'::text,
          'lineup_unknown_one'::text,
          'lineup_unknown_two'::text
        )
    )
    select comparison.label,
      left_format.lineup_profile_fingerprint <>
        right_format.lineup_profile_fingerprint,
      left_format.compatibility_key <> right_format.compatibility_key
    from comparison
    inner join context_cases as left_case
      on left_case.label = comparison.left_case
    inner join public.league_format_contexts as left_format
      on left_format.id = left_case.format_context_id
    inner join context_cases as right_case
      on right_case.label = comparison.right_case
    inner join public.league_format_contexts as right_format
      on right_format.id = right_case.format_context_id
    order by comparison.label
  $$,
  $$ values
    ('1FLEX versus 2FLEX'::text, true, true),
    ('1TE versus 2TE'::text, true, true),
    ('2WR versus 3WR'::text, true, true),
    ('one versus two unknown slots'::text, true, true)
  $$,
  'count-sensitive lineup profiles keep every material and unknown slot difference distinct'
);
select results_eq(
  $$
    select
      (one_unknown.lineup_profile ->> 'MYSTERY')::integer,
      (two_unknown.lineup_profile ->> 'MYSTERY')::integer,
      one_unknown.roster_size,
      two_unknown.roster_size
    from public.league_format_contexts as one_unknown
    cross join public.league_format_contexts as two_unknown
    where one_unknown.id = (
        select format_context_id from context_cases
        where label = 'lineup_unknown_one'
      )
      and two_unknown.id = (
        select format_context_id from context_cases
        where label = 'lineup_unknown_two'
      )
  $$,
  $$ values (1, 2, 9, 9) $$,
  'lineup profiles preserve exact unknown slot tokens and counts at equal roster size'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'ten_team'),
  'team count changes exact format identity'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'best_ball'),
  'best-ball state changes exact format identity'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'superflex'),
  'superflex state changes exact format identity'
);
select isnt(
  (select format_context_id from context_cases where label = 'base'),
  (select format_context_id from context_cases where label = 'idp'),
  'IDP state changes exact format identity'
);
select results_eq(
  $$
    select label, format.quarterback_format, format.context_quality
    from context_cases as test_case
    inner join public.league_format_contexts as format
      on format.id = test_case.format_context_id
    where label in ('base', 'superflex', 'idp')
    order by label
  $$,
  $$ values
    ('base'::text, 'one_qb'::text, 'exact'::text),
    ('idp'::text, 'one_qb'::text, 'exact'::text),
    ('superflex'::text, 'superflex'::text, 'exact'::text)
  $$,
  'quarterback topology and exact quality follow reviewed source dimensions'
);
select results_eq(
  $$
    select
      one_qb.has_idp,
      superflex.has_idp,
      one_qb.quarterback_format,
      superflex.quarterback_format,
      one_qb.compatibility_key <> superflex.compatibility_key
    from public.league_format_contexts as one_qb
    cross join public.league_format_contexts as superflex
    where one_qb.id = (
        select format_context_id from context_cases
        where label = 'idp_one_qb'
      )
      and superflex.id = (
        select format_context_id from context_cases
        where label = 'idp_superflex'
      )
  $$,
  $$ values (true, true, 'one_qb'::text, 'superflex'::text, true) $$,
  'IDP state stays independent from quarterback topology and compatibility'
);

select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
      12, 0, 'unknown', false, false, false
    )
  $$,
  '22023',
  'The exact Sleeper league format input is invalid.',
  'non-array roster source state is rejected'
);
select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{}'::jsonb, '["QB","bad token"]'::jsonb,
      '{"type":0}'::jsonb, 12, 2, 'redraft', false, false, false
    )
  $$,
  '22023',
  'The exact Sleeper roster positions are invalid.',
  'malformed exact roster tokens are rejected'
);
select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{}'::jsonb, '["QB","SUPER_FLEX"]'::jsonb,
      '{"type":0}'::jsonb, 12, 2, 'redraft', false, false, false
    )
  $$,
  '22023',
  'The derived Sleeper league format does not match exact source state.',
  'derived superflex truth cannot contradict exact roster positions'
);
select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{}'::jsonb, '["QB"]'::jsonb, '[]'::jsonb,
      12, 1, 'unknown', false, false, false
    )
  $$,
  '22023',
  'The exact Sleeper league format input is invalid.',
  'exact league settings must be a JSON object'
);
select throws_ok(
  $$
    select app_private.ensure_sleeper_league_format_context(
      'sleeper', 'nfl', '{}'::jsonb, '["QB"]'::jsonb,
      jsonb_build_object('oversized', repeat('x', 131073)),
      12, 1, 'unknown', false, false, false
    )
  $$,
  '22023',
  'The exact Sleeper league format input is invalid.',
  'exact league settings size is bounded'
);
select throws_ok(
  $$
    insert into public.scoring_contexts (
      provider, sport, normalization_version, scoring_fingerprint,
      exact_scoring_settings, broad_scoring_format,
      has_position_specific_reception, has_bonus_scoring,
      has_idp_scoring, compatibility_key, derived_dimensions
    ) values (
      'sleeper', 'nfl', 1, repeat('a', 64), '[]'::jsonb, 'unknown',
      false, false, false, 'invalid-object-fixture', '{}'::jsonb
    )
  $$,
  '22023',
  'The Sleeper scoring settings are invalid.',
  'scoring exact source must be a JSON object'
);
select throws_ok(
  $$
    insert into public.scoring_contexts (
      provider, sport, normalization_version, scoring_fingerprint,
      exact_scoring_settings, broad_scoring_format,
      has_position_specific_reception, has_bonus_scoring,
      has_idp_scoring, compatibility_key, derived_dimensions
    ) values (
      'sleeper', 'nfl', 1, repeat('a', 64),
      jsonb_build_object('oversized', repeat('x', 131073)), 'unknown',
      false, false, false, 'oversized-fixture', '{}'::jsonb
    )
  $$,
  '22023',
  'The Sleeper scoring settings are invalid.',
  'scoring exact source size is bounded'
);
select throws_ok(
  $$
    insert into public.scoring_contexts (
      provider, sport, normalization_version, scoring_fingerprint,
      exact_scoring_settings, broad_scoring_format, reception_points,
      passing_touchdown_points, tight_end_reception_bonus,
      has_position_specific_reception, has_bonus_scoring,
      has_idp_scoring, compatibility_key, derived_dimensions
    )
    select provider, sport, normalization_version, repeat('a', 64),
      exact_scoring_settings, broad_scoring_format, reception_points,
      passing_touchdown_points, tight_end_reception_bonus,
      has_position_specific_reception, has_bonus_scoring,
      has_idp_scoring, compatibility_key, derived_dimensions
    from public.scoring_contexts
    where provider = 'sleeper'
      and sport = 'nfl'
      and normalization_version = 1
      and exact_scoring_settings = '{"rec":1,"pass_td":4}'::jsonb
  $$,
  '23514', null,
  'scoring fingerprint must match exact source and normalization version'
);
create or replace function pg_temp.insert_invalid_format_context(
  p_mismatch text
)
returns void
language plpgsql
set search_path = pg_catalog
as $$
begin
  insert into public.league_format_contexts (
    provider, sport, normalization_version, scoring_context_id,
    format_fingerprint, league_settings_fingerprint,
    lineup_fingerprint, lineup_profile_fingerprint, lineup_profile,
    exact_roster_positions, exact_league_settings, team_count, roster_size,
    roster_management_type, is_best_ball, has_superflex, has_idp,
    quarterback_format, compatibility_key, context_quality,
    derived_dimensions
  )
  select
    case when p_mismatch = 'provider' then 'other' else source.provider end,
    source.sport,
    case
      when p_mismatch = 'version' then source.normalization_version + 1
      else source.normalization_version
    end,
    case
      when p_mismatch = 'scoring_context' then (
        select changed.scoring_context_id
        from public.league_format_contexts as changed
        where changed.id = (
          select test_case.format_context_id
          from pg_temp.context_cases as test_case
          where test_case.label = 'half_ppr'
        )
      )
      else source.scoring_context_id
    end,
    case
      when p_mismatch = 'format_fingerprint' then repeat('f', 64)
      else source.format_fingerprint
    end,
    case
      when p_mismatch = 'league_settings_fingerprint' then repeat('d', 64)
      else source.league_settings_fingerprint
    end,
    case
      when p_mismatch = 'lineup_fingerprint' then repeat('e', 64)
      else source.lineup_fingerprint
    end,
    case
      when p_mismatch = 'lineup_profile_fingerprint' then repeat('c', 64)
      else source.lineup_profile_fingerprint
    end,
    case
      when p_mismatch = 'lineup_profile'
        then source.lineup_profile || '{"TAMPERED":1}'::jsonb
      else source.lineup_profile
    end,
    source.exact_roster_positions,
    case
      when p_mismatch = 'exact_league_settings'
        then source.exact_league_settings || '{"task008_tampered":1}'::jsonb
      else source.exact_league_settings
    end,
    source.team_count,
    source.roster_size,
    source.roster_management_type,
    source.is_best_ball,
    source.has_superflex,
    source.has_idp,
    case
      when p_mismatch = 'quarterback_format' then 'two_qb'
      else source.quarterback_format
    end,
    case
      when p_mismatch = 'compatibility_key' then 'task008-wrong-compatibility'
      else source.compatibility_key
    end,
    case
      when p_mismatch = 'context_quality' then 'partial'
      else source.context_quality
    end,
    case
      when p_mismatch = 'derived_dimensions'
        then source.derived_dimensions || '{"task008_tampered":true}'::jsonb
      else source.derived_dimensions
    end
  from public.league_format_contexts as source
  where source.id = (
    select test_case.format_context_id
    from pg_temp.context_cases as test_case
    where test_case.label = 'base'
  );
end;
$$;

select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('provider') $$,
  '23514', null,
  'format insert rejects a scoring-context provider namespace mismatch'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('version') $$,
  '23514', null,
  'format insert rejects a scoring-context normalization-version mismatch'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('scoring_context') $$,
  '23514', null,
  'format insert rejects an exact scoring-context relationship mismatch'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('league_settings_fingerprint') $$,
  '23514', null,
  'format insert rejects an incorrect exact league-settings fingerprint'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('exact_league_settings') $$,
  '23514', null,
  'format insert rejects exact league settings inconsistent with identity'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('lineup_fingerprint') $$,
  '23514', null,
  'format insert rejects an incorrect ordered-lineup fingerprint'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('format_fingerprint') $$,
  '23514', null,
  'format insert rejects an incorrect exact format fingerprint'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('lineup_profile_fingerprint') $$,
  '23514', null,
  'format insert rejects an incorrect compatible-lineup fingerprint'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('lineup_profile') $$,
  '23514', null,
  'format insert rejects a lineup profile inconsistent with exact slots'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('quarterback_format') $$,
  '23514', null,
  'format insert rejects an incorrect quarterback format'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('compatibility_key') $$,
  '23514', null,
  'format insert rejects an incorrect compatibility key'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('context_quality') $$,
  '23514', null,
  'format insert rejects context quality inconsistent with exact source'
);
select throws_ok(
  $$ select pg_temp.insert_invalid_format_context('derived_dimensions') $$,
  '23514', null,
  'format insert rejects derived dimensions inconsistent with exact source'
);

insert into public.scoring_contexts (
  provider, sport, normalization_version, scoring_fingerprint,
  exact_scoring_settings, broad_scoring_format,
  has_position_specific_reception, has_bonus_scoring,
  has_idp_scoring, compatibility_key, derived_dimensions
)
values (
  'task008_fixture', 'nfl', 1,
  app_private.context_sha256(
    'scoring_context:task008_fixture:nfl', 1, '{}'::jsonb
  ),
  '{}'::jsonb, 'unknown', false, false, false,
  'fixture-quality-scoring', '{}'::jsonb
);
select throws_ok(
  $$
    insert into public.league_format_contexts (
      provider, sport, normalization_version, scoring_context_id,
      format_fingerprint, league_settings_fingerprint,
      lineup_fingerprint, lineup_profile_fingerprint, lineup_profile,
      exact_roster_positions,
      exact_league_settings, team_count, roster_size,
      roster_management_type, is_best_ball, has_superflex, has_idp,
      quarterback_format, compatibility_key, context_quality,
      derived_dimensions
    )
    select
      'task008_fixture', 'nfl', 1, scoring.id,
      app_private.league_format_fingerprint(
        1, 'task008_fixture', 'nfl', scoring.scoring_fingerprint,
        app_private.context_sha256(
          'league_settings:task008_fixture:nfl', 1, '{}'::jsonb
        ),
        array['QB']::text[], 8,
        1, 'unknown', false, false, false
      ),
      app_private.context_sha256(
        'league_settings:task008_fixture:nfl', 1, '{}'::jsonb
      ),
      app_private.context_text_array_sha256(
        'lineup:task008_fixture:nfl', 1, array['QB']::text[]
      ),
      app_private.context_sha256(
        'fantasyhud:nfl:lineup_profile', 1, '{"QB":1}'::jsonb
      ),
      '{"QB":1}'::jsonb, array['QB']::text[], '{}'::jsonb, 8, 1,
      'unknown', false, false, false, 'one_qb',
      'fixture-exact', 'exact', '{}'::jsonb
    from public.scoring_contexts as scoring
    where scoring.provider = 'task008_fixture'
      and scoring.sport = 'nfl'
      and scoring.normalization_version = 1
  $$,
  '23514',
  'Exact league format context requires a reviewed classifier.',
  'an unsupported provider cannot claim exact context quality'
);
select lives_ok(
  $$
    insert into public.league_format_contexts (
      provider, sport, normalization_version, scoring_context_id,
      format_fingerprint, league_settings_fingerprint,
      lineup_fingerprint, lineup_profile_fingerprint, lineup_profile,
      exact_roster_positions,
      exact_league_settings, team_count, roster_size,
      roster_management_type, is_best_ball, has_superflex, has_idp,
      quarterback_format, compatibility_key, context_quality,
      derived_dimensions
    )
    select
      'task008_fixture', 'nfl', 1, scoring.id,
      app_private.league_format_fingerprint(
        1, 'task008_fixture', 'nfl', scoring.scoring_fingerprint,
        app_private.context_sha256(
          'league_settings:task008_fixture:nfl', 1, '{}'::jsonb
        ),
        fixture.positions, fixture.team_count,
        cardinality(fixture.positions), 'unknown', false, false, false
      ),
      app_private.context_sha256(
        'league_settings:task008_fixture:nfl', 1, '{}'::jsonb
      ),
      app_private.context_text_array_sha256(
        'lineup:task008_fixture:nfl', 1, fixture.positions
      ),
      app_private.context_sha256(
        'fantasyhud:nfl:lineup_profile', 1, fixture.lineup_profile
      ),
      fixture.lineup_profile, fixture.positions, '{}'::jsonb,
      fixture.team_count,
      cardinality(fixture.positions), 'unknown', false, false, false,
      fixture.quarterback_format, 'fixture-' || fixture.quality,
      fixture.quality, '{}'::jsonb
    from public.scoring_contexts as scoring
    cross join (values
      (
        'partial'::text, array['QB','BN']::text[], 9,
        'one_qb'::text, '{"BN":1,"QB":1}'::jsonb
      ),
      (
        'unknown'::text, array[]::text[], 10,
        'unknown'::text, '{}'::jsonb
      )
    ) as fixture(
      quality, positions, team_count, quarterback_format, lineup_profile
    )
    where scoring.provider = 'task008_fixture'
      and scoring.sport = 'nfl'
      and scoring.normalization_version = 1
  $$,
  'unsupported providers may use deliberately reviewed partial and unknown quality'
);
select results_eq(
  $$
    select context_quality, count(*)::integer
    from public.league_format_contexts
    where provider = 'task008_fixture'
    group by context_quality
    order by context_quality
  $$,
  $$ values
    ('partial'::text, 1),
    ('unknown'::text, 1)
  $$,
  'partial and unknown qualities remain independently representable'
);
select throws_ok(
  $$
    update public.scoring_contexts
    set created_at = created_at
    where id = (
      select scoring_context_id
      from public.league_format_contexts
      where id = (
        select format_context_id from context_cases where label = 'base'
      )
    )
  $$,
  '55000',
  'Scoring and league format contexts are immutable.',
  'scoring contexts reject updates'
);
select throws_ok(
  $$
    delete from public.scoring_contexts
    where id = (
      select scoring_context_id
      from public.league_format_contexts
      where id = (
        select format_context_id from context_cases where label = 'base'
      )
    )
  $$,
  '55000',
  'Scoring and league format contexts are immutable.',
  'scoring contexts reject deletes'
);
select throws_ok(
  $$
    update public.league_format_contexts
    set created_at = created_at
    where id = (
      select format_context_id from context_cases where label = 'base'
    )
  $$,
  '55000',
  'Scoring and league format contexts are immutable.',
  'league format contexts reject updates'
);
select throws_ok(
  $$
    delete from public.league_format_contexts
    where id = (
      select format_context_id from context_cases where label = 'base'
    )
  $$,
  '55000',
  'Scoring and league format contexts are immutable.',
  'league format contexts reject deletes'
);

-- End-to-end discovery fixtures exercise current pointers, immutable history,
-- freshness, disjoint visibility, and last-synced regression safety.
create or replace function pg_temp.nfl_state(
  p_fetched_at text,
  p_week integer
)
returns jsonb
language sql
immutable
set search_path = pg_catalog
as $$
  select pg_catalog.jsonb_build_object(
    'season', 2026,
    'league_season', 2026,
    'league_create_season', 2027,
    'previous_season', 2025,
    'season_type', 'regular',
    'week', p_week,
    'leg', p_week,
    'display_week', p_week,
    'season_start_date', '2026-09-10',
    'provider_metadata', pg_catalog.jsonb_build_object('fixture_week', p_week),
    'fetched_at', p_fetched_at
  );
$$;

create or replace function pg_temp.league_payload(
  p_external_league_id text,
  p_name text,
  p_fetched_at text,
  p_scoring_settings jsonb,
  p_roster_positions jsonb,
  p_settings jsonb,
  p_team_count integer,
  p_roster_management_type text,
  p_is_best_ball boolean,
  p_has_superflex boolean,
  p_has_idp boolean
)
returns jsonb
language sql
immutable
set search_path = pg_catalog
as $$
  select pg_catalog.jsonb_build_object(
    'external_league_id', p_external_league_id,
    'sport', 'nfl',
    'season', 2026,
    'name', p_name,
    'status', 'pre_draft',
    'season_type', 'regular',
    'team_count', p_team_count,
    'roster_size', pg_catalog.jsonb_array_length(p_roster_positions),
    'roster_management_type', p_roster_management_type,
    'is_best_ball', p_is_best_ball,
    'has_superflex', p_has_superflex,
    'has_idp', p_has_idp,
    'scoring_format', case
      when pg_catalog.jsonb_typeof(p_scoring_settings -> 'rec') <> 'number'
        then 'unknown'
      when exists (
        select 1
        from pg_catalog.unnest(array[
          'bonus_rec_te', 'bonus_rec_rb', 'bonus_rec_wr',
          'rec_te', 'rec_rb', 'rec_wr'
        ]) as premium(key)
        where pg_catalog.jsonb_typeof(
          p_scoring_settings -> premium.key
        ) = 'number'
          and (p_scoring_settings ->> premium.key)::numeric <> 0
      ) then 'custom'
      when (p_scoring_settings ->> 'rec')::numeric = 1 then 'ppr'
      when (p_scoring_settings ->> 'rec')::numeric = 0.5 then 'half_ppr'
      when (p_scoring_settings ->> 'rec')::numeric = 0 then 'standard'
      else 'custom'
    end,
    'avatar_id', null,
    'avatar_url', null,
    'previous_external_league_id', null,
    'settings', p_settings,
    'scoring_settings', p_scoring_settings,
    'roster_positions', p_roster_positions,
    'provider_metadata', pg_catalog.jsonb_build_object(
      'fixture', p_external_league_id
    ),
    'provider_updated_at', null,
    'fetched_at', p_fetched_at
  );
$$;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'a1000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'task008-context-a@example.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb, now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a1000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'task008-context-b@example.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb, now(), now(), '', '', '', ''
  );

insert into public.fantasy_accounts (
  id, provider, external_user_id, username, normalized_username,
  provider_metadata, last_synced_at, updated_at
)
values
  (
    'a2000000-0000-0000-0000-000000000001',
    'sleeper', 'task008-user-a', 'Task008A', 'task008a', '{}'::jsonb,
    '2026-08-01T00:00:00Z'::timestamptz, now()
  ),
  (
    'a2000000-0000-0000-0000-000000000002',
    'sleeper', 'task008-user-b', 'Task008B', 'task008b', '{}'::jsonb,
    '2026-08-02T00:00:00Z'::timestamptz, now()
  );

insert into public.user_fantasy_accounts (
  user_id, fantasy_account_id, is_primary
)
values
  (
    'a1000000-0000-0000-0000-000000000001',
    'a2000000-0000-0000-0000-000000000001', true
  ),
  (
    'a1000000-0000-0000-0000-000000000002',
    'a2000000-0000-0000-0000-000000000002', true
  );

create temporary table user_a_initial_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);
create temporary table user_a_initial_completion as
select * from public.complete_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  (select sync_run_id from user_a_initial_start),
  pg_temp.nfl_state('2026-09-01T10:00:00Z', 1),
  pg_catalog.jsonb_build_array(
    pg_temp.league_payload(
      'task008-league-a1', 'Task 008 League A1',
      '2026-09-01T10:00:00Z', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    ),
    pg_temp.league_payload(
      'task008-league-a2', 'Task 008 League A2',
      '2026-09-01T10:00:00Z', '{"pass_td":4,"rec":1}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"best_ball":0,"type":0}'::jsonb,
      12, 'redraft', false, false, false
    )
  )
);

select results_eq(
  $$
    select observed_leagues, created_leagues, created_associations,
      active_associations
    from user_a_initial_completion
  $$,
  $$ values (2, 2, 2, 2) $$,
  'league discovery remains valid while creating context-aware leagues'
);
select is(
  (
    select count(*)::integer
    from public.leagues
    where external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
      and current_format_context_id is not null
  ),
  2,
  'every newly accepted league receives a current format pointer'
);
select is(
  (
    select count(distinct current_format_context_id)::integer
    from public.leagues
    where external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
  ),
  1,
  'the same exact context is reused across separate leagues'
);
select results_eq(
  $$
    select count(*)::integer, min(source), max(source),
      min(normalization_version), max(normalization_version)
    from public.league_format_observations as observation
    inner join public.leagues as league on league.id = observation.league_id
    where league.external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
  $$,
  $$ values (2, 'league_discovery'::text, 'league_discovery'::text, 1, 1) $$,
  'initial accepted representations append versioned discovery observations'
);
select results_eq(
  $$
    select scoring_settings, roster_positions, settings
    from public.leagues
    where external_league_id = 'task008-league-a1'
  $$,
  $$ values (
    '{"rec":1,"pass_td":4}'::jsonb,
    '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
    '{"type":0,"best_ball":0}'::jsonb
  ) $$,
  'context maintenance preserves the league exact source fields'
);

create temporary table user_a_initial_pointers as
select external_league_id, current_format_context_id
from public.leagues
where external_league_id in ('task008-league-a1', 'task008-league-a2');

create temporary table user_a_repeat_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);
select * from public.complete_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  (select sync_run_id from user_a_repeat_start),
  pg_temp.nfl_state('2026-09-01T10:00:00Z', 1),
  pg_catalog.jsonb_build_array(
    pg_temp.league_payload(
      'task008-league-a1', 'Task 008 League A1',
      '2026-09-01T10:00:00Z', '{"pass_td":4,"rec":1}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"best_ball":0,"type":0}'::jsonb,
      12, 'redraft', false, false, false
    ),
    pg_temp.league_payload(
      'task008-league-a2', 'Task 008 League A2',
      '2026-09-01T10:00:00Z', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    )
  )
);
select is(
  (
    select count(*)::integer
    from public.league_format_observations as observation
    inner join public.leagues as league on league.id = observation.league_id
    where league.external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
  ),
  2,
  'an identical accepted observation replay is idempotent'
);

create temporary table user_a_conflict_snapshot as
select
  league.external_league_id,
  league.name,
  league.scoring_settings,
  league.roster_positions,
  league.settings,
  league.fetched_at,
  league.current_format_context_id,
  (
    select count(*)::integer
    from public.league_format_observations as observation
    where observation.league_id = league.id
  ) as observation_count
from public.leagues as league
where league.external_league_id in ('task008-league-a1', 'task008-league-a2');

create temporary table user_a_conflict_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);
select throws_ok(
  format(
    $statement$
      select * from public.complete_sleeper_league_discovery(
        'a1000000-0000-0000-0000-000000000001',
        'a2000000-0000-0000-0000-000000000001',
        %L::uuid,
        pg_temp.nfl_state('2026-09-01T10:00:00Z', 1),
        pg_catalog.jsonb_build_array(
          pg_temp.league_payload(
            'task008-league-a1', 'Transient Task 008 League A1',
            '2026-09-01T10:00:00Z',
            '{"rec":1,"pass_td":4}'::jsonb,
            '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
            '{"type":0,"best_ball":0}'::jsonb,
            12, 'redraft', false, false, false
          ),
          pg_temp.league_payload(
            'task008-league-a2', 'Conflicting Task 008 League A2',
            '2026-09-01T10:00:00Z',
            '{"rec":0.5,"pass_td":4}'::jsonb,
            '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
            '{"type":0,"best_ball":0}'::jsonb,
            12, 'redraft', false, false, false
          )
        )
      )
    $statement$,
    (select sync_run_id from user_a_conflict_start)
  ),
  '23505',
  'A league format observation timestamp already has a conflicting context.',
  'a conflicting context at the same observation time fails closed'
);
select results_eq(
  $$
    select
      league.external_league_id,
      league.name,
      league.scoring_settings,
      league.roster_positions,
      league.settings,
      league.fetched_at,
      league.current_format_context_id,
      (
        select count(*)::integer
        from public.league_format_observations as observation
        where observation.league_id = league.id
      )
    from public.leagues as league
    where league.external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
    order by league.external_league_id
  $$,
  $$
    select external_league_id, name, scoring_settings, roster_positions,
      settings, fetched_at, current_format_context_id, observation_count
    from user_a_conflict_snapshot
    order by external_league_id
  $$,
  'same-time conflict rolls back the full collection source, pointers, and history'
);

create temporary table user_a_conflict_failure as
select * from public.fail_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  (select sync_run_id from user_a_conflict_start),
  'context_observation_conflict',
  'Expected same-time context conflict.',
  false
);

create temporary table user_a_change_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);
select * from public.complete_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  (select sync_run_id from user_a_change_start),
  pg_temp.nfl_state('2026-09-01T11:00:00Z', 2),
  pg_catalog.jsonb_build_array(
    pg_temp.league_payload(
      'task008-league-a1', 'Task 008 League A1 Updated',
      '2026-09-01T11:00:00Z', '{"rec":0.5,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    ),
    pg_temp.league_payload(
      'task008-league-a2', 'Task 008 League A2',
      '2026-09-01T11:00:00Z', '{"rec":1,"pass_td":4}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    )
  )
);

select isnt(
  (
    select current_format_context_id
    from public.leagues
    where external_league_id = 'task008-league-a1'
  ),
  (
    select current_format_context_id
    from user_a_initial_pointers
    where external_league_id = 'task008-league-a1'
  ),
  'an exact scoring change advances the current format pointer'
);
select is(
  (
    select count(*)::integer
    from public.league_format_contexts
    where id = (
      select current_format_context_id
      from user_a_initial_pointers
      where external_league_id = 'task008-league-a1'
    )
  ),
  1,
  'the old immutable format context remains after pointer advancement'
);
select results_eq(
  $$
    select count(*)::integer, count(distinct format_context_id)::integer
    from public.league_format_observations as observation
    inner join public.leagues as league on league.id = observation.league_id
    where league.external_league_id = 'task008-league-a1'
  $$,
  $$ values (2, 2) $$,
  'changed exact settings append history instead of overwriting it'
);
select is(
  (
    select current_format_context_id
    from public.leagues
    where external_league_id = 'task008-league-a2'
  ),
  (
    select current_format_context_id
    from user_a_initial_pointers
    where external_league_id = 'task008-league-a2'
  ),
  'a later observation with unchanged exact format reuses the same pointer'
);

create temporary table user_a_current_pointer as
select current_format_context_id
from public.leagues
where external_league_id = 'task008-league-a1';

create temporary table user_a_stale_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);
create temporary table user_a_stale_completion as
select * from public.complete_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  (select sync_run_id from user_a_stale_start),
  pg_temp.nfl_state('2026-09-01T09:00:00Z', 0),
  pg_catalog.jsonb_build_array(
    pg_temp.league_payload(
      'task008-league-a1', 'Stale Task 008 League A1',
      '2026-09-01T09:00:00Z', '{"rec":0,"pass_td":6}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    ),
    pg_temp.league_payload(
      'task008-league-a2', 'Stale Task 008 League A2',
      '2026-09-01T09:00:00Z', '{"rec":0,"pass_td":6}'::jsonb,
      '["QB","RB","WR","TE","FLEX","BN"]'::jsonb,
      '{"type":0,"best_ball":0}'::jsonb,
      12, 'redraft', false, false, false
    )
  )
);

select is(
  (select stale_shared_leagues_skipped from user_a_stale_completion),
  2,
  'older shared representations remain explicitly counted as stale'
);
select is(
  (
    select current_format_context_id
    from public.leagues
    where external_league_id = 'task008-league-a1'
  ),
  (select current_format_context_id from user_a_current_pointer),
  'older discovery cannot regress the current format pointer'
);
select results_eq(
  $$
    select name, scoring_settings, fetched_at
    from public.leagues
    where external_league_id = 'task008-league-a1'
  $$,
  $$ values (
    'Task 008 League A1 Updated'::text,
    '{"rec":0.5,"pass_td":4}'::jsonb,
    '2026-09-01T11:00:00Z'::timestamptz
  ) $$,
  'older discovery cannot regress exact league source state'
);
select is(
  (
    select count(*)::integer
    from public.league_format_observations as observation
    inner join public.leagues as league on league.id = observation.league_id
    where league.external_league_id in (
      'task008-league-a1', 'task008-league-a2'
    )
  ),
  4,
  'older discovery appends no stale format observations'
);

create temporary table user_b_start as
select * from public.start_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000002',
  'a2000000-0000-0000-0000-000000000002'
);
select * from public.complete_sleeper_league_discovery(
  'a1000000-0000-0000-0000-000000000002',
  'a2000000-0000-0000-0000-000000000002',
  (select sync_run_id from user_b_start),
  pg_temp.nfl_state('2026-09-01T12:00:00Z', 3),
  pg_catalog.jsonb_build_array(
    pg_temp.league_payload(
      'task008-league-b1', 'Task 008 League B1',
      '2026-09-01T12:00:00Z', '{"rec":0,"pass_td":6}'::jsonb,
      '["QB","RB","WR","TE","SUPER_FLEX","BN"]'::jsonb,
      '{"type":2,"best_ball":0}'::jsonb,
      10, 'dynasty', false, true, false
    )
  )
);

select throws_ok(
  $$
    update public.league_format_observations
    set observed_at = observed_at
    where league_id = (
      select id from public.leagues
      where external_league_id = 'task008-league-a1'
    )
  $$,
  '55000',
  'League format observations are append-only.',
  'format observations reject updates'
);
select throws_ok(
  $$
    delete from public.league_format_observations
    where league_id = (
      select id from public.leagues
      where external_league_id = 'task008-league-a1'
    )
  $$,
  '55000',
  'League format observations are append-only.',
  'format observations reject deletes'
);

select is(
  (
    select count(*)::integer
    from (values
      ('public.scoring_contexts'),
      ('public.league_format_contexts'),
      ('public.league_format_observations')
    ) as context_table(name)
    where has_table_privilege('service_role', context_table.name, 'select')
      or has_table_privilege('service_role', context_table.name, 'insert')
      or has_table_privilege('service_role', context_table.name, 'update')
      or has_table_privilege('service_role', context_table.name, 'delete')
  ),
  0,
  'service_role has no direct CRUD on context or observation tables'
);
select is(
  (
    select count(*)::integer
    from (values
      ('anon', 'public.scoring_contexts'),
      ('anon', 'public.league_format_contexts'),
      ('anon', 'public.league_format_observations'),
      ('authenticated', 'public.scoring_contexts'),
      ('authenticated', 'public.league_format_contexts'),
      ('authenticated', 'public.league_format_observations')
    ) as denied(role_name, table_name)
    where has_table_privilege(denied.role_name, denied.table_name, 'insert')
      or has_table_privilege(denied.role_name, denied.table_name, 'update')
      or has_table_privilege(denied.role_name, denied.table_name, 'delete')
  ),
  0,
  'browser roles cannot directly mutate context or observation tables'
);
select results_eq(
  $$
    select
      has_column_privilege(
        'authenticated', 'public.scoring_contexts',
        'exact_scoring_settings', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.scoring_contexts',
        'derived_dimensions', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'exact_roster_positions', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'exact_league_settings', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'lineup_profile', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'derived_dimensions', 'select'
      )
  $$,
  $$ values (false, false, false, false, false, false) $$,
  'authenticated grants exclude every sensitive context source column'
);
select results_eq(
  $$
    select
      has_column_privilege(
        'authenticated', 'public.scoring_contexts', 'id', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.scoring_contexts',
        'broad_scoring_format', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts', 'id', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'context_quality', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'league_settings_fingerprint', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'lineup_profile_fingerprint', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_contexts',
        'quarterback_format', 'select'
      ),
      has_column_privilege(
        'authenticated', 'public.league_format_observations', 'id', 'select'
      )
  $$,
  $$ values (true, true, true, true, true, true, true, true) $$,
  'authenticated grants expose only reviewed safe context projections'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-0000-0000-000000000001',
  true
);
select is(
  (select count(id)::integer from public.scoring_contexts),
  2,
  'User A sees safe scoring contexts reachable through its leagues and history'
);
select is(
  (select count(id)::integer from public.league_format_contexts),
  2,
  'User A sees only its reachable current and historical format contexts'
);
select is(
  (select count(id)::integer from public.league_format_observations),
  4,
  'User A sees only observations for its disjoint leagues'
);
select results_eq(
  $$
    select scoring_settings
    from public.leagues
    where external_league_id = 'task008-league-a1'
  $$,
  $$ values ('{"rec":0.5,"pass_td":4}'::jsonb) $$,
  'User A can still read existing exact scoring settings on its visible league'
);
select throws_ok(
  $$ select exact_scoring_settings from public.scoring_contexts $$,
  '42501', null,
  'User A cannot select exact scoring JSON from the context API'
);
select throws_ok(
  $$ select exact_league_settings from public.league_format_contexts $$,
  '42501', null,
  'User A cannot select exact league JSON from the context API'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-0000-0000-000000000002',
  true
);
select is(
  (select count(id)::integer from public.scoring_contexts),
  1,
  'User B sees only its own reachable scoring context'
);
select is(
  (select count(id)::integer from public.league_format_contexts),
  1,
  'User B sees only its own reachable format context'
);
select is(
  (select count(id)::integer from public.league_format_observations),
  1,
  'User B sees only its own format observation'
);
reset role;

set local role anon;
select results_eq(
  $$
    select
      has_column_privilege(
        current_user, 'public.scoring_contexts', 'id', 'select'
      ),
      has_column_privilege(
        current_user, 'public.league_format_contexts', 'id', 'select'
      ),
      has_column_privilege(
        current_user, 'public.league_format_observations', 'id', 'select'
      )
  $$,
  $$ values (false, false, false) $$,
  'anon cannot read any context API table'
);
reset role;

-- Regressions: context work does not claim a full sync or introduce Task 008A.2.
select results_eq(
  $$
    select id, last_synced_at
    from public.fantasy_accounts
    where id in (
      'a2000000-0000-0000-0000-000000000001',
      'a2000000-0000-0000-0000-000000000002'
    )
    order by id
  $$,
  $$ values
    (
      'a2000000-0000-0000-0000-000000000001'::uuid,
      '2026-08-01T00:00:00Z'::timestamptz
    ),
    (
      'a2000000-0000-0000-0000-000000000002'::uuid,
      '2026-08-02T00:00:00Z'::timestamptz
    )
  $$,
  'league discovery leaves fantasy-account last_synced_at unchanged'
);
select is(
  (
    select count(*)::integer
    from public.rosters
  ),
  (select rosters from task008_domain_counts_before),
  'context discovery preserves the pre-existing roster-domain row count'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_account_rosters
  ),
  (select fantasy_account_rosters from task008_domain_counts_before),
  'context discovery preserves the pre-existing ownership row count'
);
select is(
  (
    select count(*)::integer
    from public.roster_players
  ),
  (select roster_players from task008_domain_counts_before),
  'context discovery preserves the pre-existing current-holding row count'
);
select has_function(
  'public', 'start_sleeper_roster_sync', array['uuid', 'uuid'],
  'the existing roster ownership lifecycle remains available'
);
select has_table(
  'public', 'players',
  'canonical player identity remains available'
);
select has_table(
  'public', 'player_external_ids',
  'provider player identity remains available'
);
select is(
  (
    select count(*)::integer
    from information_schema.tables
    where table_schema = 'public'
      and (
        table_name like '%draft%'
        or table_name like '%adp%'
        or table_name like '%statistics%'
        or table_name like '%ranking%'
        or table_name like '%performance%'
        or table_name like '%scoring_result%'
        or table_name in (
          'player_stat_snapshots',
          'player_scoring_snapshots',
          'player_ranking_snapshots',
          'market_adp_snapshots',
          'market_adp_values'
        )
      )
  ),
  0,
  'Task 008A.1 introduces no draft, ADP, statistics, ranking, or performance tables'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'players'
      and (
        column_name like '%adp%'
        or column_name like '%ranking%'
        or column_name like '%value%'
        or column_name in ('rank', 'average_pick')
      )
  ),
  0,
  'canonical player identity gains no mutable ADP, rank, or value field'
);

select * from finish();
rollback;
