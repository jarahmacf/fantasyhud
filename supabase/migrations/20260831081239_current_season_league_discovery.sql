-- Task 006 is the first provider-data import. The hosted preflight confirmed
-- that leagues is empty, so changing its timestamp contract must fail closed
-- instead of inventing values for unexpected rows.
do $$
begin
  if exists (select 1 from public.leagues) then
    raise exception using
      errcode = '55000',
      message = 'Task 006 requires an empty leagues table before adding fetched_at.';
  end if;
end;
$$;

alter table public.leagues
add column fetched_at timestamptz not null;

alter table public.leagues
alter column provider_updated_at drop not null;

comment on column public.leagues.fetched_at is
  'The timestamp at which this league representation was fetched from the provider.';
comment on column public.leagues.provider_updated_at is
  'A reliable provider-supplied league update timestamp when the provider publishes one; never the request or fetch time.';

create or replace function public.start_sleeper_league_discovery(
  p_user_id uuid,
  p_fantasy_account_id uuid
)
returns table (
  sync_run_id uuid,
  created_run boolean,
  reused_run boolean,
  recovered_stale_run boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_account_provider text;
  v_existing_run_id uuid;
  v_existing_updated_at timestamptz;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_recovered boolean := false;
begin
  if p_user_id is null or p_fantasy_account_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid app user and fantasy account are required.';
  end if;

  perform 1
  from auth.users as app_user
  where app_user.id = p_user_id;

  if not found then
    raise exception using
      errcode = '22023',
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
    raise exception using
      errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  if v_account_provider <> 'sleeper' then
    raise exception using
      errcode = '22023',
      message = 'League discovery requires a Sleeper fantasy account.';
  end if;

  select run.id, run.updated_at
  into v_existing_run_id, v_existing_updated_at
  from public.sync_runs as run
  where run.fantasy_account_id = p_fantasy_account_id
    and run.provider = 'sleeper'
    and run.sport = 'nfl'
    and run.scope = 'league_discovery'
    and run.status = 'running'
  for update;

  if found and v_existing_updated_at >= v_now - interval '5 minutes' then
    return query
    select v_existing_run_id, false, true, false;
    return;
  end if;

  if found then
    update public.sync_runs as stale_run
    set
      status = 'failed',
      finished_at = v_now,
      error_summary = pg_catalog.jsonb_build_object(
        'code', 'stale_run_timeout',
        'message', 'The previous league discovery stopped before completion.',
        'retryable', true,
        'stage', 'league_discovery'
      ),
      updated_at = v_now
    where stale_run.id = v_existing_run_id;

    v_recovered := true;
  end if;

  insert into public.sync_runs (
    fantasy_account_id,
    triggered_by_user_id,
    provider,
    sport,
    scope,
    status,
    started_at,
    updated_at
  )
  values (
    p_fantasy_account_id,
    p_user_id,
    'sleeper',
    'nfl',
    'league_discovery',
    'running',
    v_now,
    v_now
  )
  returning public.sync_runs.id into v_existing_run_id;

  return query
  select v_existing_run_id, true, false, v_recovered;
end;
$$;

create or replace function public.complete_sleeper_league_discovery(
  p_user_id uuid,
  p_fantasy_account_id uuid,
  p_sync_run_id uuid,
  p_state jsonb,
  p_leagues jsonb
)
returns table (
  sync_run_id uuid,
  observed_leagues integer,
  created_leagues integer,
  updated_leagues integer,
  stale_shared_leagues_skipped integer,
  created_associations integer,
  reactivated_associations integer,
  removed_associations integer,
  active_associations integer,
  provider_state_applied boolean,
  provider_state_stale_skipped boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_account_provider text;
  v_run public.sync_runs%rowtype;
  v_state_season integer;
  v_league_season integer;
  v_league_create_season integer;
  v_previous_season integer;
  v_state_season_type text;
  v_week integer;
  v_leg integer;
  v_display_week integer;
  v_season_start_date date;
  v_state_fetched_at timestamptz;
  v_observed_at timestamptz := pg_catalog.clock_timestamp();
  v_item jsonb;
  v_league_id uuid;
  v_existing_fetched_at timestamptz;
  v_existing_removed_at timestamptz;
  v_external_league_id text;
  v_provider_updated_at timestamptz;
  v_fetched_at timestamptz;
  v_expected_management text;
  v_expected_best_ball boolean;
  v_expected_superflex boolean;
  v_expected_idp boolean;
  v_expected_scoring text;
  v_created_leagues integer := 0;
  v_updated_leagues integer := 0;
  v_stale_shared_leagues_skipped integer := 0;
  v_created_associations integer := 0;
  v_reactivated_associations integer := 0;
  v_removed_associations integer := 0;
  v_active_associations integer := 0;
  v_observed integer := 0;
  v_provider_state_applied boolean := false;
  v_provider_state_stale_skipped boolean := false;
begin
  if p_user_id is null
    or p_fantasy_account_id is null
    or p_sync_run_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'A valid app user, fantasy account, and sync run are required.';
  end if;

  perform 1
  from auth.users as app_user
  where app_user.id = p_user_id;

  if not found then
    raise exception using
      errcode = '22023',
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
    raise exception using
      errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  if v_account_provider <> 'sleeper' then
    raise exception using
      errcode = '22023',
      message = 'League discovery requires a Sleeper fantasy account.';
  end if;

  select run.*
  into v_run
  from public.sync_runs as run
  where run.id = p_sync_run_id
  for update;

  if not found
    or v_run.fantasy_account_id <> p_fantasy_account_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.scope <> 'league_discovery'
  then
    raise exception using
      errcode = '22023',
      message = 'The sync run does not match this Sleeper league discovery.';
  end if;

  if v_run.status <> 'running' then
    raise exception using
      errcode = '55000',
      message = 'A terminal league-discovery run cannot be completed.';
  end if;

  if p_state is null
    or pg_catalog.jsonb_typeof(p_state) <> 'object'
    or pg_catalog.pg_column_size(p_state) > 65536
  then
    raise exception using
      errcode = '22023',
      message = 'The normalized NFL state payload is invalid.';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_object_keys(p_state) as state_key(key)
    where state_key.key not in (
      'season',
      'league_season',
      'league_create_season',
      'previous_season',
      'season_type',
      'week',
      'leg',
      'display_week',
      'season_start_date',
      'provider_metadata',
      'fetched_at'
    )
  ) then
    raise exception using
      errcode = '22023',
      message = 'The normalized NFL state contains unsupported fields.';
  end if;

  if (
    select pg_catalog.count(*)
    from pg_catalog.jsonb_object_keys(p_state)
  ) <> 11 then
    raise exception using
      errcode = '22023',
      message = 'The normalized NFL state is missing required fields.';
  end if;

  begin
    if pg_catalog.jsonb_typeof(p_state -> 'season') <> 'number'
      or pg_catalog.jsonb_typeof(p_state -> 'league_season') <> 'number'
      or (p_state ->> 'season')::numeric <> pg_catalog.trunc((p_state ->> 'season')::numeric)
      or (p_state ->> 'league_season')::numeric <> pg_catalog.trunc((p_state ->> 'league_season')::numeric)
      or (
        p_state -> 'league_create_season' <> 'null'::jsonb
        and (
          pg_catalog.jsonb_typeof(p_state -> 'league_create_season') <> 'number'
          or (p_state ->> 'league_create_season')::numeric <>
            pg_catalog.trunc((p_state ->> 'league_create_season')::numeric)
        )
      )
      or (
        p_state -> 'previous_season' <> 'null'::jsonb
        and (
          pg_catalog.jsonb_typeof(p_state -> 'previous_season') <> 'number'
          or (p_state ->> 'previous_season')::numeric <>
            pg_catalog.trunc((p_state ->> 'previous_season')::numeric)
        )
      )
      or (
        p_state -> 'week' <> 'null'::jsonb
        and (
          pg_catalog.jsonb_typeof(p_state -> 'week') <> 'number'
          or (p_state ->> 'week')::numeric <>
            pg_catalog.trunc((p_state ->> 'week')::numeric)
        )
      )
      or (
        p_state -> 'leg' <> 'null'::jsonb
        and (
          pg_catalog.jsonb_typeof(p_state -> 'leg') <> 'number'
          or (p_state ->> 'leg')::numeric <>
            pg_catalog.trunc((p_state ->> 'leg')::numeric)
        )
      )
      or (
        p_state -> 'display_week' <> 'null'::jsonb
        and (
          pg_catalog.jsonb_typeof(p_state -> 'display_week') <> 'number'
          or (p_state ->> 'display_week')::numeric <>
            pg_catalog.trunc((p_state ->> 'display_week')::numeric)
        )
      )
    then
      raise exception using errcode = '22023', message = 'invalid state';
    end if;

    v_state_season := (p_state ->> 'season')::integer;
    v_league_season := (p_state ->> 'league_season')::integer;
    v_league_create_season := case
      when p_state -> 'league_create_season' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(p_state -> 'league_create_season') = 'number'
        then (p_state ->> 'league_create_season')::integer
      else -1
    end;
    v_previous_season := case
      when p_state -> 'previous_season' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(p_state -> 'previous_season') = 'number'
        then (p_state ->> 'previous_season')::integer
      else -1
    end;
    v_week := case
      when p_state -> 'week' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(p_state -> 'week') = 'number'
        then (p_state ->> 'week')::integer
      else -1
    end;
    v_leg := case
      when p_state -> 'leg' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(p_state -> 'leg') = 'number'
        then (p_state ->> 'leg')::integer
      else -1
    end;
    v_display_week := case
      when p_state -> 'display_week' = 'null'::jsonb then null
      when pg_catalog.jsonb_typeof(p_state -> 'display_week') = 'number'
        then (p_state ->> 'display_week')::integer
      else -1
    end;
    v_state_fetched_at := (p_state ->> 'fetched_at')::timestamptz;
    v_season_start_date := case
      when p_state -> 'season_start_date' = 'null'::jsonb then null
      else (p_state ->> 'season_start_date')::date
    end;
  exception when others then
    raise exception using
      errcode = '22023',
      message = 'The normalized NFL state contains invalid scalar values.';
  end;

  v_state_season_type := p_state ->> 'season_type';
  if v_state_season not between 1900 and 2999
    or v_league_season not between 1900 and 2999
    or (v_league_create_season is not null and v_league_create_season not between 1900 and 2999)
    or (v_previous_season is not null and v_previous_season not between 1900 and 2999)
    or v_state_season_type is null
    or v_state_season_type !~ '^[a-z][a-z0-9_-]{0,31}$'
    or v_week < 0
    or v_leg < 0
    or v_display_week < 0
    or pg_catalog.jsonb_typeof(p_state -> 'provider_metadata') <> 'object'
    or pg_catalog.jsonb_typeof(p_state -> 'fetched_at') <> 'string'
    or not pg_catalog.isfinite(v_state_fetched_at)
    or (p_state -> 'season_start_date' <> 'null'::jsonb and pg_catalog.jsonb_typeof(p_state -> 'season_start_date') <> 'string')
  then
    raise exception using
      errcode = '22023',
      message = 'The normalized NFL state payload is invalid.';
  end if;

  if p_leagues is null
    or pg_catalog.jsonb_typeof(p_leagues) <> 'array'
    or pg_catalog.jsonb_array_length(p_leagues) > 1000
    or pg_catalog.pg_column_size(p_leagues) > 4000000
  then
    raise exception using
      errcode = '22023',
      message = 'The normalized league collection is invalid.';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(p_leagues) as league(value)
    where pg_catalog.jsonb_typeof(league.value) <> 'object'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Every normalized league must be an object.';
  end if;

  if exists (
    select league.value ->> 'external_league_id'
    from pg_catalog.jsonb_array_elements(p_leagues) as league(value)
    group by league.value ->> 'external_league_id'
    having pg_catalog.count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'The normalized league collection contains duplicate IDs.';
  end if;

  for v_item in
    select league.value
    from pg_catalog.jsonb_array_elements(p_leagues) as league(value)
  loop
    if exists (
      select 1
      from pg_catalog.jsonb_object_keys(v_item) as league_key(key)
      where league_key.key not in (
        'external_league_id',
        'sport',
        'season',
        'name',
        'status',
        'season_type',
        'team_count',
        'roster_size',
        'roster_management_type',
        'is_best_ball',
        'has_superflex',
        'has_idp',
        'scoring_format',
        'avatar_id',
        'avatar_url',
        'previous_external_league_id',
        'settings',
        'scoring_settings',
        'roster_positions',
        'provider_metadata',
        'provider_updated_at',
        'fetched_at'
      )
    ) then
      raise exception using
        errcode = '22023',
        message = 'A normalized league contains unsupported fields.';
    end if;

    if (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(v_item)
    ) <> 22 then
      raise exception using
        errcode = '22023',
        message = 'A normalized league is missing required fields.';
    end if;

    begin
      if pg_catalog.jsonb_typeof(v_item -> 'season') <> 'number'
        or pg_catalog.jsonb_typeof(v_item -> 'team_count') <> 'number'
        or pg_catalog.jsonb_typeof(v_item -> 'roster_size') <> 'number'
        or (v_item ->> 'season')::numeric <>
          pg_catalog.trunc((v_item ->> 'season')::numeric)
        or (v_item ->> 'team_count')::numeric <>
          pg_catalog.trunc((v_item ->> 'team_count')::numeric)
        or (v_item ->> 'roster_size')::numeric <>
          pg_catalog.trunc((v_item ->> 'roster_size')::numeric)
      then
        raise exception using errcode = '22023', message = 'invalid league';
      end if;

      v_fetched_at := (v_item ->> 'fetched_at')::timestamptz;
      v_provider_updated_at := case
        when v_item -> 'provider_updated_at' = 'null'::jsonb then null
        else (v_item ->> 'provider_updated_at')::timestamptz
      end;
    exception when others then
      raise exception using
        errcode = '22023',
        message = 'A normalized league contains invalid scalar values.';
    end;

    v_external_league_id := v_item ->> 'external_league_id';
    v_expected_management := case
      when v_item -> 'settings' -> 'type' = '0'::jsonb then 'redraft'
      when v_item -> 'settings' -> 'type' = '1'::jsonb then 'keeper'
      when v_item -> 'settings' -> 'type' = '2'::jsonb then 'dynasty'
      else 'unknown'
    end;
    v_expected_best_ball := coalesce(
      v_item -> 'settings' -> 'best_ball' = '1'::jsonb,
      false
    );
    v_expected_superflex := exists (
      select 1
      from pg_catalog.jsonb_array_elements_text(
        v_item -> 'roster_positions'
      ) as position(value)
      where position.value in ('SUPER_FLEX', 'QB_FLEX')
    );
    v_expected_idp := exists (
      select 1
      from pg_catalog.jsonb_array_elements_text(
        v_item -> 'roster_positions'
      ) as position(value)
      where position.value in (
        'DL', 'DE', 'DT', 'LB', 'DB', 'CB', 'S', 'EDGE', 'IDP_FLEX'
      )
    );
    v_expected_scoring := case
      when pg_catalog.jsonb_typeof(
        v_item -> 'scoring_settings' -> 'rec'
      ) <> 'number' then 'unknown'
      when exists (
        select 1
        from pg_catalog.unnest(array[
          'bonus_rec_te', 'bonus_rec_rb', 'bonus_rec_wr',
          'rec_te', 'rec_rb', 'rec_wr'
        ]) as premium(key)
        where pg_catalog.jsonb_typeof(
          v_item -> 'scoring_settings' -> premium.key
        ) = 'number'
          and (v_item -> 'scoring_settings' ->> premium.key)::numeric <> 0
      ) then 'custom'
      when (v_item -> 'scoring_settings' ->> 'rec')::numeric = 1 then 'ppr'
      when (v_item -> 'scoring_settings' ->> 'rec')::numeric = 0.5 then 'half_ppr'
      when (v_item -> 'scoring_settings' ->> 'rec')::numeric = 0 then 'standard'
      else 'custom'
    end;

    if v_external_league_id is null
      or v_external_league_id <> pg_catalog.btrim(v_external_league_id)
      or pg_catalog.char_length(v_external_league_id) not between 1 and 255
      or v_item ->> 'sport' <> 'nfl'
      or (v_item ->> 'season')::integer <> v_league_season
      or v_item ->> 'name' is null
      or v_item ->> 'name' <> pg_catalog.btrim(v_item ->> 'name')
      or pg_catalog.char_length(v_item ->> 'name') not between 1 and 255
      or v_item ->> 'status' not in ('pre_draft', 'drafting', 'in_season', 'complete')
      or v_item ->> 'season_type' not in ('pre', 'regular', 'post')
      or (v_item ->> 'team_count')::integer not between 1 and 1000
      or (v_item ->> 'roster_size')::integer not between 0 and 1000
      or (v_item ->> 'roster_size')::integer <>
        pg_catalog.jsonb_array_length(v_item -> 'roster_positions')
      or v_item ->> 'roster_management_type' <> v_expected_management
      or v_item -> 'is_best_ball' <> pg_catalog.to_jsonb(v_expected_best_ball)
      or v_item -> 'has_superflex' <> pg_catalog.to_jsonb(v_expected_superflex)
      or v_item -> 'has_idp' <> pg_catalog.to_jsonb(v_expected_idp)
      or v_item ->> 'scoring_format' <> v_expected_scoring
      or pg_catalog.jsonb_typeof(v_item -> 'is_best_ball') <> 'boolean'
      or pg_catalog.jsonb_typeof(v_item -> 'has_superflex') <> 'boolean'
      or pg_catalog.jsonb_typeof(v_item -> 'has_idp') <> 'boolean'
      or pg_catalog.jsonb_typeof(v_item -> 'settings') <> 'object'
      or pg_catalog.jsonb_typeof(v_item -> 'scoring_settings') <> 'object'
      or pg_catalog.jsonb_typeof(v_item -> 'roster_positions') <> 'array'
      or pg_catalog.jsonb_typeof(v_item -> 'provider_metadata') <> 'object'
      or pg_catalog.jsonb_typeof(v_item -> 'fetched_at') <> 'string'
      or not pg_catalog.isfinite(v_fetched_at)
      or (v_provider_updated_at is not null and not pg_catalog.isfinite(v_provider_updated_at))
      or (v_item -> 'provider_updated_at' <> 'null'::jsonb and pg_catalog.jsonb_typeof(v_item -> 'provider_updated_at') <> 'string')
      or exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_item -> 'roster_positions') as position(value)
        where pg_catalog.jsonb_typeof(position.value) <> 'string'
          or pg_catalog.btrim(position.value #>> '{}') = ''
          or pg_catalog.char_length(position.value #>> '{}') > 64
          or position.value #>> '{}' !~ '^[A-Z0-9_]+$'
      )
    then
      raise exception using
        errcode = '22023',
        message = 'A normalized league failed validation.';
    end if;

    if (v_item -> 'avatar_id' <> 'null'::jsonb and (
        pg_catalog.jsonb_typeof(v_item -> 'avatar_id') <> 'string'
        or pg_catalog.btrim(v_item ->> 'avatar_id') = ''
        or pg_catalog.char_length(v_item ->> 'avatar_id') > 255
      ))
      or (v_item -> 'avatar_url' <> 'null'::jsonb and (
        pg_catalog.jsonb_typeof(v_item -> 'avatar_url') <> 'string'
        or pg_catalog.btrim(v_item ->> 'avatar_url') = ''
        or pg_catalog.char_length(v_item ->> 'avatar_url') > 2048
      ))
      or (v_item -> 'previous_external_league_id' <> 'null'::jsonb and (
        pg_catalog.jsonb_typeof(v_item -> 'previous_external_league_id') <> 'string'
        or pg_catalog.btrim(v_item ->> 'previous_external_league_id') = ''
        or pg_catalog.char_length(v_item ->> 'previous_external_league_id') > 255
      ))
    then
      raise exception using
        errcode = '22023',
        message = 'A normalized league contains invalid optional values.';
    end if;
  end loop;

  insert into public.provider_season_states as stored_state (
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
    'sleeper',
    'nfl',
    v_state_season,
    v_league_season,
    v_league_create_season,
    v_previous_season,
    v_state_season_type,
    v_week,
    v_leg,
    v_display_week,
    v_season_start_date,
    p_state -> 'provider_metadata',
    v_state_fetched_at,
    v_observed_at
  )
  on conflict on constraint provider_season_states_provider_sport_key
  do update set
    season = excluded.season,
    league_season = excluded.league_season,
    league_create_season = excluded.league_create_season,
    previous_season = excluded.previous_season,
    season_type = excluded.season_type,
    week = excluded.week,
    leg = excluded.leg,
    display_week = excluded.display_week,
    season_start_date = excluded.season_start_date,
    provider_metadata = excluded.provider_metadata,
    fetched_at = excluded.fetched_at,
    updated_at = excluded.updated_at
  where excluded.fetched_at >= stored_state.fetched_at
  returning true into v_provider_state_applied;

  if not found then
    v_provider_state_applied := false;
    v_provider_state_stale_skipped := true;
  end if;

  for v_item in
    select league.value
    from pg_catalog.jsonb_array_elements(p_leagues) as league(value)
    order by league.value ->> 'external_league_id'
  loop
    v_external_league_id := v_item ->> 'external_league_id';
    v_fetched_at := (v_item ->> 'fetched_at')::timestamptz;
    v_provider_updated_at := case
      when v_item -> 'provider_updated_at' = 'null'::jsonb then null
      else (v_item ->> 'provider_updated_at')::timestamptz
    end;

    insert into public.leagues (
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
      avatar_id,
      avatar_url,
      previous_external_league_id,
      settings,
      scoring_settings,
      roster_positions,
      provider_metadata,
      provider_updated_at,
      fetched_at,
      updated_at
    )
    values (
      'sleeper',
      v_external_league_id,
      'nfl',
      v_league_season,
      v_item ->> 'name',
      v_item ->> 'status',
      v_item ->> 'season_type',
      (v_item ->> 'team_count')::integer,
      (v_item ->> 'roster_size')::integer,
      v_item ->> 'roster_management_type',
      (v_item ->> 'is_best_ball')::boolean,
      (v_item ->> 'has_superflex')::boolean,
      (v_item ->> 'has_idp')::boolean,
      v_item ->> 'scoring_format',
      nullif(v_item ->> 'avatar_id', ''),
      nullif(v_item ->> 'avatar_url', ''),
      nullif(v_item ->> 'previous_external_league_id', ''),
      v_item -> 'settings',
      v_item -> 'scoring_settings',
      v_item -> 'roster_positions',
      v_item -> 'provider_metadata',
      v_provider_updated_at,
      v_fetched_at,
      v_observed_at
    )
    on conflict on constraint leagues_provider_external_league_id_key
    do nothing
    returning public.leagues.id into v_league_id;

    if found then
      v_created_leagues := v_created_leagues + 1;
    else
      select league.id, league.fetched_at
      into v_league_id, v_existing_fetched_at
      from public.leagues as league
      where league.provider = 'sleeper'
        and league.external_league_id = v_external_league_id
      for update;

      if not found then
        raise exception using
          errcode = '55000',
          message = 'The canonical shared league could not be resolved.';
      end if;

      if v_fetched_at >= v_existing_fetched_at then
      update public.leagues as league
      set
        sport = 'nfl',
        season = v_league_season,
        name = v_item ->> 'name',
        status = v_item ->> 'status',
        season_type = v_item ->> 'season_type',
        team_count = (v_item ->> 'team_count')::integer,
        roster_size = (v_item ->> 'roster_size')::integer,
        roster_management_type = v_item ->> 'roster_management_type',
        is_best_ball = (v_item ->> 'is_best_ball')::boolean,
        has_superflex = (v_item ->> 'has_superflex')::boolean,
        has_idp = (v_item ->> 'has_idp')::boolean,
        scoring_format = v_item ->> 'scoring_format',
        avatar_id = nullif(v_item ->> 'avatar_id', ''),
        avatar_url = nullif(v_item ->> 'avatar_url', ''),
        previous_external_league_id = nullif(v_item ->> 'previous_external_league_id', ''),
        settings = v_item -> 'settings',
        scoring_settings = v_item -> 'scoring_settings',
        roster_positions = v_item -> 'roster_positions',
        provider_metadata = v_item -> 'provider_metadata',
        provider_updated_at = coalesce(
          v_provider_updated_at,
          league.provider_updated_at
        ),
        fetched_at = v_fetched_at,
        updated_at = v_observed_at
      where league.id = v_league_id;

      v_updated_leagues := v_updated_leagues + 1;
      else
        v_stale_shared_leagues_skipped :=
          v_stale_shared_leagues_skipped + 1;
      end if;
    end if;

    select association.removed_at
    into v_existing_removed_at
    from public.fantasy_account_leagues as association
    where association.fantasy_account_id = p_fantasy_account_id
      and association.league_id = v_league_id
    for update;

    if found then
      if v_existing_removed_at is not null then
        v_reactivated_associations := v_reactivated_associations + 1;
      end if;

      update public.fantasy_account_leagues as association
      set
        last_seen_at = greatest(association.last_seen_at, v_observed_at),
        removed_at = null,
        updated_at = v_observed_at
      where association.fantasy_account_id = p_fantasy_account_id
        and association.league_id = v_league_id;
    else
      insert into public.fantasy_account_leagues (
        fantasy_account_id,
        league_id,
        first_seen_at,
        last_seen_at,
        updated_at
      )
      values (
        p_fantasy_account_id,
        v_league_id,
        v_observed_at,
        v_observed_at,
        v_observed_at
      );

      v_created_associations := v_created_associations + 1;
    end if;
  end loop;

  update public.fantasy_account_leagues as association
  set
    removed_at = greatest(v_observed_at, association.last_seen_at),
    updated_at = v_observed_at
  from public.leagues as league
  where association.fantasy_account_id = p_fantasy_account_id
    and association.league_id = league.id
    and association.removed_at is null
    and league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_league_season
    and not exists (
      select 1
      from pg_catalog.jsonb_array_elements(p_leagues) as observed(value)
      where observed.value ->> 'external_league_id' = league.external_league_id
    );

  get diagnostics v_removed_associations = row_count;
  v_observed := pg_catalog.jsonb_array_length(p_leagues);

  select pg_catalog.count(*)::integer
  into v_active_associations
  from public.fantasy_account_leagues as association
  inner join public.leagues as league on league.id = association.league_id
  where association.fantasy_account_id = p_fantasy_account_id
    and association.removed_at is null
    and league.provider = 'sleeper'
    and league.sport = 'nfl'
    and league.season = v_league_season;

  update public.sync_runs as run
  set
    season = v_league_season,
    status = 'succeeded',
    progress_current = v_observed,
    progress_total = v_observed,
    result_counts = pg_catalog.jsonb_build_object(
      'observed_leagues', v_observed,
      'created_leagues', v_created_leagues,
      'updated_leagues', v_updated_leagues,
      'stale_shared_leagues_skipped', v_stale_shared_leagues_skipped,
      'created_associations', v_created_associations,
      'reactivated_associations', v_reactivated_associations,
      'removed_associations', v_removed_associations,
      'active_associations', v_active_associations,
      'provider_state_applied', v_provider_state_applied,
      'provider_state_stale_skipped', v_provider_state_stale_skipped
    ),
    error_summary = '{}'::jsonb,
    finished_at = v_observed_at,
    updated_at = v_observed_at
  where run.id = p_sync_run_id;

  return query
  select
    p_sync_run_id,
    v_observed,
    v_created_leagues,
    v_updated_leagues,
    v_stale_shared_leagues_skipped,
    v_created_associations,
    v_reactivated_associations,
    v_removed_associations,
    v_active_associations,
    v_provider_state_applied,
    v_provider_state_stale_skipped;
end;
$$;

create or replace function public.fail_sleeper_league_discovery(
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
as $$
declare
  v_account_provider text;
  v_run public.sync_runs%rowtype;
  v_error_code text := pg_catalog.btrim(p_error_code);
  v_error_message text := pg_catalog.btrim(p_error_message);
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_user_id is null
    or p_fantasy_account_id is null
    or p_sync_run_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'A valid app user, fantasy account, and sync run are required.';
  end if;

  perform 1
  from auth.users as app_user
  where app_user.id = p_user_id;

  if not found then
    raise exception using
      errcode = '22023',
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
    raise exception using
      errcode = '42501',
      message = 'The app user is not linked to this fantasy account.';
  end if;

  if v_account_provider <> 'sleeper' then
    raise exception using
      errcode = '22023',
      message = 'League discovery requires a Sleeper fantasy account.';
  end if;

  select run.*
  into v_run
  from public.sync_runs as run
  where run.id = p_sync_run_id
  for update;

  if not found
    or v_run.fantasy_account_id <> p_fantasy_account_id
    or v_run.provider <> 'sleeper'
    or v_run.sport <> 'nfl'
    or v_run.scope <> 'league_discovery'
  then
    raise exception using
      errcode = '22023',
      message = 'The sync run does not match this Sleeper league discovery.';
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
      message = 'The safe league-discovery error is invalid.';
  end if;

  update public.sync_runs as run
  set
    status = 'failed',
    error_summary = pg_catalog.jsonb_build_object(
      'code', v_error_code,
      'message', v_error_message,
      'retryable', p_retryable,
      'stage', 'league_discovery'
    ),
    finished_at = v_now,
    updated_at = v_now
  where run.id = p_sync_run_id;

  return query
  select p_sync_run_id, 'failed'::text, true;
end;
$$;

revoke all on function public.start_sleeper_league_discovery(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) from public, anon, authenticated;
revoke all on function public.fail_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  text,
  text,
  boolean
) from public, anon, authenticated;

grant execute on function public.start_sleeper_league_discovery(uuid, uuid)
to service_role, postgres;
grant execute on function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) to service_role, postgres;
grant execute on function public.fail_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  text,
  text,
  boolean
) to service_role, postgres;
