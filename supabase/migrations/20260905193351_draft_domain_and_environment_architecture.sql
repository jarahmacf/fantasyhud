-- Task 008A.2 establishes draft identity, historical context, participation,
-- and immutable complete-board storage. Import orchestration remains deferred
-- to Task 008B; every provider-data table below is owner-written only.

create or replace function app_private.draft_order_map_is_safe(
  p_value jsonb,
  p_maximum_entries integer,
  p_maximum_slot integer
)
returns boolean
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_key text;
  v_value jsonb;
  v_value_text text;
begin
  if p_value is null
    or pg_catalog.jsonb_typeof(p_value) <> 'object'
    or p_maximum_entries is null
    or p_maximum_entries <= 0
    or p_maximum_slot is null
    or p_maximum_slot <= 0
    or (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_value)
    ) > p_maximum_entries
  then
    return false;
  end if;

  for v_key, v_value in
    select entry.key, entry.value
    from pg_catalog.jsonb_each(p_value) as entry(key, value)
  loop
    v_value_text := v_value #>> '{}';

    if v_key <> pg_catalog.btrim(v_key)
      or pg_catalog.char_length(v_key) not between 1 and 255
      or v_key ~ '[[:cntrl:]]'
      or pg_catalog.jsonb_typeof(v_value) <> 'number'
      or v_value_text !~ '^[1-9][0-9]*$'
      or pg_catalog.char_length(v_value_text) > 10
      or v_value_text::numeric > p_maximum_slot
    then
      return false;
    end if;
  end loop;

  return true;
exception
  when others then
    return false;
end;
$$;

create or replace function app_private.slot_to_roster_map_is_safe(
  p_value jsonb,
  p_maximum_entries integer,
  p_maximum_slot integer,
  p_maximum_roster_id integer
)
returns boolean
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_key text;
  v_value jsonb;
  v_value_text text;
begin
  if p_value is null
    or pg_catalog.jsonb_typeof(p_value) <> 'object'
    or p_maximum_entries is null
    or p_maximum_entries <= 0
    or p_maximum_slot is null
    or p_maximum_slot <= 0
    or p_maximum_roster_id is null
    or p_maximum_roster_id <= 0
    or (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_value)
    ) > p_maximum_entries
  then
    return false;
  end if;

  for v_key, v_value in
    select entry.key, entry.value
    from pg_catalog.jsonb_each(p_value) as entry(key, value)
  loop
    v_value_text := v_value #>> '{}';

    if v_key !~ '^[1-9][0-9]*$'
      or pg_catalog.char_length(v_key) > 10
      or v_key::numeric > p_maximum_slot
      or pg_catalog.jsonb_typeof(v_value) <> 'number'
      or v_value_text !~ '^[1-9][0-9]*$'
      or pg_catalog.char_length(v_value_text) > 10
      or v_value_text::numeric > p_maximum_roster_id
    then
      return false;
    end if;
  end loop;

  return true;
exception
  when others then
    return false;
end;
$$;

create or replace function app_private.exact_text_array_is_sorted_unique(
  p_values text[],
  p_maximum_count integer
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
    app_private.sorted_exact_text_array_is_safe(
      p_values,
      p_maximum_count
    ),
    false
  );
$$;

create or replace function app_private.classify_sleeper_draft_environment_v1(
  p_provider text,
  p_sport text,
  p_format_fingerprint text,
  p_format_compatibility_key text,
  p_context_resolution_status text,
  p_draft_type text,
  p_draft_pool_type text,
  p_exact_draft_settings jsonb,
  p_team_count integer,
  p_round_count integer,
  p_pick_timer_seconds integer
)
returns table (
  draft_type_family text,
  capital_type text,
  draft_settings_fingerprint text,
  draft_environment_fingerprint text,
  draft_environment_compatibility_key text,
  environment_quality text,
  derived_dimensions jsonb
)
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_teams_valid boolean := true;
  v_rounds_valid boolean := true;
  v_timer_valid boolean := true;
  v_source_value text;
begin
  if p_provider is null
    or p_provider <> 'sleeper'
    or p_sport is null
    or p_sport <> 'nfl'
    or p_context_resolution_status is null
    or p_context_resolution_status not in ('exact', 'partial', 'unknown')
    or p_draft_type is null
    or p_draft_type <> pg_catalog.btrim(p_draft_type)
    or pg_catalog.char_length(p_draft_type) not between 1 and 255
    or p_draft_type ~ '[[:cntrl:]]'
    or p_draft_pool_type is null
    or p_draft_pool_type not in (
      'all_players', 'rookies', 'veterans', 'supplemental', 'unknown'
    )
    or p_exact_draft_settings is null
    or pg_catalog.jsonb_typeof(p_exact_draft_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_exact_draft_settings::text, 'UTF8')
    ) > 131072
    or (p_team_count is not null and p_team_count not between 1 and 1000)
    or (p_round_count is not null and p_round_count not between 1 and 1000)
    or (
      p_pick_timer_seconds is not null
      and p_pick_timer_seconds not between 0 and 86400
    )
    or (
      p_context_resolution_status in ('exact', 'partial')
      and (
        p_format_fingerprint is null
        or p_format_fingerprint !~ '^[0-9a-f]{64}$'
        or p_format_compatibility_key is null
        or p_format_compatibility_key !~ '^[0-9a-f]{64}$'
      )
    )
    or (
      p_context_resolution_status = 'unknown'
      and (
        p_format_fingerprint is not null
        or p_format_compatibility_key is not null
      )
    )
  then
    raise exception using
      errcode = '22023',
      message = 'The Sleeper draft environment input is invalid.';
  end if;

  if p_exact_draft_settings ? 'teams' then
    v_source_value := p_exact_draft_settings ->> 'teams';
    if pg_catalog.jsonb_typeof(p_exact_draft_settings -> 'teams') <> 'number'
      or v_source_value !~ '^[1-9][0-9]*$'
      or pg_catalog.char_length(v_source_value) > 10
    then
      v_teams_valid := false;
    else
      v_teams_valid := v_source_value::numeric between 1 and 1000;
    end if;

    if v_teams_valid then
      if p_team_count is distinct from v_source_value::integer then
        raise exception using
          errcode = '23514',
          message = 'The typed draft team count disagrees with exact settings.';
      end if;
    end if;
  end if;

  if p_exact_draft_settings ? 'rounds' then
    v_source_value := p_exact_draft_settings ->> 'rounds';
    if pg_catalog.jsonb_typeof(p_exact_draft_settings -> 'rounds') <> 'number'
      or v_source_value !~ '^[1-9][0-9]*$'
      or pg_catalog.char_length(v_source_value) > 10
    then
      v_rounds_valid := false;
    else
      v_rounds_valid := v_source_value::numeric between 1 and 1000;
    end if;

    if v_rounds_valid then
      if p_round_count is distinct from v_source_value::integer then
        raise exception using
          errcode = '23514',
          message = 'The typed draft round count disagrees with exact settings.';
      end if;
    end if;
  end if;

  if p_exact_draft_settings ? 'pick_timer' then
    v_source_value := p_exact_draft_settings ->> 'pick_timer';
    if pg_catalog.jsonb_typeof(
      p_exact_draft_settings -> 'pick_timer'
    ) <> 'number'
      or v_source_value !~ '^(0|[1-9][0-9]*)$'
      or pg_catalog.char_length(v_source_value) > 10
    then
      v_timer_valid := false;
    else
      v_timer_valid := v_source_value::numeric between 0 and 86400;
    end if;

    if v_timer_valid then
      if p_pick_timer_seconds is distinct from v_source_value::integer then
        raise exception using
          errcode = '23514',
          message = 'The typed draft timer disagrees with exact settings.';
      end if;
    end if;
  end if;

  draft_type_family := case p_draft_type
    when 'snake' then 'snake'
    when 'linear' then 'linear'
    when 'auction' then 'auction'
    else 'unknown'
  end;

  capital_type := case
    when draft_type_family in ('snake', 'linear') then 'overall_pick'
    when draft_type_family = 'auction' then 'auction_value'
    else 'unknown'
  end;

  draft_settings_fingerprint := app_private.context_sha256(
    'draft_settings:' || p_provider || ':' || p_sport,
    1,
    p_exact_draft_settings
  );

  draft_environment_fingerprint := app_private.context_sha256(
    'draft_environment:' || p_provider || ':' || p_sport,
    1,
    pg_catalog.jsonb_build_object(
      'format_fingerprint', p_format_fingerprint,
      'context_resolution_status', p_context_resolution_status,
      'draft_type', p_draft_type,
      'draft_pool_type', p_draft_pool_type,
      'capital_type', capital_type,
      'draft_settings_fingerprint', draft_settings_fingerprint,
      'team_count', p_team_count,
      'round_count', p_round_count,
      'pick_timer_seconds', p_pick_timer_seconds
    )
  );

  draft_environment_compatibility_key := app_private.context_sha256(
    'fantasyhud:' || p_sport || ':draft_environment_compatibility',
    1,
    pg_catalog.jsonb_build_object(
      'format_compatibility_key', p_format_compatibility_key,
      'context_resolution_status', p_context_resolution_status,
      'draft_type_family', draft_type_family,
      'draft_pool_type', p_draft_pool_type,
      'capital_type', capital_type,
      'team_count', p_team_count,
      'round_count', p_round_count,
      'draft_settings_fingerprint', draft_settings_fingerprint
    )
  );

  environment_quality := case
    when p_context_resolution_status = 'exact'
      and draft_type_family <> 'unknown'
      and capital_type <> 'unknown'
      and p_draft_pool_type <> 'unknown'
      and p_team_count is not null
      and p_round_count is not null
      and v_teams_valid
      and v_rounds_valid
      and v_timer_valid
      then 'exact'
    when p_context_resolution_status = 'partial'
      and draft_type_family <> 'unknown'
      and capital_type <> 'unknown'
      and p_draft_pool_type <> 'unknown'
      and p_team_count is not null
      and p_round_count is not null
      and v_teams_valid
      and v_rounds_valid
      and v_timer_valid
      then 'partial'
    else 'unknown'
  end;

  derived_dimensions := pg_catalog.jsonb_build_object(
    'draft_type_family', draft_type_family,
    'capital_type', capital_type,
    'draft_pool_type', p_draft_pool_type,
    'team_count', p_team_count,
    'round_count', p_round_count,
    'pick_timer_seconds', p_pick_timer_seconds,
    'source_dimension_values_valid',
      v_teams_valid and v_rounds_valid and v_timer_valid
  );

  return next;
end;
$$;

revoke all on function app_private.draft_order_map_is_safe(
  jsonb,
  integer,
  integer
) from public, anon, authenticated, service_role;
revoke all on function app_private.slot_to_roster_map_is_safe(
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;
revoke all on function app_private.exact_text_array_is_sorted_unique(
  text[],
  integer
) from public, anon, authenticated, service_role;
revoke all on function app_private.classify_sleeper_draft_environment_v1(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;

comment on function app_private.draft_order_map_is_safe(
  jsonb,
  integer,
  integer
) is
  'Owner-only immutable validator for exact provider-user-to-draft-slot maps.';
comment on function app_private.slot_to_roster_map_is_safe(
  jsonb,
  integer,
  integer,
  integer
) is
  'Owner-only immutable validator for canonical slot-to-provider-roster maps.';
comment on function app_private.exact_text_array_is_sorted_unique(
  text[],
  integer
) is
  'Owner-only immutable validator for bounded, C-sorted, unique exact source IDs.';
comment on function app_private.classify_sleeper_draft_environment_v1(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  integer,
  integer,
  integer
) is
  'Owner-only immutable Sleeper/NFL v1 classifier for exact and compatible draft-environment identity.';

alter table public.leagues
add column draft_collection_fetched_at timestamptz,
add column draft_collection_count integer,
add column draft_collection_fingerprint text;

alter table public.leagues
add constraint leagues_draft_collection_state_is_valid check (
  (
    draft_collection_fetched_at is null
    and draft_collection_count is null
    and draft_collection_fingerprint is null
  )
  or (
    draft_collection_fetched_at is not null
    and pg_catalog.isfinite(draft_collection_fetched_at)
    and draft_collection_count is not null
    and draft_collection_count between 0 and 1000
    and draft_collection_fingerprint is not null
    and draft_collection_fingerprint ~ '^[0-9a-f]{64}$'
  )
),
add constraint leagues_id_provider_sport_season_key unique (
  id,
  provider,
  sport,
  season
);

comment on column public.leagues.draft_collection_fetched_at is
  'Latest accepted complete league-drafts collection observation time.';
comment on column public.leagues.draft_collection_count is
  'Cardinality of the latest accepted complete league-drafts collection.';
comment on column public.leagues.draft_collection_fingerprint is
  'SHA-256 of C-sorted exact canonical draft IDs under the fixed version-one league collection contract.';

create table public.fantasy_account_draft_collections (
  fantasy_account_id uuid not null
    references public.fantasy_accounts(id) on delete cascade,
  sport text not null,
  season integer not null,
  source_fetched_at timestamptz not null,
  source_draft_count integer not null,
  collection_fingerprint text not null,
  source_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fantasy_account_draft_collections_pkey primary key (
    fantasy_account_id,
    sport,
    season
  ),
  constraint fantasy_account_draft_collections_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint fantasy_account_draft_collections_season_is_bounded check (
    season between 1900 and 2999
  ),
  constraint fantasy_account_draft_collections_count_is_bounded check (
    source_draft_count between 0 and 10000
  ),
  constraint fantasy_account_draft_collections_fingerprint_is_sha256 check (
    collection_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  constraint fantasy_account_draft_collections_metadata_is_bounded_object check (
    pg_catalog.jsonb_typeof(source_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(source_metadata::text, 'UTF8')
    ) <= 32768
  ),
  constraint fantasy_account_draft_collections_timestamps_are_finite check (
    pg_catalog.isfinite(source_fetched_at)
    and pg_catalog.isfinite(created_at)
    and pg_catalog.isfinite(updated_at)
  )
);

comment on table public.fantasy_account_draft_collections is
  'Latest complete provider user-drafts collection accepted for one tracked account, sport, and season.';
comment on column public.fantasy_account_draft_collections.collection_fingerprint is
  'SHA-256 of C-sorted exact canonical draft IDs under the fixed version-one account collection contract.';

create index fantasy_account_draft_collections_sport_season_fetched_idx
  on public.fantasy_account_draft_collections (
    sport,
    season,
    source_fetched_at desc
  );

create trigger fantasy_account_draft_collections_set_updated_at
before update on public.fantasy_account_draft_collections
for each row execute function app_private.set_updated_at();

alter table public.league_format_observations
add constraint league_format_observations_league_context_time_key unique (
  league_id,
  format_context_id,
  observed_at
);

create table public.drafts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  external_draft_id text not null,
  context_type text not null,
  league_id uuid,
  sport text not null,
  season integer not null,
  season_type text not null,
  draft_type text not null,
  draft_type_family text not null,
  status text not null,
  name text,
  description text,
  team_count integer,
  round_count integer,
  pick_timer_seconds integer,
  start_time timestamptz,
  provider_created_at timestamptz,
  last_picked_at timestamptz,
  last_message_at timestamptz,
  last_message_id text,
  source_creators text[],
  source_draft_order jsonb,
  source_slot_to_roster_id jsonb,
  settings jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  league_format_context_id uuid,
  context_resolution_status text not null,
  context_observed_at timestamptz,
  draft_environment_version integer not null,
  draft_settings_fingerprint text not null,
  draft_environment_fingerprint text not null,
  draft_environment_compatibility_key text not null,
  draft_environment_quality text not null,
  draft_pool_type text not null,
  capital_type text not null,
  context_metadata jsonb not null default '{}'::jsonb,
  draft_fetched_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  board_state text not null default 'not_fetched',
  board_fetched_at timestamptz,
  board_slot_count integer,
  board_pick_count integer,
  board_fingerprint_version integer,
  board_fingerprint text,
  board_finalized_at timestamptz,
  contains_keeper_picks boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drafts_provider_external_draft_id_key unique (
    provider,
    external_draft_id
  ),
  constraint drafts_id_league_key unique (id, league_id),
  constraint drafts_league_namespace_fkey foreign key (
    league_id,
    provider,
    sport,
    season
  ) references public.leagues (id, provider, sport, season) on delete restrict,
  constraint drafts_context_observation_fkey foreign key (
    league_id,
    league_format_context_id,
    context_observed_at
  ) references public.league_format_observations (
    league_id,
    format_context_id,
    observed_at
  ) on delete restrict,
  constraint drafts_namespace_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
    and sport ~ '^[a-z][a-z0-9_-]{0,31}$'
    and season between 1900 and 2999
  ),
  constraint drafts_source_tokens_are_exact check (
    external_draft_id = pg_catalog.btrim(external_draft_id)
    and pg_catalog.char_length(external_draft_id) between 1 and 255
    and external_draft_id !~ '[[:cntrl:]]'
    and season_type = pg_catalog.btrim(season_type)
    and pg_catalog.char_length(season_type) between 1 and 255
    and season_type !~ '[[:cntrl:]]'
    and draft_type = pg_catalog.btrim(draft_type)
    and pg_catalog.char_length(draft_type) between 1 and 255
    and draft_type !~ '[[:cntrl:]]'
    and status = pg_catalog.btrim(status)
    and pg_catalog.char_length(status) between 1 and 255
    and status !~ '[[:cntrl:]]'
    and (
      last_message_id is null
      or (
        last_message_id = pg_catalog.btrim(last_message_id)
        and pg_catalog.char_length(last_message_id) between 1 and 255
        and last_message_id !~ '[[:cntrl:]]'
      )
    )
  ),
  constraint drafts_context_type_is_valid check (
    context_type in ('league', 'standalone', 'unknown')
    and (context_type <> 'league' or league_id is not null)
    and (context_type <> 'standalone' or league_id is null)
  ),
  constraint drafts_display_fields_are_safe check (
    (
      name is null
      or (
        name = pg_catalog.btrim(name)
        and pg_catalog.char_length(name) between 1 and 255
        and name !~ '[[:cntrl:]]'
      )
    )
    and (
      description is null
      or (
        description = pg_catalog.btrim(description)
        and pg_catalog.char_length(description) between 1 and 4096
        and description !~ '[[:cntrl:]]'
      )
    )
  ),
  constraint drafts_typed_dimensions_are_bounded check (
    (team_count is null or team_count between 1 and 1000)
    and (round_count is null or round_count between 1 and 1000)
    and (
      pick_timer_seconds is null
      or pick_timer_seconds between 0 and 86400
    )
  ),
  constraint drafts_source_creators_are_safe check (
    source_creators is null
    or app_private.exact_text_array_is_safe(source_creators, 1000, true)
  ),
  constraint drafts_source_draft_order_is_safe check (
    source_draft_order is null
    or app_private.draft_order_map_is_safe(source_draft_order, 1000, 1000)
  ),
  constraint drafts_source_slot_rosters_are_safe check (
    source_slot_to_roster_id is null
    or app_private.slot_to_roster_map_is_safe(
      source_slot_to_roster_id,
      1000,
      1000,
      1000000
    )
  ),
  constraint drafts_json_objects_are_bounded check (
    pg_catalog.jsonb_typeof(settings) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(settings::text, 'UTF8')
    ) <= 131072
    and pg_catalog.jsonb_typeof(metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(metadata::text, 'UTF8')
    ) <= 131072
    and pg_catalog.jsonb_typeof(context_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(context_metadata::text, 'UTF8')
    ) <= 32768
  ),
  constraint drafts_context_resolution_is_valid check (
    (
      context_resolution_status = 'unknown'
      and league_format_context_id is null
      and context_observed_at is null
    )
    or (
      context_resolution_status in ('exact', 'partial')
      and context_type = 'league'
      and league_id is not null
      and league_format_context_id is not null
      and context_observed_at is not null
    )
  ),
  constraint drafts_exact_context_precedes_anchor check (
    context_resolution_status <> 'exact'
    or (
      coalesce(start_time, provider_created_at) is not null
      and context_observed_at <= coalesce(
        start_time,
        provider_created_at
      )
    )
  ),
  constraint drafts_environment_is_valid check (
    draft_environment_version between 1 and 1000000
    and draft_settings_fingerprint ~ '^[0-9a-f]{64}$'
    and draft_environment_fingerprint ~ '^[0-9a-f]{64}$'
    and draft_environment_compatibility_key ~ '^[0-9a-f]{64}$'
    and draft_type_family in ('snake', 'linear', 'auction', 'unknown')
    and draft_pool_type in (
      'all_players', 'rookies', 'veterans', 'supplemental', 'unknown'
    )
    and capital_type in ('overall_pick', 'auction_value', 'unknown')
    and draft_environment_quality in ('exact', 'partial', 'unknown')
  ),
  constraint drafts_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint drafts_timestamps_are_finite check (
    (start_time is null or pg_catalog.isfinite(start_time))
    and (
      provider_created_at is null
      or pg_catalog.isfinite(provider_created_at)
    )
    and (last_picked_at is null or pg_catalog.isfinite(last_picked_at))
    and (last_message_at is null or pg_catalog.isfinite(last_message_at))
    and (
      context_observed_at is null
      or pg_catalog.isfinite(context_observed_at)
    )
    and pg_catalog.isfinite(draft_fetched_at)
    and pg_catalog.isfinite(first_seen_at)
    and pg_catalog.isfinite(last_seen_at)
    and (removed_at is null or pg_catalog.isfinite(removed_at))
    and (board_fetched_at is null or pg_catalog.isfinite(board_fetched_at))
    and (
      board_finalized_at is null
      or pg_catalog.isfinite(board_finalized_at)
    )
    and pg_catalog.isfinite(created_at)
    and pg_catalog.isfinite(updated_at)
  ),
  constraint drafts_board_state_is_valid check (
    (
      board_state = 'not_fetched'
      and board_fetched_at is null
      and board_slot_count is null
      and board_pick_count is null
      and board_fingerprint_version is null
      and board_fingerprint is null
      and board_finalized_at is null
      and contains_keeper_picks is null
    )
    or (
      board_state = 'mutable'
      and board_fetched_at is not null
      and board_slot_count is not null
      and board_slot_count between 0 and 1000
      and board_pick_count is not null
      and board_pick_count between 0 and 1000000
      and board_fingerprint_version is not null
      and board_fingerprint_version between 1 and 1000000
      and board_fingerprint is not null
      and board_fingerprint ~ '^[0-9a-f]{64}$'
      and board_finalized_at is null
      and contains_keeper_picks is not null
    )
    or (
      board_state = 'finalized'
      and status = 'complete'
      and board_fetched_at is not null
      and board_slot_count is not null
      and board_slot_count between 0 and 1000
      and board_pick_count is not null
      and board_pick_count between 0 and 1000000
      and board_fingerprint_version is not null
      and board_fingerprint_version between 1 and 1000000
      and board_fingerprint is not null
      and board_fingerprint ~ '^[0-9a-f]{64}$'
      and board_finalized_at is not null
      and board_finalized_at >= board_fetched_at
      and contains_keeper_picks is not null
    )
  )
);

comment on table public.drafts is
  'One shared provider draft with truthful historical context and a protected complete-board lifecycle.';
comment on column public.drafts.source_creators is
  'Exact ordered provider creator IDs; null means absent and an empty array means explicitly empty. Server-only.';
comment on column public.drafts.source_draft_order is
  'Exact provider user-to-slot map. Server-only and distinct from normalized draft slots.';
comment on column public.drafts.source_slot_to_roster_id is
  'Exact provider slot-to-roster map. Server-only and distinct from canonical roster resolution.';
comment on column public.drafts.draft_environment_compatibility_key is
  'Conservative FANTASY HUD v1 semantic key; its exact settings component intentionally prevents unreviewed broad matching.';
comment on column public.drafts.board_fingerprint is
  'Versioned lifecycle attestation supplied by a future reviewed import RPC; this architecture validates shape and finalized counts but does not recompute the full board projection.';

create index drafts_league_season_removed_idx
  on public.drafts (league_id, season, removed_at);
create index drafts_season_sport_status_idx
  on public.drafts (season, sport, status);
create index drafts_format_context_season_idx
  on public.drafts (league_format_context_id, season);
create index drafts_environment_fingerprint_idx
  on public.drafts (draft_environment_fingerprint);
create index drafts_environment_compatibility_season_idx
  on public.drafts (draft_environment_compatibility_key, season);
create index drafts_environment_dimensions_season_idx
  on public.drafts (
    draft_pool_type,
    draft_type_family,
    capital_type,
    season
  );
create index drafts_board_state_finalized_idx
  on public.drafts (board_state, board_finalized_at);
create index drafts_fetched_at_idx on public.drafts (draft_fetched_at);

create trigger drafts_set_updated_at
before update on public.drafts
for each row execute function app_private.set_updated_at();

create table public.draft_slots (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references public.drafts(id) on delete cascade,
  draft_slot integer not null,
  source_user_ids text[],
  external_roster_id integer,
  roster_id uuid references public.rosters(id) on delete restrict,
  source_metadata jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint draft_slots_draft_slot_key unique (draft_id, draft_slot),
  constraint draft_slots_id_draft_key unique (id, draft_id),
  constraint draft_slots_slot_is_bounded check (
    draft_slot between 1 and 1000
  ),
  constraint draft_slots_external_roster_id_is_bounded check (
    external_roster_id is null
    or external_roster_id between 1 and 1000000
  ),
  constraint draft_slots_source_users_are_safe check (
    source_user_ids is null
    or app_private.exact_text_array_is_sorted_unique(
      source_user_ids,
      1000
    )
  ),
  constraint draft_slots_metadata_is_bounded_object check (
    pg_catalog.jsonb_typeof(source_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(source_metadata::text, 'UTF8')
    ) <= 32768
  ),
  constraint draft_slots_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint draft_slots_timestamps_are_finite check (
    pg_catalog.isfinite(fetched_at)
    and pg_catalog.isfinite(first_seen_at)
    and pg_catalog.isfinite(last_seen_at)
    and (removed_at is null or pg_catalog.isfinite(removed_at))
    and pg_catalog.isfinite(created_at)
    and pg_catalog.isfinite(updated_at)
  )
);

comment on table public.draft_slots is
  'One normalized exact board slot in one provider draft; several source users may share one slot.';
comment on column public.draft_slots.source_user_ids is
  'C-sorted unique exact provider user IDs assigned to this slot. Server-only.';

create index draft_slots_draft_removed_slot_idx
  on public.draft_slots (draft_id, removed_at, draft_slot);
create index draft_slots_roster_draft_idx
  on public.draft_slots (roster_id, draft_id)
  where roster_id is not null;
create index draft_slots_external_roster_draft_idx
  on public.draft_slots (external_roster_id, draft_id)
  where external_roster_id is not null;

create trigger draft_slots_set_updated_at
before update on public.draft_slots
for each row execute function app_private.set_updated_at();

create table public.fantasy_account_drafts (
  id uuid primary key default gen_random_uuid(),
  fantasy_account_id uuid not null
    references public.fantasy_accounts(id) on delete cascade,
  draft_id uuid not null references public.drafts(id) on delete cascade,
  participation_status text not null,
  draft_slot integer,
  source_metadata jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fantasy_account_drafts_account_draft_key unique (
    fantasy_account_id,
    draft_id
  ),
  constraint fantasy_account_drafts_slot_fkey foreign key (
    draft_id,
    draft_slot
  ) references public.draft_slots (draft_id, draft_slot) on delete restrict,
  constraint fantasy_account_drafts_participation_is_valid check (
    (
      participation_status = 'confirmed'
      and draft_slot is not null
    )
    or (
      participation_status in ('not_participant', 'unresolved')
      and draft_slot is null
    )
  ),
  constraint fantasy_account_drafts_metadata_is_bounded_object check (
    pg_catalog.jsonb_typeof(source_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(source_metadata::text, 'UTF8')
    ) <= 32768
  ),
  constraint fantasy_account_drafts_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint fantasy_account_drafts_timestamps_are_finite check (
    pg_catalog.isfinite(observed_at)
    and pg_catalog.isfinite(first_seen_at)
    and pg_catalog.isfinite(last_seen_at)
    and (removed_at is null or pg_catalog.isfinite(removed_at))
    and pg_catalog.isfinite(created_at)
    and pg_catalog.isfinite(updated_at)
  )
);

comment on table public.fantasy_account_drafts is
  'Explicit tri-state participation resolution for one tracked fantasy account and one shared draft.';
comment on column public.fantasy_account_drafts.source_metadata is
  'Bounded server-only participation evidence; never an authenticated browser projection.';

create index fantasy_account_drafts_account_status_removed_idx
  on public.fantasy_account_drafts (
    fantasy_account_id,
    participation_status,
    removed_at
  );
create index fantasy_account_drafts_draft_status_removed_idx
  on public.fantasy_account_drafts (
    draft_id,
    participation_status,
    removed_at
  );
create index fantasy_account_drafts_visible_draft_account_idx
  on public.fantasy_account_drafts (draft_id, fantasy_account_id)
  where participation_status = 'confirmed' and removed_at is null;

create trigger fantasy_account_drafts_set_updated_at
before update on public.fantasy_account_drafts
for each row execute function app_private.set_updated_at();

create table public.draft_picks (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null,
  draft_slot integer not null,
  pick_no integer not null,
  round integer not null,
  player_id uuid not null references public.players(id) on delete restrict,
  source_player_external_id_id uuid not null,
  picked_by_external_user_id text,
  external_roster_id integer,
  roster_id uuid references public.rosters(id) on delete restrict,
  is_keeper boolean,
  auction_amount numeric,
  picked_at timestamptz,
  player_display_name_at_draft text,
  player_entity_type_at_draft text not null,
  player_primary_position_at_draft text,
  player_fantasy_positions_at_draft text[],
  nfl_team_at_draft text,
  player_status_at_draft text,
  injury_status_at_draft text,
  source_player_metadata jsonb not null default '{}'::jsonb,
  source_metadata jsonb not null default '{}'::jsonb,
  source_fetched_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint draft_picks_slot_fkey foreign key (
    draft_id,
    draft_slot
  ) references public.draft_slots (draft_id, draft_slot) on delete restrict,
  constraint draft_picks_mapping_player_fkey foreign key (
    source_player_external_id_id,
    player_id
  ) references public.player_external_ids (id, player_id) on delete restrict,
  constraint draft_picks_draft_pick_key unique (draft_id, pick_no),
  constraint draft_picks_coordinates_are_bounded check (
    draft_slot between 1 and 1000
    and pick_no between 1 and 1000000
    and round between 1 and 1000
  ),
  constraint draft_picks_external_roster_id_is_bounded check (
    external_roster_id is null
    or external_roster_id between 1 and 1000000
  ),
  constraint draft_picks_picked_by_is_exact check (
    picked_by_external_user_id is null
    or (
      picked_by_external_user_id = pg_catalog.btrim(
        picked_by_external_user_id
      )
      and pg_catalog.char_length(picked_by_external_user_id)
        between 1 and 255
      and picked_by_external_user_id !~ '[[:cntrl:]]'
    )
  ),
  constraint draft_picks_auction_amount_is_bounded check (
    auction_amount is null
    or auction_amount between 0::numeric and 1000000000::numeric
  ),
  constraint draft_picks_player_entity_type_is_known check (
    player_entity_type_at_draft in ('player', 'team_defense', 'unknown')
  ),
  constraint draft_picks_player_tokens_are_safe check (
    (
      player_primary_position_at_draft is null
      or player_primary_position_at_draft ~ '^[A-Z0-9_]{1,32}$'
    )
    and (
      nfl_team_at_draft is null
      or nfl_team_at_draft ~ '^[A-Z0-9_]{1,32}$'
    )
  ),
  constraint draft_picks_fantasy_positions_are_safe check (
    player_fantasy_positions_at_draft is null
    or (
      app_private.exact_text_array_is_safe(
        player_fantasy_positions_at_draft,
        32,
        true
      )
      and app_private.upper_token_array_is_safe(
        player_fantasy_positions_at_draft
      )
    )
  ),
  constraint draft_picks_historical_display_is_safe check (
    (
      player_display_name_at_draft is null
      or (
        player_display_name_at_draft = pg_catalog.btrim(
          player_display_name_at_draft
        )
        and pg_catalog.char_length(player_display_name_at_draft)
          between 1 and 255
        and player_display_name_at_draft !~ '[[:cntrl:]]'
      )
    )
    and (
      player_status_at_draft is null
      or (
        player_status_at_draft = pg_catalog.btrim(player_status_at_draft)
        and pg_catalog.char_length(player_status_at_draft) between 1 and 64
        and player_status_at_draft !~ '[[:cntrl:]]'
      )
    )
    and (
      injury_status_at_draft is null
      or (
        injury_status_at_draft = pg_catalog.btrim(injury_status_at_draft)
        and pg_catalog.char_length(injury_status_at_draft) between 1 and 64
        and injury_status_at_draft !~ '[[:cntrl:]]'
      )
    )
  ),
  constraint draft_picks_metadata_is_bounded check (
    pg_catalog.jsonb_typeof(source_player_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(source_player_metadata::text, 'UTF8')
    ) <= 65536
    and pg_catalog.jsonb_typeof(source_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(source_metadata::text, 'UTF8')
    ) <= 32768
  ),
  constraint draft_picks_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint draft_picks_timestamps_are_finite check (
    (picked_at is null or pg_catalog.isfinite(picked_at))
    and pg_catalog.isfinite(source_fetched_at)
    and pg_catalog.isfinite(first_seen_at)
    and pg_catalog.isfinite(last_seen_at)
    and (removed_at is null or pg_catalog.isfinite(removed_at))
    and pg_catalog.isfinite(created_at)
    and pg_catalog.isfinite(updated_at)
  )
);

comment on table public.draft_picks is
  'One exact overall selection in a provider draft, with canonical identity and immutable draft-time player context after finalization.';
comment on column public.draft_picks.picked_by_external_user_id is
  'Exact provider participant ID normalized from source; server-only.';
comment on column public.draft_picks.is_keeper is
  'Nullable completed-pick keeper truth; null, false, and true remain distinct.';
comment on column public.draft_picks.auction_amount is
  'Optional verified auction value, conservatively bounded to one billion; never inferred from pick order.';

create index draft_picks_board_coordinate_idx
  on public.draft_picks (draft_id, round, draft_slot, pick_no);
create index draft_picks_player_draft_idx
  on public.draft_picks (player_id, draft_id);
create index draft_picks_source_mapping_draft_idx
  on public.draft_picks (source_player_external_id_id, draft_id);
create index draft_picks_roster_draft_idx
  on public.draft_picks (roster_id, draft_id)
  where roster_id is not null;
create index draft_picks_nfl_team_draft_idx
  on public.draft_picks (nfl_team_at_draft, draft_id)
  where nfl_team_at_draft is not null;
create index draft_picks_primary_position_draft_idx
  on public.draft_picks (player_primary_position_at_draft, draft_id)
  where player_primary_position_at_draft is not null;

create trigger draft_picks_set_updated_at
before update on public.draft_picks
for each row execute function app_private.set_updated_at();

create or replace function app_private.enforce_draft_board_lifecycle()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_format_fingerprint text;
  v_format_compatibility_key text;
  v_classification record;
  v_active_slot_count integer;
  v_active_pick_count integer;
  v_contains_keeper_picks boolean;
  v_is_finalizing boolean := false;
begin
  if new.context_resolution_status in ('exact', 'partial') then
    select
      format.format_fingerprint,
      format.compatibility_key
    into
      v_format_fingerprint,
      v_format_compatibility_key
    from public.league_format_observations as observation
    inner join public.league_format_contexts as format
      on format.id = observation.format_context_id
    where observation.league_id = new.league_id
      and observation.format_context_id = new.league_format_context_id
      and observation.observed_at = new.context_observed_at;

    if not found then
      raise exception using
        errcode = '23514',
        message = 'The draft context observation is inconsistent.';
    end if;
  else
    v_format_fingerprint := null;
    v_format_compatibility_key := null;
  end if;

  if new.draft_environment_version = 1 then
    select classified.*
    into v_classification
    from app_private.classify_sleeper_draft_environment_v1(
      new.provider,
      new.sport,
      v_format_fingerprint,
      v_format_compatibility_key,
      new.context_resolution_status,
      new.draft_type,
      new.draft_pool_type,
      new.settings,
      new.team_count,
      new.round_count,
      new.pick_timer_seconds
    ) as classified;

    if new.draft_type_family is distinct from
        v_classification.draft_type_family
      or new.capital_type is distinct from v_classification.capital_type
      or new.draft_settings_fingerprint is distinct from
        v_classification.draft_settings_fingerprint
      or new.draft_environment_fingerprint is distinct from
        v_classification.draft_environment_fingerprint
      or new.draft_environment_compatibility_key is distinct from
        v_classification.draft_environment_compatibility_key
      or new.draft_environment_quality is distinct from
        v_classification.environment_quality
    then
      raise exception using
        errcode = '23514',
        message = 'The draft environment does not match normalization version one.';
    end if;
  elsif new.draft_environment_quality = 'exact' then
    raise exception using
      errcode = '23514',
      message = 'Exact draft environment requires a reviewed classifier.';
  end if;

  if tg_op = 'UPDATE' then
    if old.board_state = 'finalized' then
      if new.last_seen_at < old.last_seen_at then
        raise exception using
          errcode = '55000',
          message = 'A finalized draft observation cannot move backward.';
      end if;

      if (
        pg_catalog.to_jsonb(new)
          - array['last_seen_at', 'removed_at', 'updated_at']::text[]
      ) is distinct from (
        pg_catalog.to_jsonb(old)
          - array['last_seen_at', 'removed_at', 'updated_at']::text[]
      ) then
        raise exception using
          errcode = '55000',
          message = 'A finalized draft board is immutable.';
      end if;

      return new;
    end if;

    if old.board_state = 'mutable' and new.board_state = 'not_fetched' then
      raise exception using
        errcode = '55000',
        message = 'A draft board cannot regress.';
    end if;

    if old.board_fetched_at is not null
      and (
        new.board_fetched_at is null
        or new.board_fetched_at < old.board_fetched_at
      )
    then
      raise exception using
        errcode = '55000',
        message = 'A draft board observation cannot move backward.';
    end if;

    if old.board_state = 'mutable'
      and new.board_state = 'mutable'
      and (
        new.board_slot_count is distinct from old.board_slot_count
        or new.board_pick_count is distinct from old.board_pick_count
        or new.board_fingerprint_version is distinct from
          old.board_fingerprint_version
        or new.board_fingerprint is distinct from old.board_fingerprint
        or new.contains_keeper_picks is distinct from old.contains_keeper_picks
      )
      and new.board_fetched_at <= old.board_fetched_at
    then
      raise exception using
        errcode = '55000',
        message = 'A changed mutable board requires a newer observation.';
    end if;

    if old.board_state = 'not_fetched'
      and new.board_state = 'finalized'
      and (
        new.board_slot_count <> 0
        or new.board_pick_count <> 0
      )
    then
      raise exception using
        errcode = '55000',
        message = 'A nonempty board must be mutable before finalization.';
    end if;
  end if;

  if tg_op = 'INSERT' then
    v_is_finalizing := new.board_state = 'finalized';
  elsif tg_op = 'UPDATE' then
    v_is_finalizing := new.board_state = 'finalized'
      and old.board_state is distinct from 'finalized';
  end if;

  if v_is_finalizing then
    select pg_catalog.count(*)::integer
    into v_active_slot_count
    from public.draft_slots as slot
    where slot.draft_id = new.id
      and slot.removed_at is null;

    select
      pg_catalog.count(*)::integer,
      coalesce(
        pg_catalog.bool_or(pick.is_keeper is true),
        false
      )
    into v_active_pick_count, v_contains_keeper_picks
    from public.draft_picks as pick
    where pick.draft_id = new.id
      and pick.removed_at is null;

    if exists (
      select 1
      from public.draft_picks as pick
      left join public.draft_slots as slot
        on slot.draft_id = pick.draft_id
        and slot.draft_slot = pick.draft_slot
        and slot.removed_at is null
      where pick.draft_id = new.id
        and pick.removed_at is null
        and slot.id is null
    ) then
      raise exception using
        errcode = '23514',
        message = 'An active draft pick lacks an active draft slot.';
    end if;

    if new.board_slot_count is distinct from v_active_slot_count
      or new.board_pick_count is distinct from v_active_pick_count
      or new.contains_keeper_picks is distinct from v_contains_keeper_picks
    then
      raise exception using
        errcode = '23514',
        message = 'The finalized draft board summary is inconsistent.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function app_private.protect_finalized_draft_delete()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if old.board_state = 'finalized' then
    raise exception using
      errcode = '55000',
      message = 'A finalized draft cannot be deleted.';
  end if;

  return old;
end;
$$;

create or replace function app_private.reject_finalized_draft_child_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_draft_id uuid;
  v_board_state text;
  v_league_id uuid;
  v_provider text;
  v_sport text;
begin
  if tg_op = 'UPDATE' then
    if new.draft_id is distinct from old.draft_id then
      raise exception using
        errcode = '55000',
        message = 'A draft child cannot move between drafts.';
    end if;
  end if;

  if tg_op = 'DELETE' then
    v_draft_id := old.draft_id;
  else
    v_draft_id := new.draft_id;
  end if;

  select
    draft.board_state,
    draft.league_id,
    draft.provider,
    draft.sport
  into
    v_board_state,
    v_league_id,
    v_provider,
    v_sport
  from public.drafts as draft
  where draft.id = v_draft_id
  for update;

  if not found then
    if tg_op = 'DELETE' then
      return old;
    end if;

    raise exception using
      errcode = '23503',
      message = 'The parent draft does not exist.';
  end if;

  if v_board_state <> 'mutable' then
    raise exception using
      errcode = '55000',
      message = 'Draft children may change only while the board is mutable.';
  end if;

  if tg_table_name = 'draft_slots' and tg_op <> 'DELETE' then
    if new.roster_id is not null
      and (
        v_league_id is null
        or new.external_roster_id is null
        or not exists (
          select 1
          from public.rosters as roster
          where roster.id = new.roster_id
            and roster.league_id = v_league_id
            and roster.external_roster_id = new.external_roster_id
        )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'The draft slot roster resolution is inconsistent.';
    end if;

    if new.removed_at is not null
      and (
        exists (
          select 1
          from public.draft_picks as pick
          where pick.draft_id = new.draft_id
            and pick.draft_slot = new.draft_slot
            and pick.removed_at is null
        )
        or exists (
          select 1
          from public.fantasy_account_drafts as participation
          where participation.draft_id = new.draft_id
            and participation.draft_slot = new.draft_slot
            and participation.participation_status = 'confirmed'
            and participation.removed_at is null
        )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'An active draft relationship still references this slot.';
    end if;
  elsif tg_table_name = 'draft_picks' and tg_op <> 'DELETE' then
    if new.removed_at is null and not exists (
      select 1
      from public.draft_slots as slot
      where slot.draft_id = new.draft_id
        and slot.draft_slot = new.draft_slot
        and slot.removed_at is null
    ) then
      raise exception using
        errcode = '23514',
        message = 'An active draft pick requires an active draft slot.';
    end if;

    if not exists (
      select 1
      from public.player_external_ids as external_id
      inner join public.players as player
        on player.id = external_id.player_id
      where external_id.id = new.source_player_external_id_id
        and external_id.player_id = new.player_id
        and external_id.namespace = v_provider
        and external_id.sport = v_sport
        and external_id.reported_by = v_provider
        and external_id.is_primary
        and external_id.removed_at is null
        and player.sport = v_sport
    ) then
      raise exception using
        errcode = '23514',
        message = 'The draft pick player mapping is inconsistent.';
    end if;

    if new.roster_id is not null
      and (
        v_league_id is null
        or new.external_roster_id is null
        or not exists (
          select 1
          from public.rosters as roster
          where roster.id = new.roster_id
            and roster.league_id = v_league_id
            and roster.external_roster_id = new.external_roster_id
        )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'The draft pick roster resolution is inconsistent.';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function app_private.protect_finalized_confirmed_participation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_draft_id uuid;
  v_draft_provider text;
  v_board_state text;
  v_account_provider text;
begin
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
      or new.fantasy_account_id is distinct from old.fantasy_account_id
      or new.draft_id is distinct from old.draft_id
    then
      raise exception using
        errcode = '55000',
        message = 'A participation relationship cannot change identity.';
    end if;
  end if;

  if tg_op = 'DELETE' then
    v_draft_id := old.draft_id;
  else
    v_draft_id := new.draft_id;
  end if;

  select draft.provider, draft.board_state
  into v_draft_provider, v_board_state
  from public.drafts as draft
  where draft.id = v_draft_id
  for update;

  if not found then
    if tg_op = 'DELETE' then
      return old;
    end if;

    raise exception using
      errcode = '23503',
      message = 'The parent draft does not exist.';
  end if;

  if tg_op = 'DELETE' then
    if v_board_state = 'finalized'
      and old.participation_status = 'confirmed'
    then
      raise exception using
        errcode = '55000',
        message = 'Finalized confirmed participation is immutable.';
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    if v_board_state = 'finalized'
      and old.participation_status = 'confirmed'
      and (
        new.observed_at < old.observed_at
        or new.last_seen_at < old.last_seen_at
      )
    then
      raise exception using
        errcode = '55000',
        message = 'Finalized participation evidence cannot move backward.';
    end if;

    if v_board_state = 'finalized'
      and old.participation_status = 'confirmed'
      and (
        pg_catalog.to_jsonb(new)
          - array[
            'source_metadata',
            'observed_at',
            'last_seen_at',
            'updated_at'
          ]::text[]
      ) is distinct from (
        pg_catalog.to_jsonb(old)
          - array[
            'source_metadata',
            'observed_at',
            'last_seen_at',
            'updated_at'
          ]::text[]
      )
    then
      raise exception using
        errcode = '55000',
        message = 'Finalized confirmed participation is immutable.';
    end if;
  end if;

  select account.provider
  into v_account_provider
  from public.fantasy_accounts as account
  where account.id = new.fantasy_account_id;

  if not found or v_account_provider is distinct from v_draft_provider then
    raise exception using
      errcode = '23514',
      message = 'The participation provider is inconsistent.';
  end if;

  if new.participation_status = 'confirmed'
    and new.removed_at is null
    and not exists (
      select 1
      from public.draft_slots as slot
      where slot.draft_id = new.draft_id
        and slot.draft_slot = new.draft_slot
        and slot.removed_at is null
    )
  then
    raise exception using
      errcode = '23514',
      message = 'Confirmed participation requires an active draft slot.';
  end if;

  return new;
end;
$$;

revoke all on function app_private.enforce_draft_board_lifecycle()
from public, anon, authenticated, service_role;
revoke all on function app_private.protect_finalized_draft_delete()
from public, anon, authenticated, service_role;
revoke all on function app_private.reject_finalized_draft_child_mutation()
from public, anon, authenticated, service_role;
revoke all on function app_private.protect_finalized_confirmed_participation()
from public, anon, authenticated, service_role;

comment on function app_private.enforce_draft_board_lifecycle() is
  'Owner-only trigger that validates context/environment identity and enforces monotonic complete-board finalization.';
comment on function app_private.protect_finalized_draft_delete() is
  'Owner-only trigger that prevents deletion of finalized shared drafts.';
comment on function app_private.reject_finalized_draft_child_mutation() is
  'Owner-only trigger that permits slot and pick mutations only on mutable boards and validates canonical references.';
comment on function app_private.protect_finalized_confirmed_participation() is
  'Owner-only trigger that validates account participation and freezes confirmed finalized evidence identity.';

create trigger drafts_enforce_board_lifecycle
before insert or update on public.drafts
for each row execute function app_private.enforce_draft_board_lifecycle();

create trigger drafts_protect_finalized_delete
before delete on public.drafts
for each row execute function app_private.protect_finalized_draft_delete();

create trigger draft_slots_protect_board_lifecycle
before insert or update or delete on public.draft_slots
for each row execute function app_private.reject_finalized_draft_child_mutation();

create trigger draft_picks_protect_board_lifecycle
before insert or update or delete on public.draft_picks
for each row execute function app_private.reject_finalized_draft_child_mutation();

create trigger fantasy_account_drafts_protect_finalized_confirmation
before insert or update or delete on public.fantasy_account_drafts
for each row execute function app_private.protect_finalized_confirmed_participation();

alter table public.sync_runs
drop constraint sync_runs_scope_is_known;

alter table public.sync_runs
add constraint sync_runs_scope_is_known check (
  scope in ('league_discovery', 'roster_sync', 'draft_sync')
);

create unique index sync_runs_one_running_draft_sync_per_account_idx
  on public.sync_runs (fantasy_account_id)
  where scope = 'draft_sync' and status = 'running';

alter table public.fantasy_account_draft_collections enable row level security;
alter table public.drafts enable row level security;
alter table public.draft_slots enable row level security;
alter table public.fantasy_account_drafts enable row level security;
alter table public.draft_picks enable row level security;

create policy "authenticated users can select their draft collections"
on public.fantasy_account_draft_collections
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as account_link
    where account_link.fantasy_account_id =
        fantasy_account_draft_collections.fantasy_account_id
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select their draft participation"
on public.fantasy_account_drafts
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as account_link
    where account_link.fantasy_account_id =
        fantasy_account_drafts.fantasy_account_id
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select confirmed shared drafts"
on public.drafts
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_drafts as participation
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id = participation.fantasy_account_id
    where participation.draft_id = drafts.id
      and participation.participation_status = 'confirmed'
      and participation.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select confirmed draft slots"
on public.draft_slots
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_drafts as participation
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id = participation.fantasy_account_id
    where participation.draft_id = draft_slots.draft_id
      and participation.participation_status = 'confirmed'
      and participation.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select confirmed draft picks"
on public.draft_picks
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_drafts as participation
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id = participation.fantasy_account_id
    where participation.draft_id = draft_picks.draft_id
      and participation.participation_status = 'confirmed'
      and participation.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

revoke all on table public.fantasy_account_draft_collections
from public, anon, authenticated, service_role;
revoke all on table public.drafts
from public, anon, authenticated, service_role;
revoke all on table public.draft_slots
from public, anon, authenticated, service_role;
revoke all on table public.fantasy_account_drafts
from public, anon, authenticated, service_role;
revoke all on table public.draft_picks
from public, anon, authenticated, service_role;

grant select (
  fantasy_account_id,
  sport,
  season,
  source_fetched_at,
  source_draft_count,
  collection_fingerprint,
  created_at,
  updated_at
) on table public.fantasy_account_draft_collections to authenticated;

grant select (
  id,
  fantasy_account_id,
  draft_id,
  participation_status,
  draft_slot,
  observed_at,
  first_seen_at,
  last_seen_at,
  removed_at,
  created_at,
  updated_at
) on table public.fantasy_account_drafts to authenticated;

grant select (
  id,
  provider,
  external_draft_id,
  context_type,
  league_id,
  sport,
  season,
  season_type,
  draft_type,
  draft_type_family,
  status,
  name,
  description,
  team_count,
  round_count,
  pick_timer_seconds,
  start_time,
  provider_created_at,
  last_picked_at,
  league_format_context_id,
  context_resolution_status,
  context_observed_at,
  draft_environment_version,
  draft_settings_fingerprint,
  draft_environment_fingerprint,
  draft_environment_compatibility_key,
  draft_environment_quality,
  draft_pool_type,
  capital_type,
  settings,
  draft_fetched_at,
  first_seen_at,
  last_seen_at,
  removed_at,
  board_state,
  board_fetched_at,
  board_slot_count,
  board_pick_count,
  board_fingerprint_version,
  board_fingerprint,
  board_finalized_at,
  contains_keeper_picks,
  created_at,
  updated_at
) on table public.drafts to authenticated;

grant select (
  id,
  draft_id,
  draft_slot,
  roster_id,
  fetched_at,
  first_seen_at,
  last_seen_at,
  removed_at,
  created_at,
  updated_at
) on table public.draft_slots to authenticated;

grant select (
  id,
  draft_id,
  draft_slot,
  pick_no,
  round,
  player_id,
  source_player_external_id_id,
  roster_id,
  is_keeper,
  auction_amount,
  picked_at,
  player_display_name_at_draft,
  player_entity_type_at_draft,
  player_primary_position_at_draft,
  player_fantasy_positions_at_draft,
  nfl_team_at_draft,
  player_status_at_draft,
  injury_status_at_draft,
  source_fetched_at,
  first_seen_at,
  last_seen_at,
  removed_at,
  created_at,
  updated_at
) on table public.draft_picks to authenticated;
