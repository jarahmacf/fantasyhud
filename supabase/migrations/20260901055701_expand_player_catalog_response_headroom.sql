-- Add measured response-size headroom without changing catalog identity,
-- record-count, batching, freshness, staging, or publication semantics.

alter table public.provider_catalog_runs
drop constraint provider_catalog_runs_source_counts_are_valid;

alter table public.provider_catalog_runs
add constraint provider_catalog_runs_source_counts_are_valid check (
  (
    source_record_count is null
    or source_record_count between 0 and 50000
  )
  and (
    source_bytes is null
    or source_bytes between 0 and 25000000
  )
);

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
    or p_source_bytes not between 1 and 25000000
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

revoke all on function public.stage_sleeper_player_catalog_batch(
  uuid,
  uuid,
  integer,
  integer,
  timestamptz,
  integer,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.stage_sleeper_player_catalog_batch(
  uuid,
  uuid,
  integer,
  integer,
  timestamptz,
  integer,
  jsonb
) to service_role, postgres;
