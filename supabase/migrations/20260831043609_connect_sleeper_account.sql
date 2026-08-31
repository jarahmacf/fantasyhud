create or replace function public.connect_sleeper_account(
  p_user_id uuid,
  p_external_user_id text,
  p_username text,
  p_display_name text,
  p_avatar_url text,
  p_provider_metadata jsonb
)
returns table (
  fantasy_account_id uuid,
  user_fantasy_account_id uuid,
  is_primary boolean,
  created_link boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_fantasy_account_id uuid;
  v_user_fantasy_account_id uuid;
  v_is_primary boolean;
  v_created_link boolean := false;
  v_username text;
  v_display_name text;
  v_avatar_url text;
  v_row_count integer;
begin
  if p_user_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  perform 1
  from auth.users as app_user
  where app_user.id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = '22023',
      message = 'A valid app user is required.';
  end if;

  if p_external_user_id is null
    or p_external_user_id <> pg_catalog.btrim(p_external_user_id)
    or pg_catalog.char_length(p_external_user_id) not between 1 and 255
  then
    raise exception using
      errcode = '22023',
      message = 'A valid canonical Sleeper user ID is required.';
  end if;

  v_username := pg_catalog.btrim(p_username);
  if p_username is null
    or p_username <> v_username
    or pg_catalog.char_length(v_username) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'A valid canonical Sleeper username is required.';
  end if;

  v_display_name := nullif(pg_catalog.btrim(p_display_name), '');
  if v_display_name is not null
    and pg_catalog.char_length(v_display_name) > 100
  then
    raise exception using
      errcode = '22023',
      message = 'The Sleeper display name is invalid.';
  end if;

  v_avatar_url := nullif(pg_catalog.btrim(p_avatar_url), '');
  if v_avatar_url is not null
    and pg_catalog.char_length(v_avatar_url) > 2048
  then
    raise exception using
      errcode = '22023',
      message = 'The Sleeper avatar URL is invalid.';
  end if;

  if p_provider_metadata is null
    or pg_catalog.jsonb_typeof(p_provider_metadata) <> 'object'
  then
    raise exception using
      errcode = '22023',
      message = 'Sleeper provider metadata must be an object.';
  end if;

  insert into public.fantasy_accounts (
    provider,
    external_user_id,
    username,
    normalized_username,
    display_name,
    avatar_url,
    provider_metadata,
    provider_updated_at
  )
  values (
    'sleeper',
    p_external_user_id,
    v_username,
    pg_catalog.lower(v_username),
    v_display_name,
    v_avatar_url,
    p_provider_metadata,
    pg_catalog.now()
  )
  on conflict on constraint fantasy_accounts_provider_external_user_id_key
  do update set
    username = excluded.username,
    normalized_username = excluded.normalized_username,
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    provider_metadata = excluded.provider_metadata,
    provider_updated_at = excluded.provider_updated_at,
    updated_at = pg_catalog.now()
  returning public.fantasy_accounts.id into v_fantasy_account_id;

  v_is_primary := not exists (
    select 1
    from public.user_fantasy_accounts as existing_primary
    where existing_primary.user_id = p_user_id
      and existing_primary.is_primary
  );

  insert into public.user_fantasy_accounts (
    user_id,
    fantasy_account_id,
    is_primary
  )
  values (
    p_user_id,
    v_fantasy_account_id,
    v_is_primary
  )
  on conflict on constraint user_fantasy_accounts_user_account_key
  do nothing
  returning
    public.user_fantasy_accounts.id,
    public.user_fantasy_accounts.is_primary
  into v_user_fantasy_account_id, v_is_primary;

  get diagnostics v_row_count = row_count;
  v_created_link := v_row_count = 1;

  if not v_created_link then
    select existing_link.id, existing_link.is_primary
    into v_user_fantasy_account_id, v_is_primary
    from public.user_fantasy_accounts as existing_link
    where existing_link.user_id = p_user_id
      and existing_link.fantasy_account_id = v_fantasy_account_id;
  end if;

  return query
  select
    v_fantasy_account_id,
    v_user_fantasy_account_id,
    v_is_primary,
    v_created_link;
end;
$$;

revoke all on function public.connect_sleeper_account(
  uuid,
  text,
  text,
  text,
  text,
  jsonb
) from public, anon, authenticated;

grant execute on function public.connect_sleeper_account(
  uuid,
  text,
  text,
  text,
  text,
  jsonb
) to service_role, postgres;
