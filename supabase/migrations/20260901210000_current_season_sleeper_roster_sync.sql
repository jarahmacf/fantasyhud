create or replace function app_private.jsonb_has_exact_keys(
  p_value jsonb,
  p_keys text[]
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
    pg_catalog.jsonb_typeof(p_value) = 'object'
    and array(
      select key
      from pg_catalog.jsonb_object_keys(p_value) as object_key(key)
      order by key collate "C"
    ) = array(
      select key
      from pg_catalog.unnest(p_keys) as expected(key)
      order by key collate "C"
    ),
    false
  );
$$;

revoke all on function app_private.jsonb_has_exact_keys(jsonb, text[])
from public, anon, authenticated, service_role;

create or replace function app_private.sorted_exact_text_array_is_safe(
  p_values text[],
  p_maximum_count integer
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
    app_private.exact_text_array_is_safe(
      p_values,
      p_maximum_count,
      true
    )
    and p_values = array(
      select item.value
      from pg_catalog.unnest(p_values) as item(value)
      order by item.value collate "C"
    ),
    false
  );
$$;

revoke all on function app_private.sorted_exact_text_array_is_safe(
  text[],
  integer
) from public, anon, authenticated, service_role;

create or replace function app_private.sleeper_roster_scope_hash(
  p_league_season integer,
  p_external_league_ids text[]
)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select pg_catalog.md5(
    pg_catalog.jsonb_build_object(
      'provider', 'sleeper',
      'sport', 'nfl',
      'league_season', p_league_season,
      'external_league_ids', pg_catalog.to_jsonb(p_external_league_ids)
    )::text
  );
$$;

revoke all on function app_private.sleeper_roster_scope_hash(integer, text[])
from public, anon, authenticated, service_role;

create table app_private.sleeper_roster_sync_scopes (
  run_id uuid primary key
    references public.sync_runs(id) on delete cascade,
  league_season integer not null,
  expected_external_league_ids text[] not null,
  scope_hash text not null,
  created_at timestamptz not null default now(),
  constraint sleeper_roster_sync_scopes_season_is_bounded check (
    league_season between 1900 and 2999
  ),
  constraint sleeper_roster_sync_scopes_leagues_are_safe check (
    app_private.sorted_exact_text_array_is_safe(
      expected_external_league_ids,
      250
    )
    and cardinality(expected_external_league_ids) between 1 and 250
  ),
  constraint sleeper_roster_sync_scopes_hash_is_digest check (
    scope_hash ~ '^[0-9a-f]{32}$'
  ),
  constraint sleeper_roster_sync_scopes_created_at_is_finite check (
    isfinite(created_at)
  )
);

comment on table app_private.sleeper_roster_sync_scopes is
  'Private immutable current-season league scope frozen when one account roster sync starts.';

create table app_private.sleeper_roster_sync_stage (
  run_id uuid not null
    references public.sync_runs(id) on delete cascade,
  league_id uuid not null
    references public.leagues(id) on delete cascade,
  external_league_id text not null,
  bundle_fetched_at timestamptz not null,
  bundle_hash text not null,
  normalized_bundle jsonb not null,
  created_at timestamptz not null default now(),
  primary key (run_id, league_id),
  constraint sleeper_roster_sync_stage_run_external_key unique (
    run_id,
    external_league_id
  ),
  constraint sleeper_roster_sync_stage_external_league_id_is_exact check (
    external_league_id = btrim(external_league_id)
    and char_length(external_league_id) between 1 and 255
    and external_league_id !~ '[[:cntrl:]]'
  ),
  constraint sleeper_roster_sync_stage_hash_is_digest check (
    bundle_hash ~ '^[0-9a-f]{32}$'
  ),
  constraint sleeper_roster_sync_stage_bundle_is_bounded_object check (
    jsonb_typeof(normalized_bundle) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(normalized_bundle::text, 'UTF8')
    ) <= 2000000
  ),
  constraint sleeper_roster_sync_stage_timestamps_are_finite check (
    isfinite(bundle_fetched_at)
    and isfinite(created_at)
  )
);

comment on table app_private.sleeper_roster_sync_stage is
  'One private, bounded, normalized users-and-rosters bundle per frozen league and roster-sync run.';

create index sleeper_roster_sync_stage_run_external_idx
  on app_private.sleeper_roster_sync_stage (run_id, external_league_id);

revoke all on table app_private.sleeper_roster_sync_scopes
from public, anon, authenticated, service_role;
revoke all on table app_private.sleeper_roster_sync_stage
from public, anon, authenticated, service_role;

alter table public.leagues
add column roster_bundle_fetched_at timestamptz;

alter table public.leagues
add constraint leagues_roster_bundle_fetched_at_is_finite check (
  roster_bundle_fetched_at is null
  or pg_catalog.isfinite(roster_bundle_fetched_at)
);

comment on column public.leagues.roster_bundle_fetched_at is
  'Observation time of the latest fully validated users-and-rosters bundle published for this shared league.';

alter table public.fantasy_account_leagues
add column roster_ownership_status text,
add column roster_ownership_observed_at timestamptz;

alter table public.fantasy_account_leagues
add constraint fantasy_account_leagues_roster_ownership_state_is_valid check (
  (
    roster_ownership_status is null
    and roster_ownership_observed_at is null
  )
  or (
    roster_ownership_status is not null
    and roster_ownership_status in ('owned', 'not_owned', 'unresolved')
    and roster_ownership_observed_at is not null
  )
),
add constraint fantasy_account_leagues_roster_ownership_time_is_finite check (
  roster_ownership_observed_at is null
  or pg_catalog.isfinite(roster_ownership_observed_at)
);

comment on column public.fantasy_account_leagues.roster_ownership_status is
  'Latest explicit roster ownership resolution for this tracked account and league: owned, not_owned, unresolved, or null before evaluation.';
comment on column public.fantasy_account_leagues.roster_ownership_observed_at is
  'Shared league roster-bundle watermark whose canonical current roster state produced roster_ownership_status.';

create index fantasy_account_leagues_current_roster_ownership_idx
  on public.fantasy_account_leagues (
    fantasy_account_id,
    roster_ownership_status,
    league_id
  )
  where removed_at is null;

do $$
declare
  v_definition text;
  v_old_predicate text := $predicate$
    and external_id.removed_at is null
    and not exists (
      select 1
      from app_private.sleeper_player_catalog_stage as stage
      where stage.run_id = p_catalog_run_id
        and stage.external_player_id = external_id.external_id
        and stage.player_id = external_id.player_id
    );
$predicate$;
  v_new_predicate text := $predicate$
    and external_id.removed_at is null
    and not exists (
      select 1
      from app_private.sleeper_player_catalog_stage as stage
      where stage.run_id = p_catalog_run_id
        and stage.external_player_id = external_id.external_id
        and stage.player_id = external_id.player_id
    )
    and not exists (
      select 1
      from public.roster_players as membership
      where membership.source_player_external_id_id = external_id.id
        and membership.removed_at is null
    );
$predicate$;
  v_occurrences integer;
begin
  select pg_catalog.pg_get_functiondef(
    'public.complete_sleeper_player_catalog_sync(uuid,uuid)'::regprocedure
  ) into v_definition;

  v_occurrences := (
    pg_catalog.length(v_definition)
      - pg_catalog.length(pg_catalog.replace(v_definition, v_old_predicate, ''))
  ) / pg_catalog.length(v_old_predicate);

  if v_occurrences <> 1 then
    raise exception using errcode = '55000',
      message = 'The player-catalog removal predicate did not match its reviewed definition.';
  end if;

  execute pg_catalog.replace(v_definition, v_old_predicate, v_new_predicate);
end;
$$;

comment on function public.complete_sleeper_player_catalog_sync(uuid, uuid) is
  'Publishes a full Sleeper player catalog while retaining exact primary mappings still used by active current roster memberships.';

create or replace function app_private.sleeper_roster_bundle_is_valid(
  p_bundle jsonb,
  p_expected_external_league_id text,
  p_expected_league_season integer,
  p_roster_positions jsonb
)
returns boolean
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_bundle_fetched_at timestamptz;
  v_user jsonb;
  v_roster jsonb;
  v_membership jsonb;
  v_co_owner_ids text[];
  v_player_ids text[];
  v_starter_ids text[];
  v_reserve_ids text[];
  v_taxi_ids text[];
  v_keeper_ids text[];
  v_starting_slots text[];
  v_external_player_id text;
  v_source_order integer;
  v_starter_order integer;
  v_expected_starter boolean;
  v_expected_slot text;
begin
  if not app_private.jsonb_has_exact_keys(
    p_bundle,
    array[
      'external_league_id',
      'league_season',
      'bundle_fetched_at',
      'users',
      'rosters',
      'source_metadata'
    ]
  )
    or pg_catalog.jsonb_typeof(p_bundle -> 'external_league_id') <> 'string'
    or p_bundle ->> 'external_league_id' <> p_expected_external_league_id
    or p_bundle ->> 'external_league_id' <> pg_catalog.btrim(
      p_bundle ->> 'external_league_id'
    )
    or pg_catalog.char_length(p_bundle ->> 'external_league_id')
      not between 1 and 255
    or p_bundle ->> 'external_league_id' ~ '[[:cntrl:]]'
    or pg_catalog.jsonb_typeof(p_bundle -> 'league_season') <> 'number'
    or (p_bundle ->> 'league_season') !~ '^[0-9]{4}$'
    or (p_bundle ->> 'league_season')::integer <> p_expected_league_season
    or p_expected_league_season not between 1900 and 2999
    or pg_catalog.jsonb_typeof(p_bundle -> 'bundle_fetched_at') <> 'string'
    or pg_catalog.jsonb_typeof(p_bundle -> 'users') <> 'array'
    or pg_catalog.jsonb_array_length(p_bundle -> 'users') > 1000
    or pg_catalog.jsonb_typeof(p_bundle -> 'rosters') <> 'array'
    or pg_catalog.jsonb_array_length(p_bundle -> 'rosters') > 1000
    or pg_catalog.jsonb_typeof(p_bundle -> 'source_metadata') <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to((p_bundle -> 'source_metadata')::text, 'UTF8')
    ) > 65536
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_bundle::text, 'UTF8')
    ) > 2000000
    or pg_catalog.jsonb_typeof(p_roster_positions) <> 'array'
  then
    return false;
  end if;

  v_bundle_fetched_at := (p_bundle ->> 'bundle_fetched_at')::timestamptz;
  if not pg_catalog.isfinite(v_bundle_fetched_at) then
    return false;
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(p_roster_positions) as slot(value)
    where pg_catalog.jsonb_typeof(slot.value) <> 'string'
      or slot.value #>> '{}' !~ '^[A-Z0-9_]{1,64}$'
  ) then
    return false;
  end if;

  select coalesce(
    pg_catalog.array_agg(slot.value #>> '{}' order by slot.ordinality),
    '{}'::text[]
  )
  into v_starting_slots
  from pg_catalog.jsonb_array_elements(p_roster_positions)
    with ordinality as slot(value, ordinality)
  where slot.value #>> '{}' not in ('BN', 'IR', 'TAXI');

  if exists (
    select submitted.value ->> 'external_user_id'
    from pg_catalog.jsonb_array_elements(p_bundle -> 'users') as submitted(value)
    group by submitted.value ->> 'external_user_id'
    having pg_catalog.count(*) > 1
  ) then
    return false;
  end if;

  for v_user in
    select submitted.value
    from pg_catalog.jsonb_array_elements(p_bundle -> 'users') as submitted(value)
  loop
    if not app_private.jsonb_has_exact_keys(
      v_user,
      array[
        'external_user_id',
        'username',
        'display_name',
        'team_name',
        'avatar_id',
        'avatar_url',
        'is_commissioner',
        'metadata'
      ]
    )
      or pg_catalog.jsonb_typeof(v_user -> 'external_user_id') <> 'string'
      or v_user ->> 'external_user_id' <> pg_catalog.btrim(
        v_user ->> 'external_user_id'
      )
      or pg_catalog.char_length(v_user ->> 'external_user_id')
        not between 1 and 255
      or v_user ->> 'external_user_id' ~ '[[:cntrl:]]'
      or pg_catalog.jsonb_typeof(v_user -> 'is_commissioner') <> 'boolean'
      or pg_catalog.jsonb_typeof(v_user -> 'metadata') <> 'object'
      or pg_catalog.octet_length(
        pg_catalog.convert_to((v_user -> 'metadata')::text, 'UTF8')
      ) > 65536
      or not (
        (v_user -> 'username' = 'null'::jsonb)
        or (
          pg_catalog.jsonb_typeof(v_user -> 'username') = 'string'
          and v_user ->> 'username' = pg_catalog.btrim(v_user ->> 'username')
          and pg_catalog.char_length(v_user ->> 'username') between 1 and 100
          and v_user ->> 'username' !~ '[[:cntrl:]]'
        )
      )
      or not (
        (v_user -> 'display_name' = 'null'::jsonb)
        or (
          pg_catalog.jsonb_typeof(v_user -> 'display_name') = 'string'
          and v_user ->> 'display_name' = pg_catalog.btrim(
            v_user ->> 'display_name'
          )
          and pg_catalog.char_length(v_user ->> 'display_name')
            between 1 and 255
          and v_user ->> 'display_name' !~ '[[:cntrl:]]'
        )
      )
      or not (
        (v_user -> 'team_name' = 'null'::jsonb)
        or (
          pg_catalog.jsonb_typeof(v_user -> 'team_name') = 'string'
          and v_user ->> 'team_name' = pg_catalog.btrim(
            v_user ->> 'team_name'
          )
          and pg_catalog.char_length(v_user ->> 'team_name') between 1 and 255
          and v_user ->> 'team_name' !~ '[[:cntrl:]]'
        )
      )
      or not (
        (v_user -> 'avatar_id' = 'null'::jsonb)
        or (
          pg_catalog.jsonb_typeof(v_user -> 'avatar_id') = 'string'
          and v_user ->> 'avatar_id' = pg_catalog.btrim(v_user ->> 'avatar_id')
          and pg_catalog.char_length(v_user ->> 'avatar_id') between 1 and 255
          and v_user ->> 'avatar_id' !~ '[[:cntrl:]]'
        )
      )
      or not (
        (v_user -> 'avatar_url' = 'null'::jsonb)
        or (
          pg_catalog.jsonb_typeof(v_user -> 'avatar_url') = 'string'
          and v_user ->> 'avatar_url' = pg_catalog.btrim(v_user ->> 'avatar_url')
          and pg_catalog.char_length(v_user ->> 'avatar_url') between 1 and 2048
          and v_user ->> 'avatar_url' !~ '[[:cntrl:]]'
        )
      )
    then
      return false;
    end if;
  end loop;

  if exists (
    select submitted.value ->> 'external_roster_id'
    from pg_catalog.jsonb_array_elements(p_bundle -> 'rosters') as submitted(value)
    group by submitted.value ->> 'external_roster_id'
    having pg_catalog.count(*) > 1
  ) then
    return false;
  end if;

  for v_roster in
    select submitted.value
    from pg_catalog.jsonb_array_elements(p_bundle -> 'rosters') as submitted(value)
  loop
    if not app_private.jsonb_has_exact_keys(
      v_roster,
      array[
        'external_roster_id',
        'owner_external_user_id',
        'co_owner_external_user_ids',
        'source_player_ids',
        'source_starter_ids',
        'source_reserve_ids',
        'source_taxi_ids',
        'source_keeper_ids',
        'settings',
        'metadata',
        'memberships'
      ]
    )
      or pg_catalog.jsonb_typeof(v_roster -> 'external_roster_id') <> 'number'
      or (v_roster ->> 'external_roster_id') !~ '^[1-9][0-9]{0,6}$'
      or (v_roster ->> 'external_roster_id')::integer > 1000000
      or not (
        v_roster -> 'owner_external_user_id' = 'null'::jsonb
        or (
          pg_catalog.jsonb_typeof(v_roster -> 'owner_external_user_id') = 'string'
          and v_roster ->> 'owner_external_user_id' = pg_catalog.btrim(
            v_roster ->> 'owner_external_user_id'
          )
          and pg_catalog.char_length(v_roster ->> 'owner_external_user_id')
            between 1 and 255
          and v_roster ->> 'owner_external_user_id' !~ '[[:cntrl:]]'
        )
      )
      or pg_catalog.jsonb_typeof(v_roster -> 'settings') <> 'object'
      or pg_catalog.octet_length(
        pg_catalog.convert_to((v_roster -> 'settings')::text, 'UTF8')
      ) > 131072
      or pg_catalog.jsonb_typeof(v_roster -> 'metadata') <> 'object'
      or pg_catalog.octet_length(
        pg_catalog.convert_to((v_roster -> 'metadata')::text, 'UTF8')
      ) > 65536
      or not (
        v_roster -> 'memberships' = 'null'::jsonb
        or (
          pg_catalog.jsonb_typeof(v_roster -> 'memberships') = 'array'
          and pg_catalog.jsonb_array_length(v_roster -> 'memberships') <= 1000
        )
      )
    then
      return false;
    end if;

    if exists (
      select 1
      from (values
        (v_roster -> 'co_owner_external_user_ids'),
        (v_roster -> 'source_player_ids'),
        (v_roster -> 'source_starter_ids'),
        (v_roster -> 'source_reserve_ids'),
        (v_roster -> 'source_taxi_ids'),
        (v_roster -> 'source_keeper_ids')
      ) as source_array(value)
      where source_array.value <> 'null'::jsonb
        and pg_catalog.jsonb_typeof(source_array.value) <> 'array'
    ) then
      return false;
    end if;

    if exists (
      select 1
      from (values
        (v_roster -> 'co_owner_external_user_ids'),
        (v_roster -> 'source_player_ids'),
        (v_roster -> 'source_starter_ids'),
        (v_roster -> 'source_reserve_ids'),
        (v_roster -> 'source_taxi_ids'),
        (v_roster -> 'source_keeper_ids')
      ) as source_array(value)
      cross join lateral pg_catalog.jsonb_array_elements(
        case
          when source_array.value = 'null'::jsonb then '[]'::jsonb
          else source_array.value
        end
      ) as item(value)
      where pg_catalog.jsonb_typeof(item.value) <> 'string'
    ) then
      return false;
    end if;

    v_co_owner_ids := case
      when v_roster -> 'co_owner_external_user_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(
          v_roster -> 'co_owner_external_user_ids'
        ) with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;
    v_player_ids := case
      when v_roster -> 'source_player_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(v_roster -> 'source_player_ids')
          with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;
    v_starter_ids := case
      when v_roster -> 'source_starter_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(v_roster -> 'source_starter_ids')
          with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;
    v_reserve_ids := case
      when v_roster -> 'source_reserve_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(v_roster -> 'source_reserve_ids')
          with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;
    v_taxi_ids := case
      when v_roster -> 'source_taxi_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(v_roster -> 'source_taxi_ids')
          with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;
    v_keeper_ids := case
      when v_roster -> 'source_keeper_ids' = 'null'::jsonb then null
      else array(
        select item.value #>> '{}'
        from pg_catalog.jsonb_array_elements(v_roster -> 'source_keeper_ids')
          with ordinality as item(value, ordinality)
        order by item.ordinality
      )
    end;

    if (v_co_owner_ids is not null and not app_private.exact_text_array_is_safe(v_co_owner_ids, 1000, true))
      or (v_player_ids is not null and not app_private.exact_text_array_is_safe(v_player_ids, 1000, true))
      or (v_starter_ids is not null and not app_private.exact_text_array_is_safe(v_starter_ids, 1000, false))
      or (v_reserve_ids is not null and not app_private.exact_text_array_is_safe(v_reserve_ids, 1000, true))
      or (v_taxi_ids is not null and not app_private.exact_text_array_is_safe(v_taxi_ids, 1000, true))
      or (v_keeper_ids is not null and not app_private.exact_text_array_is_safe(v_keeper_ids, 1000, true))
      or '0' = any(coalesce(v_player_ids, '{}'::text[]))
      or exists (
        select starter_id
        from pg_catalog.unnest(coalesce(v_starter_ids, '{}'::text[])) as starter(starter_id)
        where starter_id <> '0'
        group by starter_id
        having pg_catalog.count(*) > 1
      )
      or exists (
        select 1
        from pg_catalog.unnest(coalesce(v_starter_ids, '{}'::text[])) as starter(id)
        where starter.id <> '0'
          and not (starter.id = any(coalesce(v_player_ids, '{}'::text[])))
      )
      or exists (
        select 1
        from pg_catalog.unnest(
          coalesce(v_reserve_ids, '{}'::text[])
          || coalesce(v_taxi_ids, '{}'::text[])
          || coalesce(v_keeper_ids, '{}'::text[])
        ) as annotation(id)
        where not (annotation.id = any(coalesce(v_player_ids, '{}'::text[])))
      )
    then
      return false;
    end if;

    if (v_player_ids is null and v_roster -> 'memberships' <> 'null'::jsonb)
      or (
        v_player_ids is not null
        and (
          pg_catalog.jsonb_typeof(v_roster -> 'memberships') <> 'array'
          or pg_catalog.jsonb_array_length(v_roster -> 'memberships')
            <> pg_catalog.cardinality(v_player_ids)
        )
      )
      or exists (
        select submitted.value ->> 'external_player_id'
        from pg_catalog.jsonb_array_elements(
          case
            when v_roster -> 'memberships' = 'null'::jsonb then '[]'::jsonb
            else v_roster -> 'memberships'
          end
        ) as submitted(value)
        group by submitted.value ->> 'external_player_id'
        having pg_catalog.count(*) > 1
      )
    then
      return false;
    end if;

    for v_membership in
      select submitted.value
      from pg_catalog.jsonb_array_elements(
        case
          when v_roster -> 'memberships' = 'null'::jsonb then '[]'::jsonb
          else v_roster -> 'memberships'
        end
      ) as submitted(value)
    loop
      if not app_private.jsonb_has_exact_keys(
        v_membership,
        array[
          'external_player_id',
          'source_order',
          'is_starter',
          'starter_order',
          'starter_slot',
          'is_reserve',
          'is_taxi',
          'is_keeper',
          'source_metadata'
        ]
      )
        or pg_catalog.jsonb_typeof(v_membership -> 'external_player_id') <> 'string'
        or not (
          (v_membership ->> 'external_player_id') = any(
            coalesce(v_player_ids, '{}'::text[])
          )
        )
        or pg_catalog.jsonb_typeof(v_membership -> 'source_order') <> 'number'
        or (v_membership ->> 'source_order') !~ '^[1-9][0-9]{0,3}$'
        or (v_membership ->> 'source_order')::integer > 1000
        or pg_catalog.jsonb_typeof(v_membership -> 'is_starter') <> 'boolean'
        or pg_catalog.jsonb_typeof(v_membership -> 'is_reserve') <> 'boolean'
        or pg_catalog.jsonb_typeof(v_membership -> 'is_taxi') <> 'boolean'
        or pg_catalog.jsonb_typeof(v_membership -> 'is_keeper') <> 'boolean'
        or pg_catalog.jsonb_typeof(v_membership -> 'source_metadata') <> 'object'
        or pg_catalog.octet_length(
          pg_catalog.convert_to(
            (v_membership -> 'source_metadata')::text,
            'UTF8'
          )
        ) > 32768
      then
        return false;
      end if;

      if not app_private.jsonb_has_exact_keys(
        v_membership -> 'source_metadata',
        array['annotation_source_state', 'normalization_warning_fields']
      )
        or not app_private.jsonb_has_exact_keys(
          v_membership -> 'source_metadata' -> 'annotation_source_state',
          array['starters', 'reserve', 'taxi', 'keepers']
        )
        or pg_catalog.jsonb_typeof(
          v_membership -> 'source_metadata' -> 'normalization_warning_fields'
        ) <> 'array'
        or pg_catalog.jsonb_typeof(
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            -> 'starters'
        ) <> 'string'
        or pg_catalog.jsonb_typeof(
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            -> 'reserve'
        ) <> 'string'
        or pg_catalog.jsonb_typeof(
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            -> 'taxi'
        ) <> 'string'
        or pg_catalog.jsonb_typeof(
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            -> 'keepers'
        ) <> 'string'
        or v_membership -> 'source_metadata' -> 'annotation_source_state'
          ->> 'starters' not in ('known', 'unknown')
        or v_membership -> 'source_metadata' -> 'annotation_source_state'
          ->> 'reserve' not in ('known', 'unknown')
        or v_membership -> 'source_metadata' -> 'annotation_source_state'
          ->> 'taxi' not in ('known', 'unknown')
        or v_membership -> 'source_metadata' -> 'annotation_source_state'
          ->> 'keepers' not in ('known', 'unknown')
        or (
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            ->> 'starters'
        ) <> (
          case when v_starter_ids is null then 'unknown' else 'known' end
        )
        or (
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            ->> 'reserve'
        ) <> (
          case when v_reserve_ids is null then 'unknown' else 'known' end
        )
        or (
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            ->> 'taxi'
        ) <> (
          case when v_taxi_ids is null then 'unknown' else 'known' end
        )
        or (
          v_membership -> 'source_metadata' -> 'annotation_source_state'
            ->> 'keepers'
        ) <> (
          case when v_keeper_ids is null then 'unknown' else 'known' end
        )
      then
        return false;
      end if;

      if pg_catalog.jsonb_array_length(
        v_membership -> 'source_metadata' -> 'normalization_warning_fields'
      ) > 16 or exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          v_membership -> 'source_metadata' -> 'normalization_warning_fields'
        ) as warning(value)
        where pg_catalog.jsonb_typeof(warning.value) <> 'string'
          or warning.value #>> '{}' !~ '^[a-z][a-z0-9_]{0,63}$'
      ) or exists (
        select warning.value #>> '{}'
        from pg_catalog.jsonb_array_elements(
          v_membership -> 'source_metadata' -> 'normalization_warning_fields'
        ) as warning(value)
        group by warning.value #>> '{}'
        having pg_catalog.count(*) > 1
      ) then
        return false;
      end if;

      v_external_player_id := v_membership ->> 'external_player_id';
      v_source_order := (v_membership ->> 'source_order')::integer;
      if v_source_order <> pg_catalog.array_position(
        v_player_ids,
        v_external_player_id
      ) then
        return false;
      end if;

      v_expected_starter := v_starter_ids is not null
        and v_external_player_id = any(v_starter_ids);
      v_starter_order := case
        when v_expected_starter then pg_catalog.array_position(
          v_starter_ids,
          v_external_player_id
        )
        else null
      end;
      v_expected_slot := case
        when v_expected_starter
          and pg_catalog.cardinality(v_starting_slots) = pg_catalog.cardinality(v_starter_ids)
          then v_starting_slots[v_starter_order]
        else null
      end;

      if (v_membership ->> 'is_starter')::boolean <> v_expected_starter
        or not (
          (v_starter_order is null and v_membership -> 'starter_order' = 'null'::jsonb)
          or (
            v_starter_order is not null
            and pg_catalog.jsonb_typeof(v_membership -> 'starter_order') = 'number'
            and (v_membership ->> 'starter_order')::integer = v_starter_order
          )
        )
        or not (
          (v_expected_slot is null and v_membership -> 'starter_slot' = 'null'::jsonb)
          or (
            v_expected_slot is not null
            and pg_catalog.jsonb_typeof(v_membership -> 'starter_slot') = 'string'
            and v_membership ->> 'starter_slot' = v_expected_slot
          )
        )
        or (v_membership ->> 'is_reserve')::boolean <> (
          v_reserve_ids is not null and v_external_player_id = any(v_reserve_ids)
        )
        or (v_membership ->> 'is_taxi')::boolean <> (
          v_taxi_ids is not null and v_external_player_id = any(v_taxi_ids)
        )
        or (v_membership ->> 'is_keeper')::boolean <> (
          v_keeper_ids is not null and v_external_player_id = any(v_keeper_ids)
        )
      then
        return false;
      end if;
    end loop;
  end loop;

  return true;
exception
  when others then
    return false;
end;
$$;

revoke all on function app_private.sleeper_roster_bundle_is_valid(
  jsonb,
  text,
  integer,
  jsonb
) from public, anon, authenticated, service_role;

create or replace function public.start_sleeper_roster_sync(
  p_user_id uuid,
  p_fantasy_account_id uuid
)
returns table (
  sync_run_id uuid,
  created_run boolean,
  reused_run boolean,
  recovered_stale_run boolean,
  league_season integer,
  expected_external_league_ids text[]
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_account_provider text;
  v_league_season integer;
  v_expected_ids text[];
  v_scope_hash text;
  v_run public.sync_runs%rowtype;
  v_scope app_private.sleeper_roster_sync_scopes%rowtype;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_recovered boolean := false;
  v_scope_valid boolean;
begin
  if p_user_id is null or p_fantasy_account_id is null then
    raise exception using errcode = '22023',
      message = 'A valid app user and fantasy account are required.';
  end if;

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception using errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  select account.provider
  into v_account_provider
  from public.fantasy_accounts as account
  inner join public.user_fantasy_accounts as account_link
    on account_link.fantasy_account_id = account.id
  where account.id = p_fantasy_account_id
    and account_link.user_id = p_user_id
  for update of account;

  if not found then
    raise exception using errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;
  if v_account_provider <> 'sleeper' then
    raise exception using errcode = '22023',
      message = 'Roster import requires a Sleeper fantasy account.';
  end if;

  if not exists (
    select 1
    from public.provider_catalog_runs as catalog_run
    where catalog_run.provider = 'sleeper'
      and catalog_run.sport = 'nfl'
      and catalog_run.catalog = 'players'
      and catalog_run.status = 'succeeded'
  ) or (
    select pg_catalog.count(*)
    from public.player_external_ids as external_id
    where external_id.namespace = 'sleeper'
      and external_id.sport = 'nfl'
      and external_id.is_primary
      and external_id.removed_at is null
  ) < 500 then
    raise exception using errcode = '55000',
      message = 'Import the Sleeper player catalog before importing rosters.';
  end if;

  select state.league_season
  into v_league_season
  from public.provider_season_states as state
  where state.provider = 'sleeper' and state.sport = 'nfl';
  if not found then
    raise exception using errcode = '55000',
      message = 'Import current-season leagues before importing rosters.';
  end if;

  select run.*
  into v_run
  from public.sync_runs as run
  where run.fantasy_account_id = p_fantasy_account_id
    and run.provider = 'sleeper'
    and run.sport = 'nfl'
    and run.scope = 'roster_sync'
    and run.status = 'running'
  for update;

  if found then
    select scope.*
    into v_scope
    from app_private.sleeper_roster_sync_scopes as scope
    where scope.run_id = v_run.id
    for update;

    v_scope_valid := found
      and v_run.season = v_scope.league_season
      and v_run.progress_total = pg_catalog.cardinality(
        v_scope.expected_external_league_ids
      )
      and app_private.sorted_exact_text_array_is_safe(
        v_scope.expected_external_league_ids,
        250
      )
      and v_scope.scope_hash = app_private.sleeper_roster_scope_hash(
        v_scope.league_season,
        v_scope.expected_external_league_ids
      );

    if v_run.updated_at >= v_now - interval '15 minutes' and v_scope_valid then
      return query select
        v_run.id,
        false,
        true,
        false,
        v_scope.league_season,
        v_scope.expected_external_league_ids;
      return;
    end if;

    update public.sync_runs as stale_run
    set
      status = 'failed',
      error_summary = case
        when v_scope_valid then pg_catalog.jsonb_build_object(
          'code', 'stale_roster_sync',
          'message', 'The previous roster import stopped before completion.',
          'retryable', true,
          'stage', 'roster_sync'
        )
        else pg_catalog.jsonb_build_object(
          'code', 'invalid_sync_scope',
          'message', 'The previous roster import had an invalid frozen scope.',
          'retryable', true,
          'stage', 'roster_sync'
        )
      end,
      finished_at = v_now,
      updated_at = v_now
    where stale_run.id = v_run.id;

    delete from app_private.sleeper_roster_sync_stage where run_id = v_run.id;
    delete from app_private.sleeper_roster_sync_scopes where run_id = v_run.id;
    v_recovered := true;
  end if;

  select pg_catalog.array_agg(
    league.external_league_id order by league.external_league_id collate "C"
  )
  into v_expected_ids
  from public.fantasy_account_leagues as association
  inner join public.leagues as league on league.id = association.league_id
  where association.fantasy_account_id = p_fantasy_account_id
    and association.removed_at is null
    and league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_league_season;

  if v_expected_ids is null
    or pg_catalog.cardinality(v_expected_ids) not between 1 and 250
    or not app_private.sorted_exact_text_array_is_safe(v_expected_ids, 250)
  then
    raise exception using errcode = '55000',
      message = 'Import current-season leagues before importing rosters.';
  end if;

  v_scope_hash := app_private.sleeper_roster_scope_hash(
    v_league_season,
    v_expected_ids
  );

  insert into public.sync_runs (
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
    updated_at
  ) values (
    p_fantasy_account_id,
    p_user_id,
    'sleeper',
    'nfl',
    v_league_season,
    'roster_sync',
    'running',
    0,
    pg_catalog.cardinality(v_expected_ids),
    v_now,
    v_now
  ) returning public.sync_runs.* into v_run;

  insert into app_private.sleeper_roster_sync_scopes (
    run_id,
    league_season,
    expected_external_league_ids,
    scope_hash,
    created_at
  ) values (
    v_run.id,
    v_league_season,
    v_expected_ids,
    v_scope_hash,
    v_now
  );

  return query select
    v_run.id,
    true,
    false,
    v_recovered,
    v_league_season,
    v_expected_ids;
end;
$$;

create or replace function public.stage_sleeper_roster_league_bundle(
  p_user_id uuid,
  p_fantasy_account_id uuid,
  p_sync_run_id uuid,
  p_external_league_id text,
  p_bundle jsonb
)
returns table (
  sync_run_id uuid,
  staged_leagues integer,
  progress_total integer,
  replayed_bundle boolean
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_account_provider text;
  v_run public.sync_runs%rowtype;
  v_scope app_private.sleeper_roster_sync_scopes%rowtype;
  v_league_id uuid;
  v_roster_positions jsonb;
  v_bundle_fetched_at timestamptz;
  v_bundle_hash text;
  v_existing_external_league_id text;
  v_existing_hash text;
  v_staged integer;
  v_inserted boolean := false;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_user_id is null or p_fantasy_account_id is null
    or p_sync_run_id is null or p_external_league_id is null
    or p_external_league_id <> pg_catalog.btrim(p_external_league_id)
    or pg_catalog.char_length(p_external_league_id) not between 1 and 255
    or p_external_league_id ~ '[[:cntrl:]]'
    or p_bundle is null
  then
    raise exception using errcode = '22023',
      message = 'The roster-sync bundle envelope is invalid.';
  end if;

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception using errcode = '22023', message = 'A valid app user is required.';
  end if;

  select account.provider
  into v_account_provider
  from public.fantasy_accounts as account
  inner join public.user_fantasy_accounts as account_link
    on account_link.fantasy_account_id = account.id
  where account.id = p_fantasy_account_id
    and account_link.user_id = p_user_id
  for update of account;
  if not found then
    raise exception using errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  select run.* into v_run
  from public.sync_runs as run
  where run.id = p_sync_run_id
  for update;
  if not found
    or v_account_provider <> 'sleeper'
    or v_run.fantasy_account_id <> p_fantasy_account_id
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.scope <> 'roster_sync'
    or v_run.status <> 'running'
  then
    raise exception using errcode = '22023',
      message = 'The sync run does not match this running Sleeper roster import.';
  end if;

  select scope.* into v_scope
  from app_private.sleeper_roster_sync_scopes as scope
  where scope.run_id = p_sync_run_id
  for update;
  if not found
    or v_scope.league_season <> v_run.season
    or not (p_external_league_id = any(v_scope.expected_external_league_ids))
  then
    raise exception using errcode = '22023',
      message = 'The league is outside the frozen roster-sync scope.';
  end if;

  select league.id, league.roster_positions
  into v_league_id, v_roster_positions
  from public.leagues as league
  inner join public.fantasy_account_leagues as association
    on association.league_id = league.id
    and association.fantasy_account_id = p_fantasy_account_id
    and association.removed_at is null
  where league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_scope.league_season
    and league.external_league_id = p_external_league_id;
  if not found then
    raise exception using errcode = '22023',
      message = 'The frozen league is no longer an active current-season association.';
  end if;

  if not app_private.sleeper_roster_bundle_is_valid(
    p_bundle,
    p_external_league_id,
    v_scope.league_season,
    v_roster_positions
  ) then
    raise exception using errcode = '22023',
      message = 'The normalized roster league bundle is invalid.';
  end if;

  v_bundle_fetched_at := (p_bundle ->> 'bundle_fetched_at')::timestamptz;
  v_bundle_hash := pg_catalog.md5(p_bundle::text);

  insert into app_private.sleeper_roster_sync_stage (
    run_id,
    league_id,
    external_league_id,
    bundle_fetched_at,
    bundle_hash,
    normalized_bundle,
    created_at
  ) values (
    p_sync_run_id,
    v_league_id,
    p_external_league_id,
    v_bundle_fetched_at,
    v_bundle_hash,
    p_bundle,
    v_now
  ) on conflict do nothing
  returning true into v_inserted;

  v_inserted := found;
  if not v_inserted then
    select stage.external_league_id, stage.bundle_hash
    into v_existing_external_league_id, v_existing_hash
    from app_private.sleeper_roster_sync_stage as stage
    where stage.run_id = p_sync_run_id and stage.league_id = v_league_id
    for update;
    if not found
      or v_existing_external_league_id <> p_external_league_id
      or v_existing_hash <> v_bundle_hash
    then
      raise exception using errcode = '22023',
        message = 'A staged league bundle changed during this roster import.';
    end if;
  end if;

  select pg_catalog.count(*)::integer into v_staged
  from app_private.sleeper_roster_sync_stage as stage
  where stage.run_id = p_sync_run_id;
  if v_staged > v_run.progress_total then
    raise exception using errcode = '22023',
      message = 'Roster-sync progress exceeds the frozen scope.';
  end if;

  update public.sync_runs as run
  set progress_current = v_staged, updated_at = v_now
  where run.id = p_sync_run_id;

  return query select p_sync_run_id, v_staged, v_run.progress_total, not v_inserted;
end;
$$;

create or replace function public.complete_sleeper_roster_sync(
  p_user_id uuid,
  p_fantasy_account_id uuid,
  p_sync_run_id uuid
)
returns table (
  sync_run_id uuid,
  final_status text,
  observed_leagues integer,
  applied_shared_league_bundles integer,
  stale_shared_league_bundles_skipped integer,
  observed_league_users integer,
  observed_rosters integer,
  observed_memberships integer,
  created_league_users integer,
  updated_league_users integer,
  stale_league_users_skipped integer,
  removed_league_users integer,
  created_rosters integer,
  updated_rosters integer,
  stale_rosters_skipped integer,
  removed_rosters integer,
  created_memberships integer,
  updated_memberships integer,
  stale_memberships_skipped integer,
  removed_memberships integer,
  created_ownerships integer,
  reactivated_ownerships integer,
  removed_ownerships integer,
  owned_leagues integer,
  confirmed_not_owned_leagues integer,
  unresolved_ownership_leagues integer,
  stale_ownership_resolutions_skipped integer,
  created_reference_players integer,
  reactivated_player_mappings integer,
  placeholder_starter_values integer,
  active_owned_rosters integer,
  active_owned_memberships integer
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '60s'
as $$
declare
  v_account_provider text;
  v_account_external_user_id text;
  v_run public.sync_runs%rowtype;
  v_scope app_private.sleeper_roster_sync_scopes%rowtype;
  v_stage record;
  v_user jsonb;
  v_roster jsonb;
  v_membership jsonb;
  v_league_user_id uuid;
  v_roster_id uuid;
  v_mapping_id uuid;
  v_mapping_player_id uuid;
  v_candidate_player_id uuid;
  v_existing_fetched_at timestamptz;
  v_mapping_removed_at timestamptz;
  v_mapping_last_seen_at timestamptz;
  v_bundle_fetched_at timestamptz;
  v_co_owner_ids text[];
  v_player_ids text[];
  v_starter_ids text[];
  v_reserve_ids text[];
  v_taxi_ids text[];
  v_keeper_ids text[];
  v_external_player_id text;
  v_external_roster_id integer;
  v_roster_fresh boolean;
  v_inserted boolean;
  v_match_count integer;
  v_matched_external_roster_id integer;
  v_matched_role text;
  v_has_unresolved_coowners boolean;
  v_shared_bundle_watermark timestamptz;
  v_ownership_observed_at timestamptz;
  v_existing_ownership_observed_at timestamptz;
  v_existing_ownership_status text;
  v_resolved_ownership_status text;
  v_shared_bundle_is_fresh boolean;
  v_ownership_removed_at timestamptz;
  v_staged_count integer;
  v_source_user_endpoint_successes bigint := 0;
  v_source_roster_endpoint_successes bigint := 0;
  v_source_endpoint_successes bigint := 0;
  v_source_response_bytes bigint := 0;
  v_source_fetch_duration_ms_total bigint := 0;
  v_source_fetch_duration_ms_max bigint := 0;
  v_source_collection_started_at timestamptz;
  v_source_collection_finished_at timestamptz;
  v_stage_first_created_at timestamptz;
  v_stage_last_created_at timestamptz;
  v_source_collection_window_ms bigint := 0;
  v_stage_insert_window_ms bigint := 0;
  v_stage_to_completion_ms bigint := 0;
  v_completion_duration_ms bigint := 0;
  v_completion_started_at timestamptz := pg_catalog.clock_timestamp();
  v_finished_at timestamptz;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_final_status text;
  v_observed_leagues integer := 0;
  v_applied_shared_bundles integer := 0;
  v_stale_shared_bundles integer := 0;
  v_observed_users integer := 0;
  v_observed_rosters integer := 0;
  v_observed_memberships integer := 0;
  v_created_users integer := 0;
  v_updated_users integer := 0;
  v_stale_users integer := 0;
  v_removed_users integer := 0;
  v_created_rosters integer := 0;
  v_updated_rosters integer := 0;
  v_stale_rosters integer := 0;
  v_removed_rosters integer := 0;
  v_created_memberships integer := 0;
  v_updated_memberships integer := 0;
  v_stale_memberships integer := 0;
  v_removed_memberships integer := 0;
  v_created_ownerships integer := 0;
  v_reactivated_ownerships integer := 0;
  v_removed_ownerships integer := 0;
  v_owned_leagues integer := 0;
  v_confirmed_not_owned_leagues integer := 0;
  v_unresolved_ownership integer := 0;
  v_stale_ownership_resolutions integer := 0;
  v_created_reference_players integer := 0;
  v_reactivated_mappings integer := 0;
  v_placeholder_values integer := 0;
  v_active_owned_rosters integer := 0;
  v_active_owned_memberships integer := 0;
  v_row_count integer;
begin
  if p_user_id is null or p_fantasy_account_id is null or p_sync_run_id is null then
    raise exception using errcode = '22023',
      message = 'A valid app user, fantasy account, and sync run are required.';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception using errcode = '22023', message = 'A valid app user is required.';
  end if;

  select account.provider, account.external_user_id
  into v_account_provider, v_account_external_user_id
  from public.fantasy_accounts as account
  inner join public.user_fantasy_accounts as account_link
    on account_link.fantasy_account_id = account.id
  where account.id = p_fantasy_account_id
    and account_link.user_id = p_user_id
  for update of account;
  if not found then
    raise exception using errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  select run.* into v_run
  from public.sync_runs as run
  where run.id = p_sync_run_id
  for update;
  if not found
    or v_account_provider <> 'sleeper'
    or v_run.fantasy_account_id <> p_fantasy_account_id
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.scope <> 'roster_sync'
    or v_run.status <> 'running'
  then
    raise exception using errcode = '22023',
      message = 'The sync run does not match this running Sleeper roster import.';
  end if;

  select scope.* into v_scope
  from app_private.sleeper_roster_sync_scopes as scope
  where scope.run_id = p_sync_run_id
  for update;
  if not found
    or v_scope.league_season <> v_run.season
    or v_scope.scope_hash <> app_private.sleeper_roster_scope_hash(
      v_scope.league_season,
      v_scope.expected_external_league_ids
    )
  then
    raise exception using errcode = '22023',
      message = 'The roster import has an invalid frozen scope.';
  end if;

  select pg_catalog.count(*)::integer into v_staged_count
  from app_private.sleeper_roster_sync_stage as stage
  where stage.run_id = p_sync_run_id;
  if v_staged_count <> v_run.progress_total
    or v_staged_count <> pg_catalog.cardinality(v_scope.expected_external_league_ids)
    or exists (
      select expected.external_league_id
      from pg_catalog.unnest(v_scope.expected_external_league_ids)
        as expected(external_league_id)
      except
      select stage.external_league_id
      from app_private.sleeper_roster_sync_stage as stage
      where stage.run_id = p_sync_run_id
    )
    or exists (
      select stage.external_league_id
      from app_private.sleeper_roster_sync_stage as stage
      where stage.run_id = p_sync_run_id
      except
      select expected.external_league_id
      from pg_catalog.unnest(v_scope.expected_external_league_ids)
        as expected(external_league_id)
    )
  then
    raise exception using errcode = '22023',
      message = 'The staged roster collection does not equal the frozen scope.';
  end if;

  for v_stage in
    select
      stage.league_id,
      stage.external_league_id,
      stage.bundle_fetched_at,
      stage.normalized_bundle,
      league.roster_positions
    from app_private.sleeper_roster_sync_stage as stage
    inner join public.leagues as league on league.id = stage.league_id
    where stage.run_id = p_sync_run_id
    order by stage.external_league_id collate "C"
  loop
    if not app_private.sleeper_roster_bundle_is_valid(
      v_stage.normalized_bundle,
      v_stage.external_league_id,
      v_scope.league_season,
      v_stage.roster_positions
    ) then
      raise exception using errcode = '22023',
        message = 'A staged roster league bundle failed final validation.';
      end if;
  end loop;

  -- These are bounded, server-produced source metrics. The collection window
  -- is derived as earliest (bundle time - that league's monotonic fetch
  -- duration) through latest bundle time; it is not provider-reported wall
  -- time. Missing or malformed optional metrics contribute zero.
  with stage_metrics as (
    select
      stage.bundle_fetched_at,
      stage.created_at,
      case
        when pg_catalog.jsonb_typeof(
          stage.normalized_bundle -> 'source_metadata'
            -> 'users_endpoint_succeeded'
        ) = 'number'
          and stage.normalized_bundle -> 'source_metadata'
            ->> 'users_endpoint_succeeded' ~ '^[01]$'
          then (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'users_endpoint_succeeded'
          )::bigint
        else 0
      end as users_endpoint_succeeded,
      case
        when pg_catalog.jsonb_typeof(
          stage.normalized_bundle -> 'source_metadata'
            -> 'rosters_endpoint_succeeded'
        ) = 'number'
          and stage.normalized_bundle -> 'source_metadata'
            ->> 'rosters_endpoint_succeeded' ~ '^[01]$'
          then (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'rosters_endpoint_succeeded'
          )::bigint
        else 0
      end as rosters_endpoint_succeeded,
      case
        when pg_catalog.jsonb_typeof(
          stage.normalized_bundle -> 'source_metadata'
            -> 'users_response_bytes'
        ) = 'number'
          and stage.normalized_bundle -> 'source_metadata'
            ->> 'users_response_bytes' ~ '^[0-9]{1,7}$'
          and (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'users_response_bytes'
          )::bigint <= 5000000
          then (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'users_response_bytes'
          )::bigint
        else 0
      end as users_response_bytes,
      case
        when pg_catalog.jsonb_typeof(
          stage.normalized_bundle -> 'source_metadata'
            -> 'rosters_response_bytes'
        ) = 'number'
          and stage.normalized_bundle -> 'source_metadata'
            ->> 'rosters_response_bytes' ~ '^[0-9]{1,7}$'
          and (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'rosters_response_bytes'
          )::bigint <= 5000000
          then (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'rosters_response_bytes'
          )::bigint
        else 0
      end as rosters_response_bytes,
      case
        when pg_catalog.jsonb_typeof(
          stage.normalized_bundle -> 'source_metadata'
            -> 'source_fetch_duration_ms'
        ) = 'number'
          and stage.normalized_bundle -> 'source_metadata'
            ->> 'source_fetch_duration_ms' ~ '^[0-9]{1,6}$'
          and (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'source_fetch_duration_ms'
          )::bigint <= 600000
          then (
            stage.normalized_bundle -> 'source_metadata'
              ->> 'source_fetch_duration_ms'
          )::bigint
        else 0
      end as source_fetch_duration_ms
    from app_private.sleeper_roster_sync_stage as stage
    where stage.run_id = p_sync_run_id
  )
  select
    coalesce(pg_catalog.sum(metric.users_endpoint_succeeded), 0)::bigint,
    coalesce(pg_catalog.sum(metric.rosters_endpoint_succeeded), 0)::bigint,
    coalesce(pg_catalog.sum(
      metric.users_response_bytes + metric.rosters_response_bytes
    ), 0)::bigint,
    coalesce(pg_catalog.sum(metric.source_fetch_duration_ms), 0)::bigint,
    coalesce(pg_catalog.max(metric.source_fetch_duration_ms), 0)::bigint,
    pg_catalog.min(
      metric.bundle_fetched_at
        - metric.source_fetch_duration_ms::double precision
          * interval '1 millisecond'
    ),
    pg_catalog.max(metric.bundle_fetched_at),
    pg_catalog.min(metric.created_at),
    pg_catalog.max(metric.created_at)
  into
    v_source_user_endpoint_successes,
    v_source_roster_endpoint_successes,
    v_source_response_bytes,
    v_source_fetch_duration_ms_total,
    v_source_fetch_duration_ms_max,
    v_source_collection_started_at,
    v_source_collection_finished_at,
    v_stage_first_created_at,
    v_stage_last_created_at
  from stage_metrics as metric;

  v_source_endpoint_successes := v_source_user_endpoint_successes
    + v_source_roster_endpoint_successes;

  v_source_collection_window_ms := greatest(
    0,
    pg_catalog.round(
      extract(
        epoch from v_source_collection_finished_at
          - v_source_collection_started_at
      ) * 1000
    )::bigint
  );
  v_stage_insert_window_ms := greatest(
    0,
    pg_catalog.round(
      extract(
        epoch from v_stage_last_created_at - v_stage_first_created_at
      ) * 1000
    )::bigint
  );
  v_stage_to_completion_ms := greatest(
    0,
    pg_catalog.round(
      extract(
        epoch from v_completion_started_at - v_stage_first_created_at
      ) * 1000
    )::bigint
  );

  -- Transactions that touch overlapping leagues acquire the same locks in the
  -- same canonical order before any public write.
  for v_stage in
    select stage.external_league_id
    from app_private.sleeper_roster_sync_stage as stage
    where stage.run_id = p_sync_run_id
    order by stage.external_league_id collate "C"
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'sleeper:nfl:roster-league:' || v_stage.external_league_id,
        0
      )
    );
  end loop;

  -- Coordinate sparse identity creation with the existing catalog publisher.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sleeper:nfl:players', 0)
  );

  for v_stage in
    select
      stage.league_id,
      stage.external_league_id,
      stage.bundle_fetched_at,
      stage.normalized_bundle
    from app_private.sleeper_roster_sync_stage as stage
    where stage.run_id = p_sync_run_id
    order by stage.external_league_id collate "C"
  loop
    v_bundle_fetched_at := v_stage.bundle_fetched_at;
    v_observed_leagues := v_observed_leagues + 1;
    v_observed_users := v_observed_users
      + pg_catalog.jsonb_array_length(v_stage.normalized_bundle -> 'users');
    v_observed_rosters := v_observed_rosters
      + pg_catalog.jsonb_array_length(v_stage.normalized_bundle -> 'rosters');
    select v_observed_memberships + coalesce(pg_catalog.sum(
      case
        when roster.value -> 'memberships' = 'null'::jsonb then 0
        else pg_catalog.jsonb_array_length(roster.value -> 'memberships')
      end
    ), 0)::integer
    into v_observed_memberships
    from pg_catalog.jsonb_array_elements(
      v_stage.normalized_bundle -> 'rosters'
    ) as roster(value);
    select v_placeholder_values + coalesce(pg_catalog.count(*), 0)::integer
    into v_placeholder_values
    from pg_catalog.jsonb_array_elements(
      v_stage.normalized_bundle -> 'rosters'
    ) as roster(value)
    cross join lateral pg_catalog.jsonb_array_elements_text(
      case
        when roster.value -> 'source_starter_ids' = 'null'::jsonb
          then '[]'::jsonb
        else roster.value -> 'source_starter_ids'
      end
    ) as starter(value)
    where starter.value = '0';

    select league.roster_bundle_fetched_at
    into v_shared_bundle_watermark
    from public.leagues as league
    where league.id = v_stage.league_id
    for update;
    if not found then
      raise exception using errcode = '55000',
        message = 'The canonical shared league could not be resolved.';
    end if;

    v_shared_bundle_is_fresh := v_shared_bundle_watermark is null
      or v_bundle_fetched_at >= v_shared_bundle_watermark;

    if v_shared_bundle_is_fresh then
      v_applied_shared_bundles := v_applied_shared_bundles + 1;

    for v_user in
      select submitted.value
      from pg_catalog.jsonb_array_elements(
        v_stage.normalized_bundle -> 'users'
      ) as submitted(value)
      order by submitted.value ->> 'external_user_id' collate "C"
    loop
      v_league_user_id := null;
      insert into public.league_users (
        league_id,
        external_user_id,
        username,
        display_name,
        team_name,
        avatar_id,
        avatar_url,
        is_commissioner,
        metadata,
        fetched_at,
        first_seen_at,
        last_seen_at,
        updated_at
      ) values (
        v_stage.league_id,
        v_user ->> 'external_user_id',
        nullif(v_user ->> 'username', ''),
        nullif(v_user ->> 'display_name', ''),
        nullif(v_user ->> 'team_name', ''),
        nullif(v_user ->> 'avatar_id', ''),
        nullif(v_user ->> 'avatar_url', ''),
        (v_user ->> 'is_commissioner')::boolean,
        v_user -> 'metadata',
        v_bundle_fetched_at,
        v_bundle_fetched_at,
        v_bundle_fetched_at,
        v_now
      ) on conflict on constraint league_users_league_external_user_key
      do nothing
      returning public.league_users.id into v_league_user_id;

      if found then
        v_created_users := v_created_users + 1;
      else
        select league_user.id, league_user.fetched_at
        into v_league_user_id, v_existing_fetched_at
        from public.league_users as league_user
        where league_user.league_id = v_stage.league_id
          and league_user.external_user_id = v_user ->> 'external_user_id'
        for update;
        if not found then
          raise exception using errcode = '55000',
            message = 'A canonical league user could not be resolved.';
        end if;

        if v_bundle_fetched_at >= v_existing_fetched_at then
          update public.league_users as league_user
          set
            username = nullif(v_user ->> 'username', ''),
            display_name = nullif(v_user ->> 'display_name', ''),
            team_name = nullif(v_user ->> 'team_name', ''),
            avatar_id = nullif(v_user ->> 'avatar_id', ''),
            avatar_url = nullif(v_user ->> 'avatar_url', ''),
            is_commissioner = (v_user ->> 'is_commissioner')::boolean,
            metadata = v_user -> 'metadata',
            fetched_at = v_bundle_fetched_at,
            last_seen_at = greatest(league_user.last_seen_at, v_bundle_fetched_at),
            removed_at = null,
            updated_at = v_now
          where league_user.id = v_league_user_id;
          v_updated_users := v_updated_users + 1;
        else
          v_stale_users := v_stale_users + 1;
        end if;
      end if;
    end loop;

    update public.league_users as league_user
    set
      fetched_at = v_bundle_fetched_at,
      removed_at = greatest(v_bundle_fetched_at, league_user.last_seen_at),
      updated_at = v_now
    where league_user.league_id = v_stage.league_id
      and league_user.removed_at is null
      and league_user.fetched_at <= v_bundle_fetched_at
      and not exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          v_stage.normalized_bundle -> 'users'
        ) as observed(value)
        where observed.value ->> 'external_user_id' = league_user.external_user_id
      );
    get diagnostics v_row_count = row_count;
    v_removed_users := v_removed_users + v_row_count;

    for v_roster in
      select submitted.value
      from pg_catalog.jsonb_array_elements(
        v_stage.normalized_bundle -> 'rosters'
      ) as submitted(value)
      order by (submitted.value ->> 'external_roster_id')::integer
    loop
      v_external_roster_id := (v_roster ->> 'external_roster_id')::integer;
      v_co_owner_ids := case
        when v_roster -> 'co_owner_external_user_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(
            v_roster -> 'co_owner_external_user_ids'
          ) with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;
      v_player_ids := case
        when v_roster -> 'source_player_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(v_roster -> 'source_player_ids')
            with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;
      v_starter_ids := case
        when v_roster -> 'source_starter_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(v_roster -> 'source_starter_ids')
            with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;
      v_reserve_ids := case
        when v_roster -> 'source_reserve_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(v_roster -> 'source_reserve_ids')
            with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;
      v_taxi_ids := case
        when v_roster -> 'source_taxi_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(v_roster -> 'source_taxi_ids')
            with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;
      v_keeper_ids := case
        when v_roster -> 'source_keeper_ids' = 'null'::jsonb then null
        else array(
          select item.value
          from pg_catalog.jsonb_array_elements_text(v_roster -> 'source_keeper_ids')
            with ordinality as item(value, ordinality)
          order by item.ordinality
        )
      end;

      v_roster_id := null;
      insert into public.rosters (
        league_id,
        external_roster_id,
        owner_external_user_id,
        co_owner_external_user_ids,
        source_player_ids,
        source_starter_ids,
        source_reserve_ids,
        source_taxi_ids,
        source_keeper_ids,
        settings,
        metadata,
        fetched_at,
        first_seen_at,
        last_seen_at,
        updated_at
      ) values (
        v_stage.league_id,
        v_external_roster_id,
        nullif(v_roster ->> 'owner_external_user_id', ''),
        v_co_owner_ids,
        v_player_ids,
        v_starter_ids,
        v_reserve_ids,
        v_taxi_ids,
        v_keeper_ids,
        v_roster -> 'settings',
        v_roster -> 'metadata',
        v_bundle_fetched_at,
        v_bundle_fetched_at,
        v_bundle_fetched_at,
        v_now
      ) on conflict on constraint rosters_league_external_roster_key
      do nothing
      returning public.rosters.id into v_roster_id;

      if found then
        v_created_rosters := v_created_rosters + 1;
        v_roster_fresh := true;
      else
        select roster.id, roster.fetched_at
        into v_roster_id, v_existing_fetched_at
        from public.rosters as roster
        where roster.league_id = v_stage.league_id
          and roster.external_roster_id = v_external_roster_id
        for update;
        if not found then
          raise exception using errcode = '55000',
            message = 'A canonical shared roster could not be resolved.';
        end if;
        v_roster_fresh := v_bundle_fetched_at >= v_existing_fetched_at;
        if v_roster_fresh then
          if exists (
            select 1
            from public.roster_players as membership
            where membership.roster_id = v_roster_id
              and greatest(
                membership.last_seen_at,
                coalesce(membership.removed_at, '-infinity'::timestamptz)
              ) > v_bundle_fetched_at
          ) then
            raise exception using errcode = '55000',
              message = 'Roster membership freshness exceeds its shared roster observation.';
          end if;

          update public.rosters as roster
          set
            owner_external_user_id = nullif(
              v_roster ->> 'owner_external_user_id',
              ''
            ),
            co_owner_external_user_ids = v_co_owner_ids,
            source_player_ids = v_player_ids,
            source_starter_ids = v_starter_ids,
            source_reserve_ids = v_reserve_ids,
            source_taxi_ids = v_taxi_ids,
            source_keeper_ids = v_keeper_ids,
            settings = v_roster -> 'settings',
            metadata = v_roster -> 'metadata',
            fetched_at = v_bundle_fetched_at,
            last_seen_at = greatest(roster.last_seen_at, v_bundle_fetched_at),
            removed_at = null,
            updated_at = v_now
          where roster.id = v_roster_id;
          v_updated_rosters := v_updated_rosters + 1;
        else
          v_stale_rosters := v_stale_rosters + 1;
        end if;
      end if;

      if not v_roster_fresh then
        v_stale_memberships := v_stale_memberships + case
          when v_roster -> 'memberships' = 'null'::jsonb then 0
          else pg_catalog.jsonb_array_length(v_roster -> 'memberships')
        end;
      elsif v_player_ids is null then
        -- A missing players collection preserves membership identity. Explicit
        -- empty annotation collections can still clear previously confirmed
        -- flags without pretending the player set itself was observed.
        update public.roster_players as existing_membership
        set
          is_starter = case
            when v_starter_ids is null then existing_membership.is_starter
            else false
          end,
          starter_order = case
            when v_starter_ids is null then existing_membership.starter_order
            else null
          end,
          starter_slot = case
            when v_starter_ids is null then existing_membership.starter_slot
            else null
          end,
          is_reserve = case
            when v_reserve_ids is null then existing_membership.is_reserve
            else false
          end,
          is_taxi = case
            when v_taxi_ids is null then existing_membership.is_taxi
            else false
          end,
          is_keeper = case
            when v_keeper_ids is null then existing_membership.is_keeper
            else false
          end,
          source_metadata = pg_catalog.jsonb_build_object(
            'annotation_source_state',
            pg_catalog.jsonb_build_object(
              'starters', case
                when v_starter_ids is null then 'unknown' else 'known'
              end,
              'reserve', case
                when v_reserve_ids is null then 'unknown' else 'known'
              end,
              'taxi', case
                when v_taxi_ids is null then 'unknown' else 'known'
              end,
              'keepers', case
                when v_keeper_ids is null then 'unknown' else 'known'
              end
            ),
            'normalization_warning_fields', '[]'::jsonb
          ),
          updated_at = v_now
        where existing_membership.roster_id = v_roster_id
          and existing_membership.removed_at is null;
        get diagnostics v_row_count = row_count;
        v_updated_memberships := v_updated_memberships + v_row_count;
      elsif v_player_ids is not null then
        -- Resolve exact player identities before membership writes. The global
        -- catalog lock above prevents sparse/catalog split-brain identities.
        for v_membership in
          select submitted.value
          from pg_catalog.jsonb_array_elements(v_roster -> 'memberships')
            as submitted(value)
          order by submitted.value ->> 'external_player_id' collate "C"
        loop
          v_external_player_id := v_membership ->> 'external_player_id';
          v_mapping_id := null;
          select
            external_id.id,
            external_id.player_id,
            external_id.removed_at,
            external_id.last_seen_at
          into
            v_mapping_id,
            v_mapping_player_id,
            v_mapping_removed_at,
            v_mapping_last_seen_at
          from public.player_external_ids as external_id
          where external_id.namespace = 'sleeper'
            and external_id.sport = 'nfl'
            and external_id.external_id = v_external_player_id
          for update;

          if found then
            if v_mapping_removed_at is not null
              or not exists (
                select 1
                from public.player_external_ids as exact_mapping
                where exact_mapping.id = v_mapping_id and exact_mapping.is_primary
              )
            then
              if exists (
                select 1
                from public.player_external_ids as other_mapping
                where other_mapping.player_id = v_mapping_player_id
                  and other_mapping.namespace = 'sleeper'
                  and other_mapping.sport = 'nfl'
                  and other_mapping.id <> v_mapping_id
                  and other_mapping.removed_at is null
                  and other_mapping.last_seen_at > v_bundle_fetched_at
              ) then
                raise exception using errcode = '55000',
                  message = 'A newer active Sleeper mapping conflicts with a roster reference.';
              end if;

              update public.player_external_ids as other_mapping
              set
                removed_at = greatest(
                  v_bundle_fetched_at,
                  other_mapping.last_seen_at
                ),
                updated_at = v_now
              where other_mapping.player_id = v_mapping_player_id
                and other_mapping.namespace = 'sleeper'
                and other_mapping.sport = 'nfl'
                and other_mapping.id <> v_mapping_id
                and other_mapping.removed_at is null;

              update public.player_external_ids as exact_mapping
              set
                reported_by = 'sleeper',
                is_primary = true,
                last_seen_at = greatest(
                  exact_mapping.last_seen_at,
                  v_bundle_fetched_at
                ),
                removed_at = null,
                updated_at = v_now
              where exact_mapping.id = v_mapping_id;
              if v_mapping_removed_at is not null then
                v_reactivated_mappings := v_reactivated_mappings + 1;
              end if;
            elsif v_mapping_removed_at is null then
              update public.player_external_ids as exact_mapping
              set
                last_seen_at = greatest(
                  exact_mapping.last_seen_at,
                  v_bundle_fetched_at
                ),
                updated_at = v_now
              where exact_mapping.id = v_mapping_id;
            end if;
          else
            v_candidate_player_id := gen_random_uuid();
            insert into public.players (
              id,
              sport,
              entity_type,
              profile_source,
              source_metadata,
              profile_fetched_at,
              created_at,
              updated_at
            ) values (
              v_candidate_player_id,
              'nfl',
              'unknown',
              'sleeper',
              pg_catalog.jsonb_build_object(
                'reference_only', true,
                'reference_source', 'roster'
              ),
              v_bundle_fetched_at,
              v_now,
              v_now
            );

            v_mapping_id := null;
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
              created_at,
              updated_at
            ) values (
              v_candidate_player_id,
              'sleeper',
              'nfl',
              v_external_player_id,
              'sleeper',
              true,
              pg_catalog.jsonb_build_object(
                'reference_only', true,
                'reference_source', 'roster'
              ),
              v_bundle_fetched_at,
              v_bundle_fetched_at,
              v_now,
              v_now
            ) on conflict on constraint player_external_ids_namespace_sport_external_key
            do nothing
            returning public.player_external_ids.id into v_mapping_id;

            if found then
              v_mapping_player_id := v_candidate_player_id;
              v_created_reference_players := v_created_reference_players + 1;
            else
              delete from public.players where id = v_candidate_player_id;
              select external_id.id, external_id.player_id
              into v_mapping_id, v_mapping_player_id
              from public.player_external_ids as external_id
              where external_id.namespace = 'sleeper'
                and external_id.sport = 'nfl'
                and external_id.external_id = v_external_player_id
              for update;
              if not found then
                raise exception using errcode = '55000',
                  message = 'A canonical roster player mapping could not be resolved.';
              end if;
            end if;
          end if;
        end loop;

        update public.roster_players as existing_membership
        set
          removed_at = greatest(
            v_bundle_fetched_at,
            existing_membership.last_seen_at
          ),
          updated_at = v_now
        where existing_membership.roster_id = v_roster_id
          and existing_membership.removed_at is null
          and greatest(
            existing_membership.last_seen_at,
            coalesce(existing_membership.removed_at, '-infinity'::timestamptz)
          ) <= v_bundle_fetched_at
          and not exists (
            select 1
            from public.player_external_ids as exact_mapping
            where exact_mapping.id = existing_membership.source_player_external_id_id
              and exact_mapping.external_id = any(v_player_ids)
          );
        get diagnostics v_row_count = row_count;
        v_removed_memberships := v_removed_memberships + v_row_count;

        -- Clear uniqueness-protected mutable orders before applying a possibly
        -- reordered fresh representation.
        update public.roster_players as existing_membership
        set
          source_order = null,
          is_starter = case
            when v_starter_ids is null then existing_membership.is_starter
            else false
          end,
          starter_order = case
            when v_starter_ids is null then existing_membership.starter_order
            else null
          end,
          starter_slot = case
            when v_starter_ids is null then existing_membership.starter_slot
            else null
          end,
          is_reserve = case
            when v_reserve_ids is null then existing_membership.is_reserve
            else false
          end,
          is_taxi = case
            when v_taxi_ids is null then existing_membership.is_taxi
            else false
          end,
          is_keeper = case
            when v_keeper_ids is null then existing_membership.is_keeper
            else false
          end,
          updated_at = v_now
        where existing_membership.roster_id = v_roster_id
          and existing_membership.removed_at is null;

        for v_membership in
          select submitted.value
          from pg_catalog.jsonb_array_elements(v_roster -> 'memberships')
            as submitted(value)
          order by submitted.value ->> 'external_player_id' collate "C"
        loop
          v_external_player_id := v_membership ->> 'external_player_id';
          select external_id.id, external_id.player_id
          into v_mapping_id, v_mapping_player_id
          from public.player_external_ids as external_id
          where external_id.namespace = 'sleeper'
            and external_id.sport = 'nfl'
            and external_id.external_id = v_external_player_id
          for update;
          if not found then
            raise exception using errcode = '55000',
              message = 'A canonical roster player mapping could not be resolved.';
          end if;

          v_inserted := false;
          insert into public.roster_players (
            roster_id,
            league_id,
            player_id,
            source_player_external_id_id,
            source_order,
            is_starter,
            starter_order,
            starter_slot,
            is_reserve,
            is_taxi,
            is_keeper,
            source_metadata,
            first_seen_at,
            last_seen_at,
            updated_at
          ) values (
            v_roster_id,
            v_stage.league_id,
            v_mapping_player_id,
            v_mapping_id,
            (v_membership ->> 'source_order')::integer,
            (v_membership ->> 'is_starter')::boolean,
            case
              when v_membership -> 'starter_order' = 'null'::jsonb then null
              else (v_membership ->> 'starter_order')::integer
            end,
            nullif(v_membership ->> 'starter_slot', ''),
            (v_membership ->> 'is_reserve')::boolean,
            (v_membership ->> 'is_taxi')::boolean,
            (v_membership ->> 'is_keeper')::boolean,
            v_membership -> 'source_metadata',
            v_bundle_fetched_at,
            v_bundle_fetched_at,
            v_now
          ) on conflict on constraint roster_players_roster_player_key
          do nothing
          returning true into v_inserted;

          if v_inserted then
            v_created_memberships := v_created_memberships + 1;
          else
            update public.roster_players as existing_membership
            set
              source_player_external_id_id = v_mapping_id,
              source_order = (v_membership ->> 'source_order')::integer,
              is_starter = case
                when v_starter_ids is null then existing_membership.is_starter
                else (v_membership ->> 'is_starter')::boolean
              end,
              starter_order = case
                when v_starter_ids is null then existing_membership.starter_order
                when v_membership -> 'starter_order' = 'null'::jsonb then null
                else (v_membership ->> 'starter_order')::integer
              end,
              starter_slot = case
                when v_starter_ids is null then existing_membership.starter_slot
                else nullif(v_membership ->> 'starter_slot', '')
              end,
              is_reserve = case
                when v_reserve_ids is null then existing_membership.is_reserve
                else (v_membership ->> 'is_reserve')::boolean
              end,
              is_taxi = case
                when v_taxi_ids is null then existing_membership.is_taxi
                else (v_membership ->> 'is_taxi')::boolean
              end,
              is_keeper = case
                when v_keeper_ids is null then existing_membership.is_keeper
                else (v_membership ->> 'is_keeper')::boolean
              end,
              source_metadata = v_membership -> 'source_metadata',
              last_seen_at = greatest(
                existing_membership.last_seen_at,
                v_bundle_fetched_at
              ),
              removed_at = null,
              updated_at = v_now
            where existing_membership.roster_id = v_roster_id
              and existing_membership.player_id = v_mapping_player_id;
            if not found then
              raise exception using errcode = '55000',
                message = 'A canonical roster membership could not be updated.';
            end if;
            v_updated_memberships := v_updated_memberships + 1;
          end if;
        end loop;
      end if;
    end loop;

    update public.roster_players as membership
    set
      removed_at = greatest(v_bundle_fetched_at, membership.last_seen_at),
      updated_at = v_now
    from public.rosters as roster
    where roster.id = membership.roster_id
      and roster.league_id = v_stage.league_id
      and roster.removed_at is null
      and roster.fetched_at <= v_bundle_fetched_at
      and membership.removed_at is null
      and greatest(
        membership.last_seen_at,
        coalesce(membership.removed_at, '-infinity'::timestamptz)
      ) <= v_bundle_fetched_at
      and not exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          v_stage.normalized_bundle -> 'rosters'
        ) as observed(value)
        where (observed.value ->> 'external_roster_id')::integer
          = roster.external_roster_id
      );
    get diagnostics v_row_count = row_count;
    v_removed_memberships := v_removed_memberships + v_row_count;

    update public.rosters as roster
    set
      fetched_at = v_bundle_fetched_at,
      removed_at = greatest(v_bundle_fetched_at, roster.last_seen_at),
      updated_at = v_now
    where roster.league_id = v_stage.league_id
      and roster.removed_at is null
      and roster.fetched_at <= v_bundle_fetched_at
      and not exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          v_stage.normalized_bundle -> 'rosters'
        ) as observed(value)
        where (observed.value ->> 'external_roster_id')::integer
          = roster.external_roster_id
      );
    get diagnostics v_row_count = row_count;
    v_removed_rosters := v_removed_rosters + v_row_count;

      update public.leagues as league
      set
        roster_bundle_fetched_at = v_bundle_fetched_at,
        updated_at = v_now
      where league.id = v_stage.league_id;
      v_shared_bundle_watermark := v_bundle_fetched_at;
    else
      v_stale_shared_bundles := v_stale_shared_bundles + 1;
      v_stale_users := v_stale_users
        + pg_catalog.jsonb_array_length(v_stage.normalized_bundle -> 'users');
      v_stale_rosters := v_stale_rosters
        + pg_catalog.jsonb_array_length(v_stage.normalized_bundle -> 'rosters');
      select v_stale_memberships + coalesce(pg_catalog.sum(
        case
          when roster.value -> 'memberships' = 'null'::jsonb then 0
          else pg_catalog.jsonb_array_length(roster.value -> 'memberships')
        end
      ), 0)::integer
      into v_stale_memberships
      from pg_catalog.jsonb_array_elements(
        v_stage.normalized_bundle -> 'rosters'
      ) as roster(value);
    end if;

    -- Ownership is resolved from the canonical shared representation, never
    -- from a staged bundle that may have been skipped as stale.
    select
      pg_catalog.count(*) filter (
        where roster.owner_external_user_id = v_account_external_user_id
          or v_account_external_user_id = any(
            coalesce(roster.co_owner_external_user_ids, '{}'::text[])
          )
      )::integer,
      pg_catalog.max(roster.external_roster_id) filter (
        where roster.owner_external_user_id = v_account_external_user_id
          or v_account_external_user_id = any(
            coalesce(roster.co_owner_external_user_ids, '{}'::text[])
          )
      ),
      pg_catalog.bool_or(roster.co_owner_external_user_ids is null)
    into v_match_count, v_matched_external_roster_id, v_has_unresolved_coowners
    from public.rosters as roster
    where roster.league_id = v_stage.league_id
      and roster.removed_at is null;

    if v_match_count > 1 then
      raise exception using errcode = '22023',
        message = 'The Sleeper account matched more than one roster in one league.';
    end if;

    v_ownership_observed_at := v_shared_bundle_watermark;
    if v_ownership_observed_at is null then
      raise exception using errcode = '55000',
        message = 'The shared roster-bundle watermark is missing.';
    end if;

    select
      association.roster_ownership_status,
      association.roster_ownership_observed_at
    into v_existing_ownership_status, v_existing_ownership_observed_at
    from public.fantasy_account_leagues as association
    where association.fantasy_account_id = p_fantasy_account_id
      and association.league_id = v_stage.league_id
      and association.removed_at is null
    for update;
    if not found then
      raise exception using errcode = '55000',
        message = 'The active account-to-league association could not be resolved.';
    end if;

    v_resolved_ownership_status := case
      when v_match_count = 1 then 'owned'
      when coalesce(v_has_unresolved_coowners, false) then 'unresolved'
      else 'not_owned'
    end;

    if v_ownership_observed_at < coalesce(
      v_existing_ownership_observed_at,
      '-infinity'::timestamptz
    ) then
      v_stale_ownership_resolutions := v_stale_ownership_resolutions + 1;
      v_resolved_ownership_status := v_existing_ownership_status;
    else
      update public.fantasy_account_leagues as association
      set
        roster_ownership_status = v_resolved_ownership_status,
        roster_ownership_observed_at = v_ownership_observed_at,
        updated_at = v_now
      where association.fantasy_account_id = p_fantasy_account_id
        and association.league_id = v_stage.league_id;

      if v_resolved_ownership_status = 'owned' then
        select
          roster.id,
          case
            when roster.owner_external_user_id = v_account_external_user_id
              then 'owner'
            else 'co_owner'
          end
        into v_roster_id, v_matched_role
        from public.rosters as roster
        where roster.league_id = v_stage.league_id
          and roster.external_roster_id = v_matched_external_roster_id
          and roster.removed_at is null
        for update;
        if not found then
          raise exception using errcode = '55000',
            message = 'The matched canonical roster could not be resolved.';
        end if;

        update public.fantasy_account_rosters as ownership
        set
          removed_at = greatest(
            v_ownership_observed_at,
            ownership.last_seen_at
          ),
          updated_at = v_now
        where ownership.fantasy_account_id = p_fantasy_account_id
          and ownership.league_id = v_stage.league_id
          and ownership.roster_id <> v_roster_id
          and ownership.removed_at is null;
        get diagnostics v_row_count = row_count;
        v_removed_ownerships := v_removed_ownerships + v_row_count;

        select ownership.removed_at
        into v_ownership_removed_at
        from public.fantasy_account_rosters as ownership
        where ownership.fantasy_account_id = p_fantasy_account_id
          and ownership.league_id = v_stage.league_id
          and ownership.roster_id = v_roster_id
        for update;

        if found then
          if v_ownership_removed_at is not null then
            v_reactivated_ownerships := v_reactivated_ownerships + 1;
          end if;
          update public.fantasy_account_rosters as ownership
          set
            ownership_role = v_matched_role,
            source_metadata = pg_catalog.jsonb_build_object(
              'ownership_source',
              case
                when v_matched_role = 'owner' then 'owner_id'
                else 'co_owners'
              end
            ),
            last_seen_at = greatest(
              ownership.last_seen_at,
              v_ownership_observed_at
            ),
            removed_at = null,
            updated_at = v_now
          where ownership.fantasy_account_id = p_fantasy_account_id
            and ownership.league_id = v_stage.league_id
            and ownership.roster_id = v_roster_id;
        else
          insert into public.fantasy_account_rosters (
            fantasy_account_id,
            league_id,
            roster_id,
            ownership_role,
            source_metadata,
            first_seen_at,
            last_seen_at,
            updated_at
          ) values (
            p_fantasy_account_id,
            v_stage.league_id,
            v_roster_id,
            v_matched_role,
            pg_catalog.jsonb_build_object(
              'ownership_source',
              case
                when v_matched_role = 'owner' then 'owner_id'
                else 'co_owners'
              end
            ),
            v_ownership_observed_at,
            v_ownership_observed_at,
            v_now
          );
          v_created_ownerships := v_created_ownerships + 1;
        end if;
      elsif v_resolved_ownership_status = 'not_owned' then
        update public.fantasy_account_rosters as ownership
        set
          removed_at = greatest(
            v_ownership_observed_at,
            ownership.last_seen_at
          ),
          updated_at = v_now
        where ownership.fantasy_account_id = p_fantasy_account_id
          and ownership.league_id = v_stage.league_id
          and ownership.removed_at is null;
        get diagnostics v_row_count = row_count;
        v_removed_ownerships := v_removed_ownerships + v_row_count;
      end if;
    end if;

    if v_resolved_ownership_status = 'owned' then
      v_owned_leagues := v_owned_leagues + 1;
    elsif v_resolved_ownership_status = 'not_owned' then
      v_confirmed_not_owned_leagues := v_confirmed_not_owned_leagues + 1;
    elsif v_resolved_ownership_status = 'unresolved' then
      v_unresolved_ownership := v_unresolved_ownership + 1;
    else
      raise exception using errcode = '55000',
        message = 'The account-to-league ownership state is invalid.';
    end if;
  end loop;

  v_final_status := case
    when v_unresolved_ownership > 0 then 'partial'
    else 'succeeded'
  end;

  select pg_catalog.count(*)::integer into v_active_owned_rosters
  from public.fantasy_account_rosters as ownership
  inner join public.rosters as roster
    on roster.id = ownership.roster_id and roster.removed_at is null
  inner join public.fantasy_account_leagues as association
    on association.fantasy_account_id = ownership.fantasy_account_id
    and association.league_id = ownership.league_id
    and association.removed_at is null
    and association.roster_ownership_status = 'owned'
  inner join public.leagues as league
    on league.id = ownership.league_id
  where ownership.fantasy_account_id = p_fantasy_account_id
    and ownership.removed_at is null
    and league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_scope.league_season;

  select pg_catalog.count(*)::integer into v_active_owned_memberships
  from public.fantasy_account_rosters as ownership
  inner join public.rosters as roster
    on roster.id = ownership.roster_id and roster.removed_at is null
  inner join public.fantasy_account_leagues as association
    on association.fantasy_account_id = ownership.fantasy_account_id
    and association.league_id = ownership.league_id
    and association.removed_at is null
    and association.roster_ownership_status = 'owned'
  inner join public.roster_players as membership
    on membership.roster_id = roster.id and membership.removed_at is null
  inner join public.leagues as league
    on league.id = ownership.league_id
  where ownership.fantasy_account_id = p_fantasy_account_id
    and ownership.removed_at is null
    and league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_scope.league_season;

  delete from app_private.sleeper_roster_sync_stage
  where run_id = p_sync_run_id;
  delete from app_private.sleeper_roster_sync_scopes
  where run_id = p_sync_run_id;

  v_finished_at := pg_catalog.clock_timestamp();
  v_completion_duration_ms := greatest(
    0,
    pg_catalog.round(
      extract(
        epoch from v_finished_at - v_completion_started_at
      ) * 1000
    )::bigint
  );

  update public.sync_runs as run
  set
    status = v_final_status,
    progress_current = v_staged_count,
    progress_total = v_staged_count,
    result_counts = pg_catalog.jsonb_build_object(
      'observed_leagues', v_observed_leagues,
      'applied_shared_league_bundles', v_applied_shared_bundles,
      'stale_shared_league_bundles_skipped', v_stale_shared_bundles,
      'observed_league_users', v_observed_users,
      'observed_rosters', v_observed_rosters,
      'observed_memberships', v_observed_memberships,
      'created_league_users', v_created_users,
      'updated_league_users', v_updated_users,
      'stale_league_users_skipped', v_stale_users,
      'removed_league_users', v_removed_users,
      'created_rosters', v_created_rosters,
      'updated_rosters', v_updated_rosters,
      'stale_rosters_skipped', v_stale_rosters,
      'removed_rosters', v_removed_rosters,
      'created_memberships', v_created_memberships,
      'updated_memberships', v_updated_memberships,
      'stale_memberships_skipped', v_stale_memberships,
      'removed_memberships', v_removed_memberships,
      'created_ownerships', v_created_ownerships,
      'reactivated_ownerships', v_reactivated_ownerships,
      'removed_ownerships', v_removed_ownerships,
      'owned_leagues', v_owned_leagues,
      'confirmed_not_owned_leagues', v_confirmed_not_owned_leagues,
      'unresolved_ownership_leagues', v_unresolved_ownership,
      'stale_ownership_resolutions_skipped', v_stale_ownership_resolutions,
      'created_reference_players', v_created_reference_players,
      'reactivated_player_mappings', v_reactivated_mappings,
      'placeholder_starter_values', v_placeholder_values,
      'active_owned_rosters', v_active_owned_rosters,
      'active_owned_memberships', v_active_owned_memberships,
      'source_user_endpoint_successes', v_source_user_endpoint_successes,
      'source_roster_endpoint_successes', v_source_roster_endpoint_successes,
      'source_endpoint_successes', v_source_endpoint_successes,
      'source_response_bytes', v_source_response_bytes,
      'source_fetch_duration_ms_total', v_source_fetch_duration_ms_total,
      'source_fetch_duration_ms_max', v_source_fetch_duration_ms_max,
      'source_collection_window_ms_derived', v_source_collection_window_ms,
      'stage_insert_window_ms', v_stage_insert_window_ms,
      'stage_to_completion_ms', v_stage_to_completion_ms,
      'completion_duration_ms', v_completion_duration_ms
    ),
    error_summary = '{}'::jsonb,
    finished_at = v_finished_at,
    updated_at = v_finished_at
  where run.id = p_sync_run_id;

  return query select
    p_sync_run_id,
    v_final_status,
    v_observed_leagues,
    v_applied_shared_bundles,
    v_stale_shared_bundles,
    v_observed_users,
    v_observed_rosters,
    v_observed_memberships,
    v_created_users,
    v_updated_users,
    v_stale_users,
    v_removed_users,
    v_created_rosters,
    v_updated_rosters,
    v_stale_rosters,
    v_removed_rosters,
    v_created_memberships,
    v_updated_memberships,
    v_stale_memberships,
    v_removed_memberships,
    v_created_ownerships,
    v_reactivated_ownerships,
    v_removed_ownerships,
    v_owned_leagues,
    v_confirmed_not_owned_leagues,
    v_unresolved_ownership,
    v_stale_ownership_resolutions,
    v_created_reference_players,
    v_reactivated_mappings,
    v_placeholder_values,
    v_active_owned_rosters,
    v_active_owned_memberships;
end;
$$;

create or replace function public.fail_sleeper_roster_sync(
  p_user_id uuid,
  p_fantasy_account_id uuid,
  p_sync_run_id uuid,
  p_error_code text,
  p_error_message text,
  p_retryable boolean
)
returns table (
  sync_run_id uuid,
  status text,
  changed_run boolean
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '10s'
as $$
declare
  v_account_provider text;
  v_run public.sync_runs%rowtype;
  v_error_code text := pg_catalog.btrim(p_error_code);
  v_error_message text := pg_catalog.btrim(p_error_message);
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_user_id is null or p_fantasy_account_id is null or p_sync_run_id is null then
    raise exception using errcode = '22023',
      message = 'A valid app user, fantasy account, and sync run are required.';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception using errcode = '22023', message = 'A valid app user is required.';
  end if;

  select account.provider into v_account_provider
  from public.fantasy_accounts as account
  inner join public.user_fantasy_accounts as account_link
    on account_link.fantasy_account_id = account.id
  where account.id = p_fantasy_account_id
    and account_link.user_id = p_user_id
  for update of account;
  if not found then
    raise exception using errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  select run.* into v_run
  from public.sync_runs as run
  where run.id = p_sync_run_id
  for update;
  if not found
    or v_account_provider <> 'sleeper'
    or v_run.fantasy_account_id <> p_fantasy_account_id
    or v_run.triggered_by_user_id is distinct from p_user_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.scope <> 'roster_sync'
  then
    raise exception using errcode = '22023',
      message = 'The sync run does not match this Sleeper roster import.';
  end if;

  if v_run.status <> 'running' then
    return query select v_run.id, v_run.status, false;
    return;
  end if;

  if v_error_code is null
    or v_error_code !~ '^[a-z][a-z0-9_]{0,63}$'
    or v_error_message is null
    or pg_catalog.char_length(v_error_message) not between 1 and 255
    or v_error_message ~ '[[:cntrl:]]'
    or p_retryable is null
  then
    raise exception using errcode = '22023',
      message = 'The safe roster-import error is invalid.';
  end if;

  update public.sync_runs as run
  set
    status = 'failed',
    error_summary = pg_catalog.jsonb_build_object(
      'code', v_error_code,
      'message', v_error_message,
      'retryable', p_retryable,
      'stage', 'roster_sync'
    ),
    finished_at = v_now,
    updated_at = v_now
  where run.id = p_sync_run_id;

  delete from app_private.sleeper_roster_sync_stage where run_id = p_sync_run_id;
  delete from app_private.sleeper_roster_sync_scopes where run_id = p_sync_run_id;

  return query select p_sync_run_id, 'failed'::text, true;
end;
$$;

revoke all on function public.start_sleeper_roster_sync(uuid, uuid)
from public, anon, authenticated, service_role;
revoke all on function public.stage_sleeper_roster_league_bundle(
  uuid,
  uuid,
  uuid,
  text,
  jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.complete_sleeper_roster_sync(uuid, uuid, uuid)
from public, anon, authenticated, service_role;
revoke all on function public.fail_sleeper_roster_sync(
  uuid,
  uuid,
  uuid,
  text,
  text,
  boolean
) from public, anon, authenticated, service_role;

grant execute on function public.start_sleeper_roster_sync(uuid, uuid)
to service_role, postgres;
grant execute on function public.stage_sleeper_roster_league_bundle(
  uuid,
  uuid,
  uuid,
  text,
  jsonb
) to service_role, postgres;
grant execute on function public.complete_sleeper_roster_sync(uuid, uuid, uuid)
to service_role, postgres;
grant execute on function public.fail_sleeper_roster_sync(
  uuid,
  uuid,
  uuid,
  text,
  text,
  boolean
) to service_role, postgres;
