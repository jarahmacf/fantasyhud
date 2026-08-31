create table public.provider_season_states (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  sport text not null,
  season integer not null,
  league_season integer not null,
  league_create_season integer,
  previous_season integer,
  season_type text not null,
  week integer,
  leg integer,
  display_week integer,
  season_start_date date,
  provider_metadata jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_season_states_provider_sport_key unique (provider, sport),
  constraint provider_season_states_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint provider_season_states_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint provider_season_states_season_is_bounded check (
    season between 1900 and 2999
  ),
  constraint provider_season_states_league_season_is_bounded check (
    league_season between 1900 and 2999
  ),
  constraint provider_season_states_league_create_season_is_bounded check (
    league_create_season is null
    or league_create_season between 1900 and 2999
  ),
  constraint provider_season_states_previous_season_is_bounded check (
    previous_season is null or previous_season between 1900 and 2999
  ),
  constraint provider_season_states_season_type_is_safe check (
    season_type ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint provider_season_states_week_is_nonnegative check (
    week is null or week >= 0
  ),
  constraint provider_season_states_leg_is_nonnegative check (
    leg is null or leg >= 0
  ),
  constraint provider_season_states_display_week_is_nonnegative check (
    display_week is null or display_week >= 0
  ),
  constraint provider_season_states_metadata_is_object check (
    jsonb_typeof(provider_metadata) = 'object'
  )
);

comment on table public.provider_season_states is
  'Latest shared provider season state by provider and sport; not a historical week fact table.';

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  external_league_id text not null,
  sport text not null,
  season integer not null,
  name text not null,
  status text not null,
  season_type text not null,
  team_count integer not null,
  roster_size integer not null,
  roster_management_type text not null,
  is_best_ball boolean not null,
  has_superflex boolean not null,
  has_idp boolean not null,
  scoring_format text not null,
  avatar_id text,
  avatar_url text,
  previous_external_league_id text,
  settings jsonb not null,
  scoring_settings jsonb not null,
  roster_positions jsonb not null,
  provider_metadata jsonb not null default '{}'::jsonb,
  provider_updated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leagues_provider_external_league_id_key unique (
    provider,
    external_league_id
  ),
  constraint leagues_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint leagues_external_league_id_is_bounded check (
    external_league_id = btrim(external_league_id)
    and char_length(external_league_id) between 1 and 255
  ),
  constraint leagues_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint leagues_season_is_bounded check (season between 1900 and 2999),
  constraint leagues_name_is_trimmed_and_bounded check (
    name = btrim(name) and char_length(name) between 1 and 255
  ),
  constraint leagues_status_is_safe check (
    status ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint leagues_season_type_is_safe check (
    season_type ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint leagues_team_count_is_bounded check (team_count between 1 and 1000),
  constraint leagues_roster_size_is_bounded check (
    roster_size between 0 and 1000
  ),
  constraint leagues_roster_management_type_is_known check (
    roster_management_type in ('redraft', 'keeper', 'dynasty', 'unknown')
  ),
  constraint leagues_scoring_format_is_known check (
    scoring_format in ('ppr', 'half_ppr', 'standard', 'custom', 'unknown')
  ),
  constraint leagues_avatar_id_is_trimmed_and_bounded check (
    avatar_id is null
    or (
      avatar_id = btrim(avatar_id)
      and char_length(avatar_id) between 1 and 255
    )
  ),
  constraint leagues_avatar_url_is_trimmed_and_bounded check (
    avatar_url is null
    or (
      avatar_url = btrim(avatar_url)
      and char_length(avatar_url) between 1 and 2048
    )
  ),
  constraint leagues_previous_external_id_is_bounded check (
    previous_external_league_id is null
    or (
      previous_external_league_id = btrim(previous_external_league_id)
      and char_length(previous_external_league_id) between 1 and 255
    )
  ),
  constraint leagues_settings_is_object check (jsonb_typeof(settings) = 'object'),
  constraint leagues_scoring_settings_is_object check (
    jsonb_typeof(scoring_settings) = 'object'
  ),
  constraint leagues_roster_positions_is_array check (
    jsonb_typeof(roster_positions) = 'array'
  ),
  constraint leagues_provider_metadata_is_object check (
    jsonb_typeof(provider_metadata) = 'object'
  )
);

comment on table public.leagues is
  'One shared provider league keyed by provider and exact external league ID.';
comment on column public.leagues.settings is
  'Exact provider league settings; derived columns are presentation and filter aids only.';
comment on column public.leagues.scoring_settings is
  'Exact provider scoring settings; never replace with the broad scoring_format value.';
comment on column public.leagues.roster_positions is
  'Exact ordered provider roster-position array.';

create index leagues_sport_season_provider_idx
  on public.leagues (sport, season desc, provider);
create index leagues_status_idx on public.leagues (status);
create index leagues_management_best_ball_idx
  on public.leagues (roster_management_type, is_best_ball);
create index leagues_scoring_format_idx on public.leagues (scoring_format);

create table public.fantasy_account_leagues (
  id uuid primary key default gen_random_uuid(),
  fantasy_account_id uuid not null
    references public.fantasy_accounts(id) on delete cascade,
  league_id uuid not null references public.leagues(id) on delete cascade,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fantasy_account_leagues_account_league_key unique (
    fantasy_account_id,
    league_id
  ),
  constraint fantasy_account_leagues_seen_order_is_valid check (
    last_seen_at >= first_seen_at
  ),
  constraint fantasy_account_leagues_removed_time_is_valid check (
    removed_at is null or removed_at >= first_seen_at
  )
);

comment on table public.fantasy_account_leagues is
  'Discovery association: a provider user-leagues response reported the shared league for the tracked fantasy account. This does not prove roster ownership.';

create index fantasy_account_leagues_active_account_idx
  on public.fantasy_account_leagues (
    fantasy_account_id,
    last_seen_at desc,
    league_id
  )
  where removed_at is null;
create index fantasy_account_leagues_removed_account_idx
  on public.fantasy_account_leagues (fantasy_account_id, removed_at desc)
  where removed_at is not null;
create index fantasy_account_leagues_league_account_idx
  on public.fantasy_account_leagues (league_id, fantasy_account_id);

create table public.sync_runs (
  id uuid primary key default gen_random_uuid(),
  fantasy_account_id uuid not null
    references public.fantasy_accounts(id) on delete cascade,
  triggered_by_user_id uuid references auth.users(id) on delete set null,
  provider text not null,
  sport text not null,
  season integer,
  scope text not null,
  status text not null,
  progress_current integer not null default 0,
  progress_total integer not null default 0,
  result_counts jsonb not null default '{}'::jsonb,
  error_summary jsonb not null default '{}'::jsonb,
  started_at timestamptz not null,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sync_runs_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint sync_runs_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint sync_runs_season_is_bounded check (
    season is null or season between 1900 and 2999
  ),
  constraint sync_runs_scope_is_known check (scope in ('league_discovery')),
  constraint sync_runs_status_is_known check (
    status in ('running', 'succeeded', 'failed', 'partial')
  ),
  constraint sync_runs_progress_is_nonnegative check (
    progress_current >= 0 and progress_total >= 0
  ),
  constraint sync_runs_progress_does_not_exceed_total check (
    progress_total = 0 or progress_current <= progress_total
  ),
  constraint sync_runs_lifecycle_is_valid check (
    (status = 'running' and finished_at is null)
    or (
      status in ('succeeded', 'failed', 'partial')
      and finished_at is not null
    )
  ),
  constraint sync_runs_finished_time_is_valid check (
    finished_at is null or finished_at >= started_at
  ),
  constraint sync_runs_result_counts_is_object check (
    jsonb_typeof(result_counts) = 'object'
  ),
  constraint sync_runs_error_summary_is_object check (
    jsonb_typeof(error_summary) = 'object'
  )
);

comment on table public.sync_runs is
  'One traceable synchronization attempt for one tracked fantasy account and one scope.';
comment on column public.sync_runs.error_summary is
  'Sanitized structured error metadata only; never a raw provider response, credential, or token.';

create unique index sync_runs_one_running_league_discovery_per_account_idx
  on public.sync_runs (fantasy_account_id)
  where scope = 'league_discovery' and status = 'running';
create index sync_runs_account_created_at_idx
  on public.sync_runs (fantasy_account_id, created_at desc);
create index sync_runs_status_idx on public.sync_runs (status);
create index sync_runs_scope_status_idx on public.sync_runs (scope, status);

create trigger provider_season_states_set_updated_at
before update on public.provider_season_states
for each row execute function app_private.set_updated_at();

create trigger leagues_set_updated_at
before update on public.leagues
for each row execute function app_private.set_updated_at();

create trigger fantasy_account_leagues_set_updated_at
before update on public.fantasy_account_leagues
for each row execute function app_private.set_updated_at();

create trigger sync_runs_set_updated_at
before update on public.sync_runs
for each row execute function app_private.set_updated_at();

alter table public.provider_season_states enable row level security;
alter table public.leagues enable row level security;
alter table public.fantasy_account_leagues enable row level security;
alter table public.sync_runs enable row level security;

create policy "authenticated users can select provider season state"
on public.provider_season_states
for select
to authenticated
using (true);

create policy "authenticated users can select their fantasy account leagues"
on public.fantasy_account_leagues
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as account_links
    where account_links.user_id = (select auth.uid())
      and account_links.fantasy_account_id =
        fantasy_account_leagues.fantasy_account_id
  )
);

create policy "authenticated users can select reachable leagues"
on public.leagues
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_leagues as discovered_leagues
    inner join public.user_fantasy_accounts as account_links
      on account_links.fantasy_account_id =
        discovered_leagues.fantasy_account_id
    where discovered_leagues.league_id = leagues.id
      and account_links.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select their account sync runs"
on public.sync_runs
for select
to authenticated
using (
  exists (
    select 1
    from public.user_fantasy_accounts as account_links
    where account_links.user_id = (select auth.uid())
      and account_links.fantasy_account_id = sync_runs.fantasy_account_id
  )
);

revoke all on table public.provider_season_states
  from public, anon, authenticated;
revoke all on table public.leagues from public, anon, authenticated;
revoke all on table public.fantasy_account_leagues
  from public, anon, authenticated;
revoke all on table public.sync_runs from public, anon, authenticated;

grant select on table public.provider_season_states to authenticated;
grant select on table public.leagues to authenticated;
grant select on table public.fantasy_account_leagues to authenticated;
grant select on table public.sync_runs to authenticated;

grant select, insert, update, delete on table public.provider_season_states
  to service_role;
grant select, insert, update, delete on table public.leagues to service_role;
grant select, insert, update, delete on table public.fantasy_account_leagues
  to service_role;
grant select, insert, update, delete on table public.sync_runs to service_role;
