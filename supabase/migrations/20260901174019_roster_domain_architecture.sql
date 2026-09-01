create or replace function app_private.exact_text_array_is_safe(
  p_values text[],
  p_maximum_count integer,
  p_require_unique boolean
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
    p_values is not null
    and p_maximum_count is not null
    and p_maximum_count > 0
    and p_require_unique is not null
    and coalesce(pg_catalog.array_ndims(p_values), 1) = 1
    and pg_catalog.cardinality(p_values) <= p_maximum_count
    and not exists (
      select 1
      from pg_catalog.unnest(p_values) as item(value)
      where item.value is null
        or item.value <> pg_catalog.btrim(item.value)
        or pg_catalog.char_length(item.value) not between 1 and 255
        or item.value ~ '[[:cntrl:]]'
    )
    and (
      not p_require_unique
      or pg_catalog.cardinality(p_values) = (
        select pg_catalog.count(distinct item.value)
        from pg_catalog.unnest(p_values) as item(value)
      )
    ),
    false
  );
$$;

revoke all on function app_private.exact_text_array_is_safe(
  text[],
  integer,
  boolean
) from public, anon, authenticated, service_role;

comment on function app_private.exact_text_array_is_safe(
  text[],
  integer,
  boolean
) is
  'Owner-only immutable constraint helper for bounded exact one-dimensional text arrays.';

create table public.league_users (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  external_user_id text not null,
  username text,
  display_name text,
  team_name text,
  avatar_id text,
  avatar_url text,
  is_commissioner boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint league_users_league_external_user_key unique (
    league_id,
    external_user_id
  ),
  constraint league_users_external_user_id_is_exact check (
    external_user_id = btrim(external_user_id)
    and char_length(external_user_id) between 1 and 255
    and external_user_id !~ '[[:cntrl:]]'
  ),
  constraint league_users_display_fields_are_safe check (
    (username is null or (
      username = btrim(username)
      and char_length(username) between 1 and 100
      and username !~ '[[:cntrl:]]'
    ))
    and (display_name is null or (
      display_name = btrim(display_name)
      and char_length(display_name) between 1 and 255
      and display_name !~ '[[:cntrl:]]'
    ))
    and (team_name is null or (
      team_name = btrim(team_name)
      and char_length(team_name) between 1 and 255
      and team_name !~ '[[:cntrl:]]'
    ))
  ),
  constraint league_users_avatar_fields_are_safe check (
    (avatar_id is null or (
      avatar_id = btrim(avatar_id)
      and char_length(avatar_id) between 1 and 255
      and avatar_id !~ '[[:cntrl:]]'
    ))
    and (avatar_url is null or (
      avatar_url = btrim(avatar_url)
      and char_length(avatar_url) between 1 and 2048
      and avatar_url !~ '[[:cntrl:]]'
    ))
  ),
  constraint league_users_metadata_is_bounded_object check (
    jsonb_typeof(metadata) = 'object'
    and pg_column_size(metadata) <= 65536
  ),
  constraint league_users_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint league_users_timestamps_are_finite check (
    isfinite(fetched_at)
    and isfinite(first_seen_at)
    and isfinite(last_seen_at)
    and (removed_at is null or isfinite(removed_at))
    and isfinite(created_at)
    and isfinite(updated_at)
  )
);

comment on table public.league_users is
  'One provider user identity as represented within one canonical league.';

create index league_users_league_removed_external_idx
  on public.league_users (league_id, removed_at, external_user_id);
create index league_users_external_league_idx
  on public.league_users (external_user_id, league_id);
create index league_users_lower_display_name_idx
  on public.league_users (lower(display_name))
  where display_name is not null;

create table public.rosters (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  external_roster_id integer not null,
  owner_external_user_id text,
  co_owner_external_user_ids text[],
  source_player_ids text[],
  source_starter_ids text[],
  source_reserve_ids text[],
  source_taxi_ids text[],
  source_keeper_ids text[],
  settings jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rosters_league_external_roster_key unique (
    league_id,
    external_roster_id
  ),
  constraint rosters_id_league_key unique (id, league_id),
  constraint rosters_external_roster_id_is_bounded check (
    external_roster_id between 1 and 1000000
  ),
  constraint rosters_owner_external_user_id_is_exact check (
    owner_external_user_id is null or (
      owner_external_user_id = btrim(owner_external_user_id)
      and char_length(owner_external_user_id) between 1 and 255
      and owner_external_user_id !~ '[[:cntrl:]]'
    )
  ),
  constraint rosters_co_owner_ids_are_safe check (
    co_owner_external_user_ids is null or (
      app_private.exact_text_array_is_safe(
        co_owner_external_user_ids,
        1000,
        true
      )
    )
  ),
  constraint rosters_source_player_ids_are_safe check (
    source_player_ids is null or (
      app_private.exact_text_array_is_safe(source_player_ids, 1000, true)
    )
  ),
  constraint rosters_source_starter_ids_are_safe check (
    source_starter_ids is null or (
      app_private.exact_text_array_is_safe(source_starter_ids, 1000, false)
    )
  ),
  constraint rosters_source_reserve_ids_are_safe check (
    source_reserve_ids is null or (
      app_private.exact_text_array_is_safe(source_reserve_ids, 1000, true)
    )
  ),
  constraint rosters_source_taxi_ids_are_safe check (
    source_taxi_ids is null or (
      app_private.exact_text_array_is_safe(source_taxi_ids, 1000, true)
    )
  ),
  constraint rosters_source_keeper_ids_are_safe check (
    source_keeper_ids is null or (
      app_private.exact_text_array_is_safe(source_keeper_ids, 1000, true)
    )
  ),
  constraint rosters_json_objects_are_bounded check (
    jsonb_typeof(settings) = 'object'
    and jsonb_typeof(metadata) = 'object'
    and pg_column_size(settings) <= 131072
    and pg_column_size(metadata) <= 65536
  ),
  constraint rosters_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint rosters_timestamps_are_finite check (
    isfinite(fetched_at)
    and isfinite(first_seen_at)
    and isfinite(last_seen_at)
    and (removed_at is null or isfinite(removed_at))
    and isfinite(created_at)
    and isfinite(updated_at)
  )
);

comment on table public.rosters is
  'One league-local current provider roster with exact ordered source arrays.';
comment on column public.rosters.source_player_ids is
  'Exact ordered provider players array, retained beside normalized current memberships.';
comment on column public.rosters.source_starter_ids is
  'Exact ordered provider starters array; repeated empty-slot sentinels remain valid source facts.';
comment on column public.rosters.source_keeper_ids is
  'Exact ordered current provider keepers array; null means absent and an empty array means explicitly empty.';

create index rosters_league_removed_external_idx
  on public.rosters (league_id, removed_at, external_roster_id);
create index rosters_owner_league_idx
  on public.rosters (owner_external_user_id, league_id)
  where owner_external_user_id is not null;

create table public.fantasy_account_rosters (
  id uuid primary key default gen_random_uuid(),
  fantasy_account_id uuid not null,
  league_id uuid not null,
  roster_id uuid not null,
  ownership_role text not null,
  source_metadata jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fantasy_account_rosters_account_league_fkey foreign key (
    fantasy_account_id,
    league_id
  ) references public.fantasy_account_leagues (
    fantasy_account_id,
    league_id
  ) on delete cascade,
  constraint fantasy_account_rosters_roster_league_fkey foreign key (
    roster_id,
    league_id
  ) references public.rosters (id, league_id) on delete cascade,
  constraint fantasy_account_rosters_account_league_roster_key unique (
    fantasy_account_id,
    league_id,
    roster_id
  ),
  constraint fantasy_account_rosters_ownership_role_is_known check (
    ownership_role in ('owner', 'co_owner')
  ),
  constraint fantasy_account_rosters_metadata_is_bounded_object check (
    jsonb_typeof(source_metadata) = 'object'
    and pg_column_size(source_metadata) <= 32768
  ),
  constraint fantasy_account_rosters_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint fantasy_account_rosters_timestamps_are_finite check (
    isfinite(first_seen_at)
    and isfinite(last_seen_at)
    and (removed_at is null or isfinite(removed_at))
    and isfinite(created_at)
    and isfinite(updated_at)
  )
);

comment on table public.fantasy_account_rosters is
  'One explicit tracked fantasy-account ownership association to one roster in one league.';

create unique index fantasy_account_rosters_one_active_account_league_idx
  on public.fantasy_account_rosters (fantasy_account_id, league_id)
  where removed_at is null;
create index fantasy_account_rosters_account_league_removed_idx
  on public.fantasy_account_rosters (
    fantasy_account_id,
    league_id,
    removed_at
  );
create index fantasy_account_rosters_roster_account_idx
  on public.fantasy_account_rosters (roster_id, fantasy_account_id);
create index fantasy_account_rosters_league_roster_idx
  on public.fantasy_account_rosters (league_id, roster_id);

alter table public.player_external_ids
add constraint player_external_ids_id_player_key unique (id, player_id);

create table public.roster_players (
  id uuid primary key default gen_random_uuid(),
  roster_id uuid not null,
  league_id uuid not null,
  player_id uuid not null,
  source_player_external_id_id uuid not null,
  source_order integer,
  is_starter boolean not null default false,
  starter_order integer,
  starter_slot text,
  is_reserve boolean not null default false,
  is_taxi boolean not null default false,
  is_keeper boolean not null default false,
  source_metadata jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roster_players_roster_league_fkey foreign key (
    roster_id,
    league_id
  ) references public.rosters (id, league_id) on delete cascade,
  constraint roster_players_player_id_fkey foreign key (player_id)
    references public.players(id) on delete restrict,
  constraint roster_players_mapping_player_fkey foreign key (
    source_player_external_id_id,
    player_id
  ) references public.player_external_ids (id, player_id) on delete restrict,
  constraint roster_players_roster_player_key unique (roster_id, player_id),
  constraint roster_players_roster_source_mapping_key unique (
    roster_id,
    source_player_external_id_id
  ),
  constraint roster_players_source_order_is_bounded check (
    source_order is null or source_order between 1 and 1000
  ),
  constraint roster_players_starter_state_is_consistent check (
    (
      is_starter
      and starter_order is not null
      and starter_order between 1 and 1000
    )
    or (
      not is_starter
      and starter_order is null
      and starter_slot is null
    )
  ),
  constraint roster_players_starter_slot_is_safe check (
    starter_slot is null or starter_slot ~ '^[A-Z0-9_]{1,64}$'
  ),
  constraint roster_players_metadata_is_bounded_object check (
    jsonb_typeof(source_metadata) = 'object'
    and pg_column_size(source_metadata) <= 32768
  ),
  constraint roster_players_observation_order_is_valid check (
    last_seen_at >= first_seen_at
    and (removed_at is null or removed_at >= last_seen_at)
  ),
  constraint roster_players_timestamps_are_finite check (
    isfinite(first_seen_at)
    and isfinite(last_seen_at)
    and (removed_at is null or isfinite(removed_at))
    and isfinite(created_at)
    and isfinite(updated_at)
  )
);

comment on table public.roster_players is
  'One canonical player current-membership row on one current roster; not draft, transaction, or weekly-lineup history.';

create unique index roster_players_one_active_source_order_idx
  on public.roster_players (roster_id, source_order)
  where removed_at is null and source_order is not null;
create unique index roster_players_one_active_starter_order_idx
  on public.roster_players (roster_id, starter_order)
  where removed_at is null
    and is_starter
    and starter_order is not null;
create index roster_players_active_player_roster_idx
  on public.roster_players (player_id, roster_id)
  where removed_at is null;
create index roster_players_active_league_roster_player_idx
  on public.roster_players (league_id, roster_id, player_id)
  where removed_at is null;
create index roster_players_roster_removed_idx
  on public.roster_players (roster_id, removed_at);

alter table public.sync_runs
drop constraint sync_runs_scope_is_known;

alter table public.sync_runs
add constraint sync_runs_scope_is_known check (
  scope in ('league_discovery', 'roster_sync')
);

create unique index sync_runs_one_running_roster_sync_per_account_idx
  on public.sync_runs (fantasy_account_id)
  where scope = 'roster_sync' and status = 'running';

comment on column public.sync_runs.triggered_by_user_id is
  'Server-only run ownership and audit state; intentionally excluded from authenticated browser grants.';

create trigger league_users_set_updated_at
before update on public.league_users
for each row execute function app_private.set_updated_at();

create trigger rosters_set_updated_at
before update on public.rosters
for each row execute function app_private.set_updated_at();

create trigger fantasy_account_rosters_set_updated_at
before update on public.fantasy_account_rosters
for each row execute function app_private.set_updated_at();

create trigger roster_players_set_updated_at
before update on public.roster_players
for each row execute function app_private.set_updated_at();

alter table public.league_users enable row level security;
alter table public.rosters enable row level security;
alter table public.fantasy_account_rosters enable row level security;
alter table public.roster_players enable row level security;

create policy "authenticated users can select reachable league users"
on public.league_users
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_leagues as discovered_league
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where discovered_league.league_id = league_users.league_id
      and discovered_league.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select reachable rosters"
on public.rosters
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_leagues as discovered_league
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where discovered_league.league_id = rosters.league_id
      and discovered_league.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select their account roster ownership"
on public.fantasy_account_rosters
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as account_link
    where account_link.fantasy_account_id =
        fantasy_account_rosters.fantasy_account_id
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select reachable roster players"
on public.roster_players
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_leagues as discovered_league
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where discovered_league.league_id = roster_players.league_id
      and discovered_league.removed_at is null
      and account_link.user_id = (select auth.uid())
  )
);

revoke all on table public.league_users
from public, anon, authenticated, service_role;
revoke all on table public.rosters
from public, anon, authenticated, service_role;
revoke all on table public.fantasy_account_rosters
from public, anon, authenticated, service_role;
revoke all on table public.roster_players
from public, anon, authenticated, service_role;

grant select on table public.league_users to authenticated;
grant select on table public.rosters to authenticated;
grant select on table public.fantasy_account_rosters to authenticated;
grant select on table public.roster_players to authenticated;

revoke select on table public.sync_runs from authenticated;
grant select (
  id,
  fantasy_account_id,
  provider,
  sport,
  season,
  scope,
  status,
  progress_current,
  progress_total,
  result_counts,
  error_summary,
  started_at,
  finished_at,
  created_at,
  updated_at
) on table public.sync_runs to authenticated;
