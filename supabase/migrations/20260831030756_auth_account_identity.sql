create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_is_trimmed_and_bounded check (
    display_name is null
    or (
      display_name = btrim(display_name)
      and char_length(display_name) between 1 and 100
    )
  ),
  constraint profiles_avatar_url_is_trimmed_and_bounded check (
    avatar_url is null
    or (
      avatar_url = btrim(avatar_url)
      and char_length(avatar_url) between 1 and 2048
    )
  )
);

create table public.fantasy_accounts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  external_user_id text not null,
  username text not null,
  normalized_username text not null,
  display_name text,
  avatar_url text,
  provider_metadata jsonb not null default '{}'::jsonb,
  last_synced_at timestamptz,
  provider_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fantasy_accounts_provider_external_user_id_key unique (
    provider,
    external_user_id
  ),
  constraint fantasy_accounts_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint fantasy_accounts_external_user_id_is_bounded check (
    external_user_id = btrim(external_user_id)
    and char_length(external_user_id) between 1 and 255
  ),
  constraint fantasy_accounts_username_is_bounded check (
    username = btrim(username)
    and char_length(username) between 1 and 100
  ),
  constraint fantasy_accounts_normalized_username_matches check (
    normalized_username = lower(btrim(username))
  ),
  constraint fantasy_accounts_display_name_is_trimmed_and_bounded check (
    display_name is null
    or (
      display_name = btrim(display_name)
      and char_length(display_name) between 1 and 100
    )
  ),
  constraint fantasy_accounts_avatar_url_is_trimmed_and_bounded check (
    avatar_url is null
    or (
      avatar_url = btrim(avatar_url)
      and char_length(avatar_url) between 1 and 2048
    )
  ),
  constraint fantasy_accounts_provider_metadata_is_object check (
    jsonb_typeof(provider_metadata) = 'object'
  )
);

create table public.user_fantasy_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fantasy_account_id uuid not null
    references public.fantasy_accounts(id) on delete cascade,
  label text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_fantasy_accounts_user_account_key unique (
    user_id,
    fantasy_account_id
  ),
  constraint user_fantasy_accounts_label_is_trimmed_and_bounded check (
    label is null
    or (label = btrim(label) and char_length(label) between 1 and 100)
  )
);

create index user_fantasy_accounts_account_user_idx
  on public.user_fantasy_accounts (fantasy_account_id, user_id);

create unique index user_fantasy_accounts_one_primary_per_user_idx
  on public.user_fantasy_accounts (user_id)
  where is_primary;

create or replace function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function app_private.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  safe_display_name text;
  safe_avatar_url text;
begin
  safe_display_name := btrim(new.raw_user_meta_data ->> 'display_name');
  if safe_display_name = '' or char_length(safe_display_name) > 100 then
    safe_display_name := null;
  end if;

  safe_avatar_url := btrim(new.raw_user_meta_data ->> 'avatar_url');
  if safe_avatar_url = '' or char_length(safe_avatar_url) > 2048 then
    safe_avatar_url := null;
  end if;

  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, safe_display_name, safe_avatar_url)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function app_private.set_updated_at();

create trigger fantasy_accounts_set_updated_at
before update on public.fantasy_accounts
for each row execute function app_private.set_updated_at();

create trigger user_fantasy_accounts_set_updated_at
before update on public.user_fantasy_accounts
for each row execute function app_private.set_updated_at();

create trigger auth_users_create_profile
after insert on auth.users
for each row execute function app_private.create_profile_for_new_user();

insert into public.profiles (id, display_name, avatar_url)
select
  users.id,
  case
    when char_length(btrim(users.raw_user_meta_data ->> 'display_name')) between 1 and 100
      then btrim(users.raw_user_meta_data ->> 'display_name')
  end,
  case
    when char_length(btrim(users.raw_user_meta_data ->> 'avatar_url')) between 1 and 2048
      then btrim(users.raw_user_meta_data ->> 'avatar_url')
  end
from auth.users as users
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.fantasy_accounts enable row level security;
alter table public.user_fantasy_accounts enable row level security;

create policy "authenticated users can select their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "authenticated users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "authenticated users can select their linked fantasy accounts"
on public.fantasy_accounts
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as links
    where links.user_id = (select auth.uid())
      and links.fantasy_account_id = fantasy_accounts.id
  )
);

create policy "authenticated users can select their own fantasy account links"
on public.user_fantasy_accounts
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.fantasy_accounts from public, anon, authenticated;
revoke all on table public.user_fantasy_accounts from public, anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name, avatar_url) on table public.profiles to authenticated;
grant select on table public.fantasy_accounts to authenticated;
grant select on table public.user_fantasy_accounts to authenticated;

grant select, insert, update, delete on table public.profiles to service_role;
grant select, insert, update, delete on table public.fantasy_accounts to service_role;
grant select, insert, update, delete on table public.user_fantasy_accounts to service_role;

revoke all on function app_private.set_updated_at() from public, anon, authenticated;
revoke all on function app_private.create_profile_for_new_user()
  from public, anon, authenticated;

grant execute on function app_private.set_updated_at() to postgres, service_role;
grant execute on function app_private.create_profile_for_new_user()
  to postgres, service_role;
