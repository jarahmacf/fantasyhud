create or replace function app_private.upper_token_array_is_safe(
  p_values text[]
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select pg_catalog.cardinality(p_values) <= 32
    and coalesce(
      (
        select pg_catalog.bool_and(value ~ '^[A-Z0-9_]{1,32}$')
        from pg_catalog.unnest(p_values) as item(value)
      ),
      true
    );
$$;

revoke all on function app_private.upper_token_array_is_safe(text[])
from public, anon, authenticated, service_role;

create table public.players (
  id uuid primary key default gen_random_uuid(),
  sport text not null,
  entity_type text not null,
  display_name text,
  first_name text,
  last_name text,
  full_name text,
  primary_position text,
  fantasy_positions text[] not null default '{}',
  nfl_team text,
  active boolean,
  status text,
  jersey_number integer,
  age integer,
  height text,
  weight text,
  years_experience integer,
  college text,
  high_school text,
  birth_country text,
  depth_chart_position integer,
  depth_chart_order integer,
  injury_status text,
  injury_body_part text,
  injury_start_date date,
  practice_participation text,
  news_updated_at timestamptz,
  search_rank integer,
  profile_source text not null,
  source_metadata jsonb not null default '{}'::jsonb,
  profile_fetched_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint players_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint players_entity_type_is_known check (
    entity_type in ('player', 'team_defense', 'unknown')
  ),
  constraint players_display_fields_are_safe check (
    (display_name is null or (
      display_name = btrim(display_name)
      and char_length(display_name) between 1 and 255
      and display_name !~ '[[:cntrl:]]'
    ))
    and (first_name is null or (
      first_name = btrim(first_name)
      and char_length(first_name) between 1 and 100
      and first_name !~ '[[:cntrl:]]'
    ))
    and (last_name is null or (
      last_name = btrim(last_name)
      and char_length(last_name) between 1 and 100
      and last_name !~ '[[:cntrl:]]'
    ))
    and (full_name is null or (
      full_name = btrim(full_name)
      and char_length(full_name) between 1 and 255
      and full_name !~ '[[:cntrl:]]'
    ))
    and (status is null or (
      status = btrim(status)
      and char_length(status) between 1 and 64
      and status !~ '[[:cntrl:]]'
    ))
    and (height is null or (
      height = btrim(height)
      and char_length(height) between 1 and 32
      and height !~ '[[:cntrl:]]'
    ))
    and (weight is null or (
      weight = btrim(weight)
      and char_length(weight) between 1 and 32
      and weight !~ '[[:cntrl:]]'
    ))
    and (college is null or (
      college = btrim(college)
      and char_length(college) between 1 and 255
      and college !~ '[[:cntrl:]]'
    ))
    and (high_school is null or (
      high_school = btrim(high_school)
      and char_length(high_school) between 1 and 255
      and high_school !~ '[[:cntrl:]]'
    ))
    and (birth_country is null or (
      birth_country = btrim(birth_country)
      and char_length(birth_country) between 1 and 100
      and birth_country !~ '[[:cntrl:]]'
    ))
    and (injury_status is null or (
      injury_status = btrim(injury_status)
      and char_length(injury_status) between 1 and 64
      and injury_status !~ '[[:cntrl:]]'
    ))
    and (injury_body_part is null or (
      injury_body_part = btrim(injury_body_part)
      and char_length(injury_body_part) between 1 and 64
      and injury_body_part !~ '[[:cntrl:]]'
    ))
    and (practice_participation is null or (
      practice_participation = btrim(practice_participation)
      and char_length(practice_participation) between 1 and 64
      and practice_participation !~ '[[:cntrl:]]'
    ))
  ),
  constraint players_primary_position_is_safe check (
    primary_position is null or primary_position ~ '^[A-Z0-9_]{1,32}$'
  ),
  constraint players_nfl_team_is_safe check (
    nfl_team is null or nfl_team ~ '^[A-Z0-9_]{1,32}$'
  ),
  constraint players_fantasy_positions_are_safe check (
    app_private.upper_token_array_is_safe(fantasy_positions)
  ),
  constraint players_integer_fields_are_bounded check (
    (jersey_number is null or jersey_number between 0 and 99)
    and (age is null or age between 0 and 120)
    and (years_experience is null or years_experience between 0 and 100)
    and (depth_chart_position is null or depth_chart_position between 0 and 1000)
    and (depth_chart_order is null or depth_chart_order between 0 and 1000)
    and (search_rank is null or search_rank between 0 and 2147483647)
  ),
  constraint players_profile_source_is_safe check (
    profile_source ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint players_source_metadata_is_object check (
    jsonb_typeof(source_metadata) = 'object'
    and pg_column_size(source_metadata) <= 65536
  ),
  constraint players_timestamps_are_finite check (
    isfinite(profile_fetched_at)
    and (news_updated_at is null or isfinite(news_updated_at))
  )
);

comment on table public.players is
  'One shared canonical football entity with a mutable current profile.';
comment on column public.players.profile_fetched_at is
  'When FANTASY HUD fetched this current profile representation.';
comment on column public.players.news_updated_at is
  'A provider-reported news timestamp when valid; not a complete-profile update timestamp.';
comment on column public.players.search_rank is
  'Sleeper search metadata only; never a fantasy, season, position, market, or ADP rank.';

create index players_sport_entity_type_idx
  on public.players (sport, entity_type);
create index players_active_idx on public.players (active);
create index players_nfl_team_idx on public.players (nfl_team);
create index players_primary_position_idx on public.players (primary_position);
create index players_fantasy_positions_idx
  on public.players using gin (fantasy_positions);
create index players_lower_display_name_idx
  on public.players (lower(display_name))
  where display_name is not null;
create index players_profile_fetched_at_idx
  on public.players (profile_fetched_at);

create table public.player_external_ids (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null
    references public.players(id) on delete restrict,
  namespace text not null,
  sport text not null,
  external_id text not null,
  reported_by text not null,
  is_primary boolean not null default false,
  source_metadata jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_external_ids_namespace_sport_external_key unique (
    namespace,
    sport,
    external_id
  ),
  constraint player_external_ids_identifiers_are_safe check (
    namespace ~ '^[a-z][a-z0-9_-]{0,31}$'
    and sport ~ '^[a-z][a-z0-9_-]{0,31}$'
    and reported_by ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint player_external_ids_external_id_is_exact check (
    external_id = btrim(external_id)
    and char_length(external_id) between 1 and 255
    and external_id !~ '[[:cntrl:]]'
  ),
  constraint player_external_ids_metadata_is_object check (
    jsonb_typeof(source_metadata) = 'object'
    and pg_column_size(source_metadata) <= 32768
  ),
  constraint player_external_ids_seen_order_is_valid check (
    last_seen_at >= first_seen_at
  ),
  constraint player_external_ids_removed_order_is_valid check (
    removed_at is null or removed_at >= last_seen_at
  ),
  constraint player_external_ids_timestamps_are_finite check (
    isfinite(first_seen_at)
    and isfinite(last_seen_at)
    and (removed_at is null or isfinite(removed_at))
  ),
  constraint player_external_ids_primary_is_sleeper check (
    not is_primary
    or (
      namespace = 'sleeper'
      and sport = 'nfl'
      and reported_by = 'sleeper'
    )
  )
);

comment on table public.player_external_ids is
  'One exact source namespace, sport, and external ID mapped to one canonical player.';

create unique index player_external_ids_one_active_namespace_per_player_idx
  on public.player_external_ids (player_id, namespace, sport)
  where removed_at is null;
create unique index player_external_ids_one_active_primary_per_player_idx
  on public.player_external_ids (player_id)
  where is_primary and removed_at is null;
create index player_external_ids_player_idx
  on public.player_external_ids (player_id);
create index player_external_ids_namespace_sport_removed_idx
  on public.player_external_ids (namespace, sport, removed_at);
create index player_external_ids_player_removed_idx
  on public.player_external_ids (player_id, removed_at);
create index player_external_ids_reported_removed_idx
  on public.player_external_ids (reported_by, removed_at);

create table public.provider_catalog_runs (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  sport text not null,
  catalog text not null,
  triggered_by_user_id uuid references auth.users(id) on delete set null,
  status text not null,
  progress_current integer not null default 0,
  progress_total integer not null default 0,
  source_fetched_at timestamptz,
  source_record_count integer,
  source_bytes integer,
  result_counts jsonb not null default '{}'::jsonb,
  error_summary jsonb not null default '{}'::jsonb,
  started_at timestamptz not null,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_catalog_runs_identity_is_supported check (
    provider = 'sleeper' and sport = 'nfl' and catalog = 'players'
  ),
  constraint provider_catalog_runs_status_is_known check (
    status in ('running', 'succeeded', 'failed', 'partial')
  ),
  constraint provider_catalog_runs_progress_is_valid check (
    progress_current >= 0
    and progress_total >= 0
    and (progress_total = 0 or progress_current <= progress_total)
  ),
  constraint provider_catalog_runs_source_counts_are_valid check (
    (source_record_count is null or source_record_count between 0 and 50000)
    and (source_bytes is null or source_bytes between 0 and 15000000)
  ),
  constraint provider_catalog_runs_lifecycle_is_valid check (
    (status = 'running' and finished_at is null)
    or (status in ('succeeded', 'failed', 'partial') and finished_at is not null)
  ),
  constraint provider_catalog_runs_finish_order_is_valid check (
    finished_at is null or finished_at >= started_at
  ),
  constraint provider_catalog_runs_metadata_is_bounded check (
    jsonb_typeof(result_counts) = 'object'
    and jsonb_typeof(error_summary) = 'object'
    and pg_column_size(result_counts) <= 32768
    and pg_column_size(error_summary) <= 32768
  ),
  constraint provider_catalog_runs_timestamps_are_finite check (
    isfinite(started_at)
    and (finished_at is null or isfinite(finished_at))
    and (source_fetched_at is null or isfinite(source_fetched_at))
  )
);

comment on table public.provider_catalog_runs is
  'One global provider, sport, catalog resource, and attempt.';
comment on column public.provider_catalog_runs.error_summary is
  'Bounded sanitized operational metadata only; never player records or raw provider payloads.';

create unique index provider_catalog_runs_one_running_sleeper_players_idx
  on public.provider_catalog_runs (provider, sport, catalog)
  where provider = 'sleeper'
    and sport = 'nfl'
    and catalog = 'players'
    and status = 'running';
create index provider_catalog_runs_resource_created_idx
  on public.provider_catalog_runs (provider, sport, catalog, created_at desc);
create index provider_catalog_runs_status_idx
  on public.provider_catalog_runs (status);
create index provider_catalog_runs_source_fetched_idx
  on public.provider_catalog_runs (source_fetched_at desc);

create table app_private.sleeper_player_catalog_stage (
  run_id uuid not null
    references public.provider_catalog_runs(id) on delete cascade,
  external_player_id text not null,
  player_id uuid not null,
  batch_index integer not null,
  record_hash text not null,
  normalized_record jsonb not null,
  created_at timestamptz not null default now(),
  primary key (run_id, external_player_id),
  constraint sleeper_player_catalog_stage_external_id_is_exact check (
    external_player_id = btrim(external_player_id)
    and char_length(external_player_id) between 1 and 255
    and external_player_id !~ '[[:cntrl:]]'
  ),
  constraint sleeper_player_catalog_stage_batch_is_nonnegative check (
    batch_index >= 0
  ),
  constraint sleeper_player_catalog_stage_hash_is_digest check (
    record_hash ~ '^[0-9a-f]{32}$'
  ),
  constraint sleeper_player_catalog_stage_record_is_bounded check (
    jsonb_typeof(normalized_record) = 'object'
    and pg_column_size(normalized_record) <= 131072
  )
);

comment on table app_private.sleeper_player_catalog_stage is
  'Private bounded implementation state for one normalized Sleeper player record and catalog run; never domain truth.';

create index sleeper_player_catalog_stage_run_batch_idx
  on app_private.sleeper_player_catalog_stage (run_id, batch_index);

create trigger players_set_updated_at
before update on public.players
for each row execute function app_private.set_updated_at();

create trigger player_external_ids_set_updated_at
before update on public.player_external_ids
for each row execute function app_private.set_updated_at();

create trigger provider_catalog_runs_set_updated_at
before update on public.provider_catalog_runs
for each row execute function app_private.set_updated_at();

alter table public.players enable row level security;
alter table public.player_external_ids enable row level security;
alter table public.provider_catalog_runs enable row level security;

create policy "authenticated users can select canonical players"
on public.players
for select
to authenticated
using (true);

create policy "authenticated users can select player external IDs"
on public.player_external_ids
for select
to authenticated
using (true);

create policy "authenticated users can select provider catalog runs"
on public.provider_catalog_runs
for select
to authenticated
using (true);

revoke all on table public.players from public, anon, authenticated, service_role;
revoke all on table public.player_external_ids from public, anon, authenticated, service_role;
revoke all on table public.provider_catalog_runs from public, anon, authenticated, service_role;
revoke all on table app_private.sleeper_player_catalog_stage
  from public, anon, authenticated, service_role;

grant select on table public.players to authenticated;
grant select on table public.player_external_ids to authenticated;
grant select on table public.provider_catalog_runs to authenticated;

create or replace function app_private.sleeper_player_record_is_valid(
  p_record jsonb,
  p_expected_fetched_at timestamptz
)
returns boolean
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_profile jsonb;
  v_external_ids jsonb;
  v_key text;
  v_value jsonb;
  v_maximum_length integer;
  v_number numeric;
  v_profile_fetched_at timestamptz;
  v_news_updated_at timestamptz;
  v_injury_start_date date;
begin
  if p_record is null
    or pg_catalog.jsonb_typeof(p_record) <> 'object'
    or pg_catalog.pg_column_size(p_record) > 131072
    or p_expected_fetched_at is null
    or not pg_catalog.isfinite(p_expected_fetched_at)
  then
    return false;
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_object_keys(p_record) as record_key(key)
    where record_key.key not in (
      'external_player_id',
      'profile',
      'external_ids',
      'normalization_warning_count'
    )
  ) or (
    select pg_catalog.count(*)
    from pg_catalog.jsonb_object_keys(p_record)
  ) <> 4 then
    return false;
  end if;

  if pg_catalog.jsonb_typeof(p_record -> 'external_player_id') <> 'string'
    or p_record ->> 'external_player_id' <> pg_catalog.btrim(
      p_record ->> 'external_player_id'
    )
    or pg_catalog.char_length(p_record ->> 'external_player_id')
      not between 1 and 255
    or p_record ->> 'external_player_id' ~ '[[:cntrl:]]'
    or pg_catalog.jsonb_typeof(p_record -> 'profile') <> 'object'
    or pg_catalog.jsonb_typeof(p_record -> 'external_ids') <> 'array'
    or pg_catalog.jsonb_typeof(
      p_record -> 'normalization_warning_count'
    ) <> 'number'
  then
    return false;
  end if;

  begin
    v_number := (p_record ->> 'normalization_warning_count')::numeric;
  exception when others then
    return false;
  end;

  if v_number <> pg_catalog.trunc(v_number)
    or v_number not between 0 and 1000
  then
    return false;
  end if;

  v_profile := p_record -> 'profile';
  v_external_ids := p_record -> 'external_ids';

  if exists (
    select 1
    from pg_catalog.jsonb_object_keys(v_profile) as profile_key(key)
    where profile_key.key not in (
      'sport',
      'entity_type',
      'display_name',
      'first_name',
      'last_name',
      'full_name',
      'primary_position',
      'fantasy_positions',
      'nfl_team',
      'active',
      'status',
      'jersey_number',
      'age',
      'height',
      'weight',
      'years_experience',
      'college',
      'high_school',
      'birth_country',
      'depth_chart_position',
      'depth_chart_order',
      'injury_status',
      'injury_body_part',
      'injury_start_date',
      'practice_participation',
      'news_updated_at',
      'search_rank',
      'profile_source',
      'source_metadata',
      'profile_fetched_at'
    )
  ) or (
    select pg_catalog.count(*)
    from pg_catalog.jsonb_object_keys(v_profile)
  ) <> 30 then
    return false;
  end if;

  if v_profile ->> 'sport' <> 'nfl'
    or v_profile ->> 'profile_source' <> 'sleeper'
    or v_profile ->> 'entity_type' not in (
      'player', 'team_defense', 'unknown'
    )
    or pg_catalog.jsonb_typeof(v_profile -> 'fantasy_positions') <> 'array'
    or pg_catalog.jsonb_array_length(v_profile -> 'fantasy_positions') > 32
    or pg_catalog.jsonb_typeof(v_profile -> 'source_metadata') <> 'object'
    or pg_catalog.pg_column_size(v_profile -> 'source_metadata') > 65536
    or pg_catalog.jsonb_typeof(v_profile -> 'profile_fetched_at') <> 'string'
  then
    return false;
  end if;

  for v_key, v_value in
    select field.key, field.value
    from pg_catalog.jsonb_each(v_profile) as field(key, value)
    where field.key in (
      'display_name',
      'first_name',
      'last_name',
      'full_name',
      'status',
      'height',
      'weight',
      'college',
      'high_school',
      'birth_country',
      'injury_status',
      'injury_body_part',
      'practice_participation'
    )
  loop
    if v_value = 'null'::jsonb then
      continue;
    end if;

    v_maximum_length := case v_key
      when 'display_name' then 255
      when 'first_name' then 100
      when 'last_name' then 100
      when 'full_name' then 255
      when 'height' then 32
      when 'weight' then 32
      when 'college' then 255
      when 'high_school' then 255
      when 'birth_country' then 100
      else 64
    end;

    if pg_catalog.jsonb_typeof(v_value) <> 'string'
      or v_value #>> '{}' <> pg_catalog.btrim(v_value #>> '{}')
      or pg_catalog.char_length(v_value #>> '{}')
        not between 1 and v_maximum_length
      or v_value #>> '{}' ~ '[[:cntrl:]]'
    then
      return false;
    end if;
  end loop;

  for v_key in
    select token.key
    from pg_catalog.unnest(array['primary_position', 'nfl_team'])
      as token(key)
  loop
    v_value := v_profile -> v_key;
    if v_value <> 'null'::jsonb and (
      pg_catalog.jsonb_typeof(v_value) <> 'string'
      or v_value #>> '{}' !~ '^[A-Z0-9_]{1,32}$'
    ) then
      return false;
    end if;
  end loop;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      v_profile -> 'fantasy_positions'
    ) as position(value)
    where pg_catalog.jsonb_typeof(position.value) <> 'string'
      or position.value #>> '{}' !~ '^[A-Z0-9_]{1,32}$'
  ) or (
    select pg_catalog.count(*)
    from pg_catalog.jsonb_array_elements_text(
      v_profile -> 'fantasy_positions'
    ) as position(value)
  ) <> (
    select pg_catalog.count(distinct position.value)
    from pg_catalog.jsonb_array_elements_text(
      v_profile -> 'fantasy_positions'
    ) as position(value)
  ) then
    return false;
  end if;

  if v_profile -> 'active' <> 'null'::jsonb
    and pg_catalog.jsonb_typeof(v_profile -> 'active') <> 'boolean'
  then
    return false;
  end if;

  for v_key, v_value in
    select field.key, field.value
    from pg_catalog.jsonb_each(v_profile) as field(key, value)
    where field.key in (
      'jersey_number',
      'age',
      'years_experience',
      'depth_chart_position',
      'depth_chart_order',
      'search_rank'
    )
  loop
    if v_value = 'null'::jsonb then
      continue;
    end if;

    if pg_catalog.jsonb_typeof(v_value) <> 'number' then
      return false;
    end if;

    begin
      v_number := (v_value #>> '{}')::numeric;
    exception when others then
      return false;
    end;

    if v_number <> pg_catalog.trunc(v_number)
      or (
        case v_key
          when 'jersey_number' then not (v_number between 0 and 99)
          when 'age' then not (v_number between 0 and 120)
          when 'years_experience' then not (v_number between 0 and 100)
          when 'depth_chart_position' then not (v_number between 0 and 1000)
          when 'depth_chart_order' then not (v_number between 0 and 1000)
          when 'search_rank' then not (
            v_number between 0 and 2147483647
          )
          else true
        end
      )
    then
      return false;
    end if;
  end loop;

  begin
    v_profile_fetched_at := (
      v_profile ->> 'profile_fetched_at'
    )::timestamptz;
    v_news_updated_at := case
      when v_profile -> 'news_updated_at' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(v_profile -> 'news_updated_at') = 'string'
        then (v_profile ->> 'news_updated_at')::timestamptz
      else '-infinity'::timestamptz
    end;
    v_injury_start_date := case
      when v_profile -> 'injury_start_date' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(v_profile -> 'injury_start_date') = 'string'
        then (v_profile ->> 'injury_start_date')::date
      else '-infinity'::date
    end;
  exception when others then
    return false;
  end;

  if not pg_catalog.isfinite(v_profile_fetched_at)
    or v_profile_fetched_at <> p_expected_fetched_at
    or (v_news_updated_at is not null and not pg_catalog.isfinite(v_news_updated_at))
    or (v_injury_start_date is not null and not pg_catalog.isfinite(v_injury_start_date))
    or (
      v_injury_start_date is not null
      and v_injury_start_date::text <> v_profile ->> 'injury_start_date'
    )
  then
    return false;
  end if;

  if pg_catalog.jsonb_array_length(v_external_ids) > 7
    or exists (
      select 1
      from pg_catalog.jsonb_array_elements(v_external_ids) as external(value)
      where pg_catalog.jsonb_typeof(external.value) <> 'object'
        or exists (
          select 1
          from pg_catalog.jsonb_object_keys(external.value)
            as external_key(key)
          where external_key.key not in (
            'namespace', 'external_id', 'reported_by', 'source_field'
          )
        )
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(external.value)
        ) <> 4
        or external.value ->> 'namespace' not in (
          'espn', 'yahoo', 'stats', 'sportradar',
          'fantasy_data', 'rotowire', 'rotoworld'
        )
        or external.value ->> 'reported_by' <> 'sleeper'
        or external.value ->> 'source_field' <> case
          external.value ->> 'namespace'
          when 'espn' then 'espn_id'
          when 'yahoo' then 'yahoo_id'
          when 'stats' then 'stats_id'
          when 'sportradar' then 'sportradar_id'
          when 'fantasy_data' then 'fantasy_data_id'
          when 'rotowire' then 'rotowire_id'
          when 'rotoworld' then 'rotoworld_id'
        end
        or pg_catalog.jsonb_typeof(
          external.value -> 'external_id'
        ) <> 'string'
        or external.value ->> 'external_id' <> pg_catalog.btrim(
          external.value ->> 'external_id'
        )
        or pg_catalog.char_length(external.value ->> 'external_id')
          not between 1 and 255
        or external.value ->> 'external_id' ~ '[[:cntrl:]]'
    )
    or exists (
      select external.value ->> 'namespace'
      from pg_catalog.jsonb_array_elements(v_external_ids) as external(value)
      group by external.value ->> 'namespace'
      having pg_catalog.count(*) > 1
    )
  then
    return false;
  end if;

  return true;
exception when others then
  return false;
end;
$$;

create or replace function app_private.sleeper_player_secondary_candidates(
  p_run_id uuid
)
returns table (
  player_id uuid,
  namespace text,
  external_id text,
  source_field text
)
language sql
stable
set search_path = pg_catalog
as $$
  select
    stage.player_id,
    external.value ->> 'namespace',
    external.value ->> 'external_id',
    external.value ->> 'source_field'
  from app_private.sleeper_player_catalog_stage as stage
  cross join lateral pg_catalog.jsonb_array_elements(
    stage.normalized_record -> 'external_ids'
  ) as external(value)
  where stage.run_id = p_run_id;
$$;

revoke all on function app_private.sleeper_player_record_is_valid(
  jsonb,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function app_private.sleeper_player_secondary_candidates(uuid)
from public, anon, authenticated, service_role;

create or replace function public.start_sleeper_player_catalog_sync(
  p_user_id uuid
)
returns table (
  catalog_run_id uuid,
  created_run boolean,
  reused_run boolean,
  catalog_fresh boolean,
  recovered_stale_run boolean,
  last_success_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_run_id uuid;
  v_running_updated_at timestamptz;
  v_last_success_at timestamptz;
  v_last_success_run_id uuid;
  v_recovered boolean := false;
begin
  if p_user_id is null
    or not exists (
      select 1
      from auth.users as app_user
      where app_user.id = p_user_id
    )
  then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  if not exists (
    select 1
    from public.user_fantasy_accounts as account_link
    inner join public.fantasy_accounts as account
      on account.id = account_link.fantasy_account_id
    where account_link.user_id = p_user_id
      and account.provider = 'sleeper'
  ) then
    raise exception using
      errcode = '42501',
      message = 'The app user must track a Sleeper fantasy account.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sleeper:nfl:players', 0)
  );

  select run.id, run.source_fetched_at
  into v_last_success_run_id, v_last_success_at
  from public.provider_catalog_runs as run
  where run.provider = 'sleeper'
    and run.sport = 'nfl'
    and run.catalog = 'players'
    and run.status = 'succeeded'
    and run.source_fetched_at is not null
  order by run.source_fetched_at desc, run.id
  limit 1;

  if v_last_success_at is not null
    and v_last_success_at >= v_now - interval '24 hours'
  then
    return query
    select
      v_last_success_run_id,
      false,
      false,
      true,
      false,
      v_last_success_at;
    return;
  end if;

  select run.id, run.updated_at
  into v_run_id, v_running_updated_at
  from public.provider_catalog_runs as run
  where run.provider = 'sleeper'
    and run.sport = 'nfl'
    and run.catalog = 'players'
    and run.status = 'running'
  for update;

  if found and v_running_updated_at >= v_now - interval '15 minutes' then
    return query
    select
      v_run_id,
      false,
      true,
      false,
      false,
      v_last_success_at;
    return;
  end if;

  if found then
    update public.provider_catalog_runs as stale_run
    set
      status = 'failed',
      error_summary = pg_catalog.jsonb_build_object(
        'code', 'stale_catalog_run',
        'message',
          'The previous player catalog refresh stopped before completion.',
        'retryable', true,
        'stage', 'player_catalog'
      ),
      finished_at = v_now,
      updated_at = v_now
    where stale_run.id = v_run_id;

    delete from app_private.sleeper_player_catalog_stage as stale_stage
    where stale_stage.run_id = v_run_id;

    v_recovered := true;
  end if;

  insert into public.provider_catalog_runs (
    provider,
    sport,
    catalog,
    triggered_by_user_id,
    status,
    started_at,
    updated_at
  ) values (
    'sleeper',
    'nfl',
    'players',
    p_user_id,
    'running',
    v_now,
    v_now
  )
  returning public.provider_catalog_runs.id into v_run_id;

  return query
  select
    v_run_id,
    true,
    false,
    false,
    v_recovered,
    v_last_success_at;
end;
$$;

create or replace function public.stage_sleeper_player_catalog_batch(
  p_user_id uuid,
  p_catalog_run_id uuid,
  p_batch_index integer,
  p_expected_total integer,
  p_source_fetched_at timestamptz,
  p_source_bytes integer,
  p_records jsonb
)
returns table (
  catalog_run_id uuid,
  staged_records integer,
  total_staged_records integer,
  progress_total integer,
  replayed_batch boolean
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_run public.provider_catalog_runs%rowtype;
  v_record jsonb;
  v_external_player_id text;
  v_record_hash text;
  v_player_id uuid;
  v_existing_batch_index integer;
  v_existing_hash text;
  v_batch_count integer;
  v_inserted integer := 0;
  v_total_staged integer;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_user_id is null
    or p_catalog_run_id is null
    or p_batch_index is null
    or p_batch_index < 0
    or p_expected_total is null
    or p_expected_total not between 500 and 50000
    or p_source_fetched_at is null
    or not pg_catalog.isfinite(p_source_fetched_at)
    or p_source_bytes is null
    or p_source_bytes not between 1 and 15000000
    or p_records is null
    or pg_catalog.jsonb_typeof(p_records) <> 'array'
  then
    raise exception using
      errcode = '22023',
      message = 'The player-catalog batch envelope is invalid.';
  end if;

  v_batch_count := pg_catalog.jsonb_array_length(p_records);

  if v_batch_count not between 1 and 500 then
    raise exception using
      errcode = '22023',
      message = 'A player-catalog batch must contain between 1 and 500 records.';
  end if;

  if not exists (
    select 1
    from auth.users as app_user
    where app_user.id = p_user_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  if not exists (
    select 1
    from public.user_fantasy_accounts as account_link
    inner join public.fantasy_accounts as account
      on account.id = account_link.fantasy_account_id
    where account_link.user_id = p_user_id
      and account.provider = 'sleeper'
  ) then
    raise exception using
      errcode = '42501',
      message = 'The app user must track a Sleeper fantasy account.';
  end if;

  select run.*
  into v_run
  from public.provider_catalog_runs as run
  where run.id = p_catalog_run_id
  for update;

  if not found
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.catalog <> 'players'
    or v_run.status <> 'running'
  then
    raise exception using
      errcode = '22023',
      message = 'The catalog run does not match this running Sleeper player refresh.';
  end if;

  if v_run.source_record_count is null then
    if p_batch_index <> 0
      or v_run.progress_current <> 0
      or v_run.progress_total <> 0
      or v_run.source_fetched_at is not null
      or v_run.source_bytes is not null
    then
      raise exception using
        errcode = '22023',
        message = 'The first player-catalog batch must establish the source envelope.';
    end if;

    update public.provider_catalog_runs as run
    set
      progress_total = p_expected_total,
      source_record_count = p_expected_total,
      source_fetched_at = p_source_fetched_at,
      source_bytes = p_source_bytes,
      updated_at = v_now
    where run.id = p_catalog_run_id;
  elsif v_run.progress_total <> p_expected_total
    or v_run.source_record_count <> p_expected_total
    or v_run.source_fetched_at is distinct from p_source_fetched_at
    or v_run.source_bytes <> p_source_bytes
  then
    raise exception using
      errcode = '22023',
      message = 'The player-catalog source envelope changed between batches.';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(p_records) as submitted(record)
    group by submitted.record ->> 'external_player_id'
    having pg_catalog.count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'A player-catalog batch contains a duplicate Sleeper ID.';
  end if;

  for v_record in
    select submitted.record
    from pg_catalog.jsonb_array_elements(p_records) as submitted(record)
    order by submitted.record ->> 'external_player_id'
  loop
    if not app_private.sleeper_player_record_is_valid(
      v_record,
      p_source_fetched_at
    ) then
      raise exception using
        errcode = '22023',
        message = 'A normalized player-catalog record is invalid.';
    end if;

    v_external_player_id := v_record ->> 'external_player_id';
    v_record_hash := pg_catalog.md5(v_record::text);

    select stage.batch_index, stage.record_hash
    into v_existing_batch_index, v_existing_hash
    from app_private.sleeper_player_catalog_stage as stage
    where stage.run_id = p_catalog_run_id
      and stage.external_player_id = v_external_player_id;

    if found then
      if v_existing_batch_index <> p_batch_index
        or v_existing_hash <> v_record_hash
      then
        raise exception using
          errcode = '22023',
          message = 'A staged Sleeper ID changed across catalog batches.';
      end if;

      continue;
    end if;

    select external_id.player_id
    into v_player_id
    from public.player_external_ids as external_id
    where external_id.namespace = 'sleeper'
      and external_id.sport = 'nfl'
      and external_id.external_id = v_external_player_id;

    if not found then
      v_player_id := gen_random_uuid();
    end if;

    insert into app_private.sleeper_player_catalog_stage (
      run_id,
      external_player_id,
      player_id,
      batch_index,
      record_hash,
      normalized_record
    ) values (
      p_catalog_run_id,
      v_external_player_id,
      v_player_id,
      p_batch_index,
      v_record_hash,
      v_record
    );

    v_inserted := v_inserted + 1;
  end loop;

  select pg_catalog.count(*)::integer
  into v_total_staged
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id;

  if v_total_staged > p_expected_total then
    raise exception using
      errcode = '22023',
      message = 'Player-catalog progress exceeds the expected source count.';
  end if;

  update public.provider_catalog_runs as run
  set
    progress_current = v_total_staged,
    progress_total = p_expected_total,
    updated_at = v_now
  where run.id = p_catalog_run_id;

  return query
  select
    p_catalog_run_id,
    v_batch_count,
    v_total_staged,
    p_expected_total,
    v_inserted = 0;
end;
$$;

create or replace function app_private.sleeper_player_profiles(
  p_run_id uuid
)
returns table (
  external_player_id text,
  player_id uuid,
  sport text,
  entity_type text,
  display_name text,
  first_name text,
  last_name text,
  full_name text,
  primary_position text,
  fantasy_positions text[],
  nfl_team text,
  active boolean,
  status text,
  jersey_number integer,
  age integer,
  height text,
  weight text,
  years_experience integer,
  college text,
  high_school text,
  birth_country text,
  depth_chart_position integer,
  depth_chart_order integer,
  injury_status text,
  injury_body_part text,
  injury_start_date date,
  practice_participation text,
  news_updated_at timestamptz,
  search_rank integer,
  profile_source text,
  source_metadata jsonb,
  profile_fetched_at timestamptz
)
language sql
stable
set search_path = pg_catalog
as $$
  select
    stage.external_player_id,
    stage.player_id,
    stage.normalized_record -> 'profile' ->> 'sport',
    stage.normalized_record -> 'profile' ->> 'entity_type',
    stage.normalized_record -> 'profile' ->> 'display_name',
    stage.normalized_record -> 'profile' ->> 'first_name',
    stage.normalized_record -> 'profile' ->> 'last_name',
    stage.normalized_record -> 'profile' ->> 'full_name',
    stage.normalized_record -> 'profile' ->> 'primary_position',
    array(
      select position.value
      from pg_catalog.jsonb_array_elements_text(
        stage.normalized_record -> 'profile' -> 'fantasy_positions'
      ) with ordinality as position(value, source_order)
      order by position.source_order
    ),
    stage.normalized_record -> 'profile' ->> 'nfl_team',
    case
      when stage.normalized_record -> 'profile' -> 'active' = 'null'::jsonb
        then null
      else (stage.normalized_record -> 'profile' ->> 'active')::boolean
    end,
    stage.normalized_record -> 'profile' ->> 'status',
    (stage.normalized_record -> 'profile' ->> 'jersey_number')::integer,
    (stage.normalized_record -> 'profile' ->> 'age')::integer,
    stage.normalized_record -> 'profile' ->> 'height',
    stage.normalized_record -> 'profile' ->> 'weight',
    (stage.normalized_record -> 'profile' ->> 'years_experience')::integer,
    stage.normalized_record -> 'profile' ->> 'college',
    stage.normalized_record -> 'profile' ->> 'high_school',
    stage.normalized_record -> 'profile' ->> 'birth_country',
    (stage.normalized_record -> 'profile' ->> 'depth_chart_position')::integer,
    (stage.normalized_record -> 'profile' ->> 'depth_chart_order')::integer,
    stage.normalized_record -> 'profile' ->> 'injury_status',
    stage.normalized_record -> 'profile' ->> 'injury_body_part',
    (stage.normalized_record -> 'profile' ->> 'injury_start_date')::date,
    stage.normalized_record -> 'profile' ->> 'practice_participation',
    (stage.normalized_record -> 'profile' ->> 'news_updated_at')::timestamptz,
    (stage.normalized_record -> 'profile' ->> 'search_rank')::integer,
    stage.normalized_record -> 'profile' ->> 'profile_source',
    stage.normalized_record -> 'profile' -> 'source_metadata',
    (stage.normalized_record -> 'profile' ->> 'profile_fetched_at')::timestamptz
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_run_id;
$$;

revoke all on function app_private.sleeper_player_profiles(uuid)
from public, anon, authenticated, service_role;

create or replace function public.complete_sleeper_player_catalog_sync(
  p_user_id uuid,
  p_catalog_run_id uuid
)
returns table (
  catalog_run_id uuid,
  observed_records integer,
  created_players integer,
  updated_players integer,
  stale_player_profiles_skipped integer,
  created_sleeper_ids integer,
  reactivated_sleeper_ids integer,
  removed_sleeper_ids integer,
  secondary_ids_created integer,
  secondary_ids_refreshed integer,
  secondary_ids_replaced integer,
  ambiguous_secondary_ids_skipped integer,
  conflicting_secondary_ids_skipped integer,
  records_with_warnings integer,
  normalization_warning_count integer,
  active_players integer,
  team_defenses integer,
  unknown_entities integer
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '60s'
as $$
declare
  v_run public.provider_catalog_runs%rowtype;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_staged_count integer;
  v_previous_source_count integer;
  v_minimum_safe_count integer;
  v_created_players integer := 0;
  v_updated_players integer := 0;
  v_stale_profiles integer := 0;
  v_created_sleeper_ids integer := 0;
  v_reactivated_sleeper_ids integer := 0;
  v_removed_sleeper_ids integer := 0;
  v_secondary_created integer := 0;
  v_secondary_refreshed integer := 0;
  v_secondary_replaced integer := 0;
  v_ambiguous_secondary integer := 0;
  v_conflicting_secondary integer := 0;
  v_records_with_warnings integer := 0;
  v_warning_count integer := 0;
  v_active_players integer := 0;
  v_team_defenses integer := 0;
  v_unknown_entities integer := 0;
begin
  if p_user_id is null or p_catalog_run_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid app user and catalog run are required.';
  end if;

  if not exists (
    select 1
    from auth.users as app_user
    where app_user.id = p_user_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  if not exists (
    select 1
    from public.user_fantasy_accounts as account_link
    inner join public.fantasy_accounts as account
      on account.id = account_link.fantasy_account_id
    where account_link.user_id = p_user_id
      and account.provider = 'sleeper'
  ) then
    raise exception using
      errcode = '42501',
      message = 'The app user must track a Sleeper fantasy account.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sleeper:nfl:players', 0)
  );

  select run.*
  into v_run
  from public.provider_catalog_runs as run
  where run.id = p_catalog_run_id
  for update;

  if not found
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.catalog <> 'players'
    or v_run.status <> 'running'
  then
    raise exception using
      errcode = '22023',
      message = 'The catalog run does not match this running Sleeper player refresh.';
  end if;

  select pg_catalog.count(*)::integer
  into v_staged_count
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id;

  if v_run.source_fetched_at is null
    or v_run.source_record_count is null
    or v_run.source_bytes is null
    or v_staged_count < 500
    or v_staged_count <> v_run.progress_current
    or v_staged_count <> v_run.progress_total
    or v_staged_count <> v_run.source_record_count
  then
    raise exception using
      errcode = '22023',
      message = 'The staged player catalog is incomplete.';
  end if;

  select prior.source_record_count
  into v_previous_source_count
  from public.provider_catalog_runs as prior
  where prior.provider = 'sleeper'
    and prior.sport = 'nfl'
    and prior.catalog = 'players'
    and prior.status = 'succeeded'
    and prior.source_record_count is not null
    and prior.id <> p_catalog_run_id
  order by prior.source_fetched_at desc nulls last, prior.created_at desc
  limit 1;

  if v_previous_source_count is not null then
    v_minimum_safe_count := greatest(
      500,
      pg_catalog.floor(v_previous_source_count * 0.75)::integer
    );

    if v_staged_count < v_minimum_safe_count then
      raise exception using
        errcode = '22023',
        message = 'The staged player catalog failed the anti-wipe size guard.';
    end if;
  end if;

  if exists (
    select 1
    from app_private.sleeper_player_catalog_stage as stage
    where stage.run_id = p_catalog_run_id
      and (
        stage.external_player_id
          <> stage.normalized_record ->> 'external_player_id'
        or not app_private.sleeper_player_record_is_valid(
          stage.normalized_record,
          v_run.source_fetched_at
        )
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'The staged player catalog failed final record validation.';
  end if;

  if exists (
    select stage.player_id
    from app_private.sleeper_player_catalog_stage as stage
    where stage.run_id = p_catalog_run_id
    group by stage.player_id
    having pg_catalog.count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'The staged player catalog has inconsistent canonical player IDs.';
  end if;

  if exists (
    select 1
    from app_private.sleeper_player_catalog_stage as stage
    inner join public.player_external_ids as external_id
      on external_id.namespace = 'sleeper'
      and external_id.sport = 'nfl'
      and external_id.external_id = stage.external_player_id
    where stage.run_id = p_catalog_run_id
      and external_id.player_id <> stage.player_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'A staged Sleeper ID no longer resolves to its canonical player.';
  end if;

  select
    pg_catalog.count(*) filter (
      where (
        stage.normalized_record ->> 'normalization_warning_count'
      )::integer > 0
    )::integer,
    coalesce(pg_catalog.sum((
      stage.normalized_record ->> 'normalization_warning_count'
    )::integer), 0)::integer,
    pg_catalog.count(*) filter (
      where (stage.normalized_record -> 'profile' ->> 'active')::boolean
    )::integer,
    pg_catalog.count(*) filter (
      where stage.normalized_record -> 'profile' ->> 'entity_type'
        = 'team_defense'
    )::integer,
    pg_catalog.count(*) filter (
      where stage.normalized_record -> 'profile' ->> 'entity_type'
        = 'unknown'
    )::integer
  into
    v_records_with_warnings,
    v_warning_count,
    v_active_players,
    v_team_defenses,
    v_unknown_entities
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id;

  select pg_catalog.count(*)::integer
  into v_stale_profiles
  from app_private.sleeper_player_profiles(p_catalog_run_id) as incoming
  inner join public.players as player on player.id = incoming.player_id
  where incoming.profile_fetched_at < player.profile_fetched_at;

  update public.players as player
  set
    sport = incoming.sport,
    entity_type = incoming.entity_type,
    display_name = incoming.display_name,
    first_name = incoming.first_name,
    last_name = incoming.last_name,
    full_name = incoming.full_name,
    primary_position = incoming.primary_position,
    fantasy_positions = incoming.fantasy_positions,
    nfl_team = incoming.nfl_team,
    active = incoming.active,
    status = incoming.status,
    jersey_number = incoming.jersey_number,
    age = incoming.age,
    height = incoming.height,
    weight = incoming.weight,
    years_experience = incoming.years_experience,
    college = incoming.college,
    high_school = incoming.high_school,
    birth_country = incoming.birth_country,
    depth_chart_position = incoming.depth_chart_position,
    depth_chart_order = incoming.depth_chart_order,
    injury_status = incoming.injury_status,
    injury_body_part = incoming.injury_body_part,
    injury_start_date = incoming.injury_start_date,
    practice_participation = incoming.practice_participation,
    news_updated_at = incoming.news_updated_at,
    search_rank = incoming.search_rank,
    profile_source = incoming.profile_source,
    source_metadata = incoming.source_metadata,
    profile_fetched_at = incoming.profile_fetched_at,
    updated_at = v_now
  from app_private.sleeper_player_profiles(p_catalog_run_id) as incoming
  where player.id = incoming.player_id
    and incoming.profile_fetched_at >= player.profile_fetched_at;

  get diagnostics v_updated_players = row_count;

  insert into public.players (
    id,
    sport,
    entity_type,
    display_name,
    first_name,
    last_name,
    full_name,
    primary_position,
    fantasy_positions,
    nfl_team,
    active,
    status,
    jersey_number,
    age,
    height,
    weight,
    years_experience,
    college,
    high_school,
    birth_country,
    depth_chart_position,
    depth_chart_order,
    injury_status,
    injury_body_part,
    injury_start_date,
    practice_participation,
    news_updated_at,
    search_rank,
    profile_source,
    source_metadata,
    profile_fetched_at,
    created_at,
    updated_at
  )
  select
    incoming.player_id,
    incoming.sport,
    incoming.entity_type,
    incoming.display_name,
    incoming.first_name,
    incoming.last_name,
    incoming.full_name,
    incoming.primary_position,
    incoming.fantasy_positions,
    incoming.nfl_team,
    incoming.active,
    incoming.status,
    incoming.jersey_number,
    incoming.age,
    incoming.height,
    incoming.weight,
    incoming.years_experience,
    incoming.college,
    incoming.high_school,
    incoming.birth_country,
    incoming.depth_chart_position,
    incoming.depth_chart_order,
    incoming.injury_status,
    incoming.injury_body_part,
    incoming.injury_start_date,
    incoming.practice_participation,
    incoming.news_updated_at,
    incoming.search_rank,
    incoming.profile_source,
    incoming.source_metadata,
    incoming.profile_fetched_at,
    v_now,
    v_now
  from app_private.sleeper_player_profiles(p_catalog_run_id) as incoming
  where not exists (
    select 1
    from public.players as existing
    where existing.id = incoming.player_id
  )
  order by incoming.external_player_id;

  get diagnostics v_created_players = row_count;

  select pg_catalog.count(*)::integer
  into v_created_sleeper_ids
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id
    and not exists (
      select 1
      from public.player_external_ids as external_id
      where external_id.namespace = 'sleeper'
        and external_id.sport = 'nfl'
        and external_id.external_id = stage.external_player_id
    );

  select pg_catalog.count(*)::integer
  into v_reactivated_sleeper_ids
  from app_private.sleeper_player_catalog_stage as stage
  inner join public.player_external_ids as external_id
    on external_id.namespace = 'sleeper'
    and external_id.sport = 'nfl'
    and external_id.external_id = stage.external_player_id
    and external_id.player_id = stage.player_id
  where stage.run_id = p_catalog_run_id
    and external_id.removed_at is not null;

  update public.player_external_ids as external_id
  set
    removed_at = greatest(v_now, external_id.last_seen_at),
    updated_at = v_now
  where external_id.namespace = 'sleeper'
    and external_id.sport = 'nfl'
    and external_id.is_primary
    and external_id.removed_at is null
    and not exists (
      select 1
      from app_private.sleeper_player_catalog_stage as stage
      where stage.run_id = p_catalog_run_id
        and stage.external_player_id = external_id.external_id
        and stage.player_id = external_id.player_id
    );

  get diagnostics v_removed_sleeper_ids = row_count;

  update public.player_external_ids as external_id
  set
    last_seen_at = greatest(
      external_id.last_seen_at,
      v_run.source_fetched_at
    ),
    removed_at = null,
    reported_by = 'sleeper',
    is_primary = true,
    source_metadata = pg_catalog.jsonb_build_object(
      'source_field', 'map_key'
    ),
    updated_at = v_now
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id
    and external_id.namespace = 'sleeper'
    and external_id.sport = 'nfl'
    and external_id.external_id = stage.external_player_id
    and external_id.player_id = stage.player_id;

  insert into public.player_external_ids (
    player_id,
    namespace,
    sport,
    external_id,
    reported_by,
    is_primary,
    source_metadata,
    first_seen_at,
    last_seen_at,
    removed_at,
    created_at,
    updated_at
  )
  select
    stage.player_id,
    'sleeper',
    'nfl',
    stage.external_player_id,
    'sleeper',
    true,
    pg_catalog.jsonb_build_object('source_field', 'map_key'),
    v_run.source_fetched_at,
    v_run.source_fetched_at,
    null,
    v_now,
    v_now
  from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id
    and not exists (
      select 1
      from public.player_external_ids as external_id
      where external_id.namespace = 'sleeper'
        and external_id.sport = 'nfl'
        and external_id.external_id = stage.external_player_id
    )
  order by stage.external_player_id;

  with candidates as (
    select candidate.*
    from app_private.sleeper_player_secondary_candidates(
      p_catalog_run_id
    ) as candidate
  )
  select pg_catalog.count(*)::integer
  into v_ambiguous_secondary
  from candidates as candidate
  where exists (
    select 1
    from candidates as other
    where other.namespace = candidate.namespace
      and other.external_id = candidate.external_id
      and other.player_id <> candidate.player_id
  );

  with candidates as (
    select candidate.*
    from app_private.sleeper_player_secondary_candidates(
      p_catalog_run_id
    ) as candidate
  ), unambiguous as (
    select candidate.*
    from candidates as candidate
    where not exists (
      select 1
      from candidates as other
      where other.namespace = candidate.namespace
        and other.external_id = candidate.external_id
        and other.player_id <> candidate.player_id
    )
  )
  select pg_catalog.count(*)::integer
  into v_conflicting_secondary
  from unambiguous as candidate
  where exists (
    select 1
    from public.player_external_ids as external_id
    where external_id.namespace = candidate.namespace
      and external_id.sport = 'nfl'
      and external_id.external_id = candidate.external_id
      and external_id.player_id <> candidate.player_id
  );

  with candidates as (
    select candidate.*
    from app_private.sleeper_player_secondary_candidates(
      p_catalog_run_id
    ) as candidate
  ), acceptable as (
    select candidate.*
    from candidates as candidate
    where not exists (
      select 1
      from candidates as other
      where other.namespace = candidate.namespace
        and other.external_id = candidate.external_id
        and other.player_id <> candidate.player_id
    )
      and not exists (
        select 1
        from public.player_external_ids as external_id
        where external_id.namespace = candidate.namespace
          and external_id.sport = 'nfl'
          and external_id.external_id = candidate.external_id
          and external_id.player_id <> candidate.player_id
      )
  )
  select
    pg_catalog.count(*) filter (
      where not exists (
        select 1
        from public.player_external_ids as exact_id
        where exact_id.namespace = candidate.namespace
          and exact_id.sport = 'nfl'
          and exact_id.external_id = candidate.external_id
      )
      and not exists (
        select 1
        from public.player_external_ids as old_id
        where old_id.player_id = candidate.player_id
          and old_id.namespace = candidate.namespace
          and old_id.sport = 'nfl'
          and old_id.external_id <> candidate.external_id
          and old_id.removed_at is null
      )
    )::integer,
    pg_catalog.count(*) filter (
      where exists (
        select 1
        from public.player_external_ids as exact_id
        where exact_id.namespace = candidate.namespace
          and exact_id.sport = 'nfl'
          and exact_id.external_id = candidate.external_id
          and exact_id.player_id = candidate.player_id
      )
      and not exists (
        select 1
        from public.player_external_ids as old_id
        where old_id.player_id = candidate.player_id
          and old_id.namespace = candidate.namespace
          and old_id.sport = 'nfl'
          and old_id.external_id <> candidate.external_id
          and old_id.removed_at is null
      )
    )::integer,
    pg_catalog.count(*) filter (
      where exists (
        select 1
        from public.player_external_ids as old_id
        where old_id.player_id = candidate.player_id
          and old_id.namespace = candidate.namespace
          and old_id.sport = 'nfl'
          and old_id.external_id <> candidate.external_id
          and old_id.removed_at is null
      )
    )::integer
  into
    v_secondary_created,
    v_secondary_refreshed,
    v_secondary_replaced
  from acceptable as candidate;

  with candidates as (
    select candidate.*
    from app_private.sleeper_player_secondary_candidates(
      p_catalog_run_id
    ) as candidate
  ), acceptable as (
    select candidate.*
    from candidates as candidate
    where not exists (
      select 1
      from candidates as other
      where other.namespace = candidate.namespace
        and other.external_id = candidate.external_id
        and other.player_id <> candidate.player_id
    )
      and not exists (
        select 1
        from public.player_external_ids as external_id
        where external_id.namespace = candidate.namespace
          and external_id.sport = 'nfl'
          and external_id.external_id = candidate.external_id
          and external_id.player_id <> candidate.player_id
      )
  )
  update public.player_external_ids as old_id
  set
    removed_at = greatest(v_now, old_id.last_seen_at),
    updated_at = v_now
  from acceptable as candidate
  where old_id.player_id = candidate.player_id
    and old_id.namespace = candidate.namespace
    and old_id.sport = 'nfl'
    and old_id.external_id <> candidate.external_id
    and old_id.removed_at is null;

  with candidates as (
    select candidate.*
    from app_private.sleeper_player_secondary_candidates(
      p_catalog_run_id
    ) as candidate
  ), acceptable as (
    select candidate.*
    from candidates as candidate
    where not exists (
      select 1
      from candidates as other
      where other.namespace = candidate.namespace
        and other.external_id = candidate.external_id
        and other.player_id <> candidate.player_id
    )
      and not exists (
        select 1
        from public.player_external_ids as external_id
        where external_id.namespace = candidate.namespace
          and external_id.sport = 'nfl'
          and external_id.external_id = candidate.external_id
          and external_id.player_id <> candidate.player_id
      )
  )
  insert into public.player_external_ids (
    player_id,
    namespace,
    sport,
    external_id,
    reported_by,
    is_primary,
    source_metadata,
    first_seen_at,
    last_seen_at,
    removed_at,
    created_at,
    updated_at
  )
  select
    candidate.player_id,
    candidate.namespace,
    'nfl',
    candidate.external_id,
    'sleeper',
    false,
    pg_catalog.jsonb_build_object(
      'source_field', candidate.source_field
    ),
    v_run.source_fetched_at,
    v_run.source_fetched_at,
    null,
    v_now,
    v_now
  from acceptable as candidate
  order by candidate.namespace, candidate.external_id, candidate.player_id
  on conflict on constraint player_external_ids_namespace_sport_external_key
  do update set
    last_seen_at = greatest(
      public.player_external_ids.last_seen_at,
      excluded.last_seen_at
    ),
    removed_at = null,
    reported_by = 'sleeper',
    is_primary = false,
    source_metadata = excluded.source_metadata,
    updated_at = v_now
  where public.player_external_ids.player_id = excluded.player_id;

  update public.provider_catalog_runs as run
  set
    status = 'succeeded',
    progress_current = v_staged_count,
    progress_total = v_staged_count,
    result_counts = pg_catalog.jsonb_build_object(
      'observed_records', v_staged_count,
      'created_players', v_created_players,
      'updated_players', v_updated_players,
      'stale_player_profiles_skipped', v_stale_profiles,
      'created_sleeper_ids', v_created_sleeper_ids,
      'reactivated_sleeper_ids', v_reactivated_sleeper_ids,
      'removed_sleeper_ids', v_removed_sleeper_ids,
      'secondary_ids_created', v_secondary_created,
      'secondary_ids_refreshed', v_secondary_refreshed,
      'secondary_ids_replaced', v_secondary_replaced,
      'ambiguous_secondary_ids_skipped', v_ambiguous_secondary,
      'conflicting_secondary_ids_skipped', v_conflicting_secondary,
      'records_with_warnings', v_records_with_warnings,
      'normalization_warning_count', v_warning_count,
      'active_players', v_active_players,
      'team_defenses', v_team_defenses,
      'unknown_entities', v_unknown_entities
    ),
    error_summary = '{}'::jsonb,
    finished_at = v_now,
    updated_at = v_now
  where run.id = p_catalog_run_id;

  delete from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id;

  return query
  select
    p_catalog_run_id,
    v_staged_count,
    v_created_players,
    v_updated_players,
    v_stale_profiles,
    v_created_sleeper_ids,
    v_reactivated_sleeper_ids,
    v_removed_sleeper_ids,
    v_secondary_created,
    v_secondary_refreshed,
    v_secondary_replaced,
    v_ambiguous_secondary,
    v_conflicting_secondary,
    v_records_with_warnings,
    v_warning_count,
    v_active_players,
    v_team_defenses,
    v_unknown_entities;
end;
$$;

create or replace function public.fail_sleeper_player_catalog_sync(
  p_user_id uuid,
  p_catalog_run_id uuid,
  p_error_code text,
  p_error_message text,
  p_retryable boolean
)
returns table (
  catalog_run_id uuid,
  status text,
  changed_run boolean
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_run public.provider_catalog_runs%rowtype;
  v_error_code text := pg_catalog.btrim(p_error_code);
  v_error_message text := pg_catalog.btrim(p_error_message);
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_user_id is null or p_catalog_run_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid app user and catalog run are required.';
  end if;

  if not exists (
    select 1
    from auth.users as app_user
    where app_user.id = p_user_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  if not exists (
    select 1
    from public.user_fantasy_accounts as account_link
    inner join public.fantasy_accounts as account
      on account.id = account_link.fantasy_account_id
    where account_link.user_id = p_user_id
      and account.provider = 'sleeper'
  ) then
    raise exception using
      errcode = '42501',
      message = 'The app user must track a Sleeper fantasy account.';
  end if;

  select run.*
  into v_run
  from public.provider_catalog_runs as run
  where run.id = p_catalog_run_id
  for update;

  if not found
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.catalog <> 'players'
  then
    raise exception using
      errcode = '22023',
      message = 'The catalog run does not match this Sleeper player refresh.';
  end if;

  if v_run.status <> 'running' then
    return query
    select v_run.id, v_run.status, false;
    return;
  end if;

  if v_error_code is null
    or v_error_code !~ '^[a-z][a-z0-9_]{0,63}$'
    or v_error_message is null
    or pg_catalog.char_length(v_error_message) not between 1 and 255
    or v_error_message ~ '[[:cntrl:]]'
    or p_retryable is null
  then
    raise exception using
      errcode = '22023',
      message = 'The safe player-catalog error is invalid.';
  end if;

  update public.provider_catalog_runs as run
  set
    status = 'failed',
    error_summary = pg_catalog.jsonb_build_object(
      'code', v_error_code,
      'message', v_error_message,
      'retryable', p_retryable,
      'stage', 'player_catalog'
    ),
    finished_at = v_now,
    updated_at = v_now
  where run.id = p_catalog_run_id;

  delete from app_private.sleeper_player_catalog_stage as stage
  where stage.run_id = p_catalog_run_id;

  return query
  select p_catalog_run_id, 'failed'::text, true;
end;
$$;

revoke all on function public.start_sleeper_player_catalog_sync(uuid)
from public, anon, authenticated, service_role;
revoke all on function public.stage_sleeper_player_catalog_batch(
  uuid,
  uuid,
  integer,
  integer,
  timestamptz,
  integer,
  jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.complete_sleeper_player_catalog_sync(uuid, uuid)
from public, anon, authenticated, service_role;
revoke all on function public.fail_sleeper_player_catalog_sync(
  uuid,
  uuid,
  text,
  text,
  boolean
) from public, anon, authenticated, service_role;

grant execute on function public.start_sleeper_player_catalog_sync(uuid)
to service_role, postgres;
grant execute on function public.stage_sleeper_player_catalog_batch(
  uuid,
  uuid,
  integer,
  integer,
  timestamptz,
  integer,
  jsonb
) to service_role, postgres;
grant execute on function public.complete_sleeper_player_catalog_sync(uuid, uuid)
to service_role, postgres;
grant execute on function public.fail_sleeper_player_catalog_sync(
  uuid,
  uuid,
  text,
  text,
  boolean
) to service_role, postgres;
