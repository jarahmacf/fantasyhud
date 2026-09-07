-- Explicit, reversible read-only access requested by the workspace owner.
-- No Auth identity is impersonated and no anonymous writes are granted.
create table app_private.temporary_workspace_access (
  singleton boolean primary key default true check (singleton),
  fantasy_account_id uuid not null references public.fantasy_accounts(id) on delete cascade,
  enabled boolean not null default false
);

alter table app_private.temporary_workspace_access enable row level security;
revoke all on app_private.temporary_workspace_access from public, anon, authenticated, service_role;

create function public.get_temporary_workspace()
returns table (id uuid, provider text, username text, display_name text)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select account.id, account.provider, account.username, account.display_name
  from app_private.temporary_workspace_access as access
  join public.fantasy_accounts as account on account.id = access.fantasy_account_id
  where access.singleton and access.enabled and account.provider = 'sleeper';
$$;

revoke all on function public.get_temporary_workspace() from public;
grant execute on function public.get_temporary_workspace() to anon, authenticated, service_role;

-- Activate only the already existing, explicitly approved canonical account.
-- Fresh databases and CI contain no matching account and remain private.
insert into app_private.temporary_workspace_access (fantasy_account_id, enabled)
select id, true from public.fantasy_accounts
where id = 'dfe53328-459b-4120-99e3-6c2982f87446'::uuid
  and provider = 'sleeper' and external_user_id = '1373015982733295616';

-- Column grants deliberately exclude Auth identities, private payloads, and
-- draft data. SELECT * remains denied on these tables.
grant select (provider, sport, league_season)
  on public.provider_season_states to anon;
grant select (id, provider, sport, season, name, status, team_count,
  roster_management_type, is_best_ball, scoring_format, has_superflex)
  on public.leagues to anon;
grant select (id, fantasy_account_id, league_id, removed_at, roster_ownership_status)
  on public.fantasy_account_leagues to anon;
grant select (id, fantasy_account_id, provider, sport, season, scope, status,
  result_counts, finished_at, created_at)
  on public.sync_runs to anon;
grant select (id, provider, sport, catalog, status, source_fetched_at, created_at)
  on public.provider_catalog_runs to anon;
grant select (id, sport, entity_type, display_name, primary_position,
  fantasy_positions, nfl_team, active, status, injury_status, injury_body_part)
  on public.players to anon;
grant select (id, player_id, namespace, sport, external_id, is_primary, removed_at)
  on public.player_external_ids to anon;
grant select (id, league_id, external_user_id, team_name, display_name, username, removed_at)
  on public.league_users to anon;
grant select (id, fantasy_account_id, league_id, roster_id, ownership_role, removed_at)
  on public.fantasy_account_rosters to anon;
grant select (id, league_id, external_roster_id, owner_external_user_id,
  source_player_ids, source_starter_ids, source_reserve_ids, source_taxi_ids,
  source_keeper_ids, removed_at)
  on public.rosters to anon;
grant select (id, roster_id, league_id, player_id, source_player_external_id_id,
  source_order, is_starter, is_reserve, is_taxi, is_keeper, source_metadata, removed_at)
  on public.roster_players to anon;

create policy "temporary workspace season reads"
  on public.provider_season_states for select to anon
  using (provider = 'sleeper' and sport = 'nfl'
    and (select id from public.get_temporary_workspace()) is not null);

create policy "temporary workspace league association reads"
  on public.fantasy_account_leagues for select to anon
  using (fantasy_account_id = (select id from public.get_temporary_workspace())
    and removed_at is null);

create policy "temporary workspace league reads"
  on public.leagues for select to anon
  using (provider = 'sleeper' and sport = 'nfl' and id in (
    select association.league_id from public.fantasy_account_leagues as association
    where association.fantasy_account_id = (select id from public.get_temporary_workspace())
      and association.removed_at is null
  ));

create policy "temporary workspace import status reads"
  on public.sync_runs for select to anon
  using (fantasy_account_id = (select id from public.get_temporary_workspace())
    and provider = 'sleeper' and sport = 'nfl'
    and scope in ('league_discovery', 'roster_sync'));

create policy "temporary workspace catalog status reads"
  on public.provider_catalog_runs for select to anon
  using (provider = 'sleeper' and sport = 'nfl' and catalog = 'players'
    and (select id from public.get_temporary_workspace()) is not null);

create policy "temporary workspace player reads"
  on public.players for select to anon
  using (sport = 'nfl' and (select id from public.get_temporary_workspace()) is not null);

create policy "temporary workspace player mapping reads"
  on public.player_external_ids for select to anon
  using (namespace = 'sleeper' and sport = 'nfl'
    and (select id from public.get_temporary_workspace()) is not null);

create policy "temporary workspace league user reads"
  on public.league_users for select to anon
  using (removed_at is null and league_id in (
    select association.league_id from public.fantasy_account_leagues as association
    where association.fantasy_account_id = (select id from public.get_temporary_workspace())
      and association.removed_at is null
  ));

create policy "temporary workspace confirmed ownership reads"
  on public.fantasy_account_rosters for select to anon
  using (fantasy_account_id = (select id from public.get_temporary_workspace())
    and removed_at is null and league_id in (
      select association.league_id from public.fantasy_account_leagues as association
      where association.fantasy_account_id = (select id from public.get_temporary_workspace())
        and association.removed_at is null and association.roster_ownership_status = 'owned'
    ));

create policy "temporary workspace owned roster reads"
  on public.rosters for select to anon
  using (removed_at is null and id in (
    select ownership.roster_id from public.fantasy_account_rosters as ownership
    where ownership.fantasy_account_id = (select id from public.get_temporary_workspace())
      and ownership.removed_at is null
  ));

create policy "temporary workspace owned membership reads"
  on public.roster_players for select to anon
  using (removed_at is null and roster_id in (
    select roster.id from public.rosters as roster where roster.removed_at is null
  ));
