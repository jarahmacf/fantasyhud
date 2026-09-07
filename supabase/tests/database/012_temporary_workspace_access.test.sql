begin;
select plan(40);

select is((select count(*)::integer from public.get_temporary_workspace()), 0, 'fresh database requires authentication');

-- BEGIN TEMPORARY ACCESS FIXTURE
insert into public.fantasy_accounts (id, provider, external_user_id, username, normalized_username) values
('12000000-0000-4000-8000-000000000001','sleeper','temporary-workspace-user','OpenFixture','openfixture'),
('12000000-0000-4000-8000-000000000002','sleeper','private-workspace-user','PrivateFixture','privatefixture');

insert into public.provider_season_states (provider,sport,season,league_season,season_type,fetched_at)
values ('sleeper','nfl',2026,2026,'regular',now())
on conflict (provider,sport) do update set league_season=2026;

insert into public.leagues (id,provider,external_league_id,sport,season,name,status,season_type,team_count,roster_size,roster_management_type,is_best_ball,has_superflex,has_idp,scoring_format,settings,scoring_settings,roster_positions,provider_updated_at,fetched_at)
select ('12100000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 'sleeper','temporary-league-' || n,'nfl',2026,
 case n when 1 then 'Temporary Access League' when 2 then 'Unresolved Access League' else 'Private Account League' end,
 'pre_draft','regular',2,1,'redraft',false,false,false,'standard','{}','{}','["WR"]',now(),now()
from generate_series(1,3) n;

insert into public.fantasy_account_leagues (fantasy_account_id,league_id,first_seen_at,last_seen_at,roster_ownership_status,roster_ownership_observed_at)
select case when n=3 then '12000000-0000-4000-8000-000000000002'::uuid else '12000000-0000-4000-8000-000000000001'::uuid end,
 ('12100000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,now(),now(),case when n=2 then 'unresolved' else 'owned' end,now()
from generate_series(1,3) n;

insert into public.rosters (id,league_id,external_roster_id,owner_external_user_id,source_player_ids,source_starter_ids,source_reserve_ids,source_taxi_ids,source_keeper_ids,fetched_at,first_seen_at,last_seen_at)
select ('12200000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 ('12100000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,1,
 case when n=3 then 'private-workspace-user' else 'temporary-workspace-user' end,
 array['temporary-player'],array[]::text[],array[]::text[],null,array[]::text[],now(),now(),now()
from generate_series(1,3) n;

insert into public.fantasy_account_rosters (fantasy_account_id,league_id,roster_id,ownership_role,first_seen_at,last_seen_at)
select association.fantasy_account_id,association.league_id,roster.id,'owner',now(),now()
from public.fantasy_account_leagues association join public.rosters roster on roster.league_id=association.league_id
where association.fantasy_account_id in ('12000000-0000-4000-8000-000000000001','12000000-0000-4000-8000-000000000002');

insert into public.league_users (league_id,external_user_id,team_name,fetched_at,first_seen_at,last_seen_at)
select league_id,owner_external_user_id,'Temporary Fixture Team',now(),now(),now()
from public.rosters where id in ('12200000-0000-4000-8000-000000000001','12200000-0000-4000-8000-000000000002','12200000-0000-4000-8000-000000000003');

insert into public.players (id,sport,entity_type,display_name,primary_position,fantasy_positions,active,profile_source,profile_fetched_at)
values ('12300000-0000-4000-8000-000000000001','nfl','player','Temporary Fixture Player','WR',array['WR'],true,'sleeper',now());
insert into public.player_external_ids (id,player_id,namespace,sport,external_id,reported_by,is_primary,first_seen_at,last_seen_at)
values ('12400000-0000-4000-8000-000000000001','12300000-0000-4000-8000-000000000001','sleeper','nfl','temporary-player','sleeper',true,now(),now());
insert into public.roster_players (roster_id,league_id,player_id,source_player_external_id_id,source_order,source_metadata,first_seen_at,last_seen_at)
select id,league_id,'12300000-0000-4000-8000-000000000001','12400000-0000-4000-8000-000000000001',1,
 '{"annotation_source_state":{"starters":"known","reserve":"known","taxi":"unknown","keepers":"known"},"normalization_warning_fields":[]}',now(),now()
from public.rosters where id in ('12200000-0000-4000-8000-000000000001','12200000-0000-4000-8000-000000000002','12200000-0000-4000-8000-000000000003');

insert into public.provider_catalog_runs (provider,sport,catalog,status,source_fetched_at,started_at,finished_at)
values ('sleeper','nfl','players','succeeded',now(),now(),now());
insert into public.sync_runs (fantasy_account_id,provider,sport,season,scope,status,result_counts,started_at,finished_at)
values
('12000000-0000-4000-8000-000000000001','sleeper','nfl',2026,'league_discovery','succeeded','{}',now(),now()),
('12000000-0000-4000-8000-000000000001','sleeper','nfl',2026,'roster_sync','partial','{"unresolved_ownership_leagues":1}',now(),now()),
('12000000-0000-4000-8000-000000000002','sleeper','nfl',2026,'roster_sync','succeeded','{}',now(),now());

insert into app_private.temporary_workspace_access (fantasy_account_id,enabled)
values ('12000000-0000-4000-8000-000000000001',true)
on conflict (singleton) do update set fantasy_account_id=excluded.fantasy_account_id,enabled=true;
-- END TEMPORARY ACCESS FIXTURE

select ok((select relrowsecurity from pg_class where oid='app_private.temporary_workspace_access'::regclass),'private switch uses RLS');
select ok((select prosecdef from pg_proc where oid='public.get_temporary_workspace()'::regprocedure),'context uses one bounded privileged read');
select is((select proconfig::text from pg_proc where oid='public.get_temporary_workspace()'::regprocedure),'{search_path=pg_catalog}','context has a fixed search path');
select ok(not has_schema_privilege('anon','app_private','usage'),'anonymous cannot access private schema');
select ok(not has_table_privilege('service_role','public.rosters','select'),'service role gains no provider-table read grant');
select ok(not has_column_privilege('anon','public.sync_runs','triggered_by_user_id','select'),'triggering Auth identity stays private');
select ok(not has_column_privilege('anon','public.provider_catalog_runs','triggered_by_user_id','select'),'catalog triggering identity stays private');
select ok(not has_column_privilege('anon','public.rosters','metadata','select'),'raw roster metadata stays private');
select ok(not has_column_privilege('anon','public.leagues','settings','select'),'raw league settings stay private');
select ok(not exists (
 select 1 from (values ('provider_season_states'),('leagues'),('fantasy_account_leagues'),('sync_runs'),('provider_catalog_runs'),('players'),('player_external_ids'),('league_users'),('fantasy_account_rosters'),('rosters'),('roster_players')) t(name)
 where has_table_privilege('anon','public.'||t.name,'insert,update,delete')
),'temporary access grants no anonymous mutation');
select ok(not has_function_privilege('anon','public.start_sleeper_roster_sync(uuid,uuid)','execute'),'public callers cannot start imports');
select ok(not has_function_privilege('anon','public.connect_sleeper_account(uuid,text,text,text,text,jsonb)','execute'),'public callers cannot connect accounts');

set local role anon;
select is(auth.uid(),null::uuid,'temporary access creates no authenticated identity');
select is((select id from public.get_temporary_workspace()),'12000000-0000-4000-8000-000000000001'::uuid,'context selects exactly the approved account');
select is((select count(id)::integer from public.leagues),2,'only selected-account leagues are visible');
select is((select count(id)::integer from public.leagues where name='Private Account League'),0,'unrelated league is hidden');
select is((select count(id)::integer from public.fantasy_account_leagues),2,'only active selected associations are visible');
select is((select count(id)::integer from public.fantasy_account_rosters),1,'unresolved ownership history is hidden');
select is((select count(id)::integer from public.rosters),1,'only confirmed owned rosters are visible');
select is((select count(id)::integer from public.roster_players),1,'only confirmed owned memberships are visible');
select is((select count(id)::integer from public.league_users),2,'league users follow selected account reachability');
select is((select count(id)::integer from public.sync_runs),2,'import status is scoped to selected account');
select is((select count(id)::integer from public.players),1,'catalog profiles remain readable');
select is((select count(id)::integer from public.player_external_ids),1,'canonical mappings remain readable');
select throws_ok($$select * from public.user_fantasy_accounts$$,'42501',null,'Auth-to-account links remain private');
select throws_ok($$select * from public.profiles$$,'42501',null,'Auth profiles remain private');
select throws_ok($$select * from public.fantasy_accounts$$,'42501',null,'account internals remain private');
select throws_ok($$select * from public.drafts$$,'42501',null,'draft data remains private');
select throws_ok($$update public.rosters set removed_at=now()$$,'42501',null,'anonymous roster writes fail');
select throws_ok($$update app_private.temporary_workspace_access set enabled=false$$,'42501',null,'anonymous cannot change access configuration');
reset role;

update public.fantasy_account_leagues set removed_at=now() where fantasy_account_id='12000000-0000-4000-8000-000000000001';
set local role anon;
select is((select count(id)::integer from public.leagues),0,'removing reachability hides leagues immediately');
select is((select count(id)::integer from public.rosters),0,'removing reachability hides rosters immediately');
select is((select count(id)::integer from public.roster_players),0,'removing reachability hides memberships immediately');
reset role;
update public.fantasy_account_leagues set removed_at=null where fantasy_account_id='12000000-0000-4000-8000-000000000001';
update app_private.temporary_workspace_access set enabled=false;
set local role anon;
select is((select count(*)::integer from public.get_temporary_workspace()),0,'disabling the switch removes public context');
select is((select count(id)::integer from public.leagues),0,'disabling the switch removes league access');
select is((select count(id)::integer from public.rosters),0,'disabling the switch removes roster access');
select is((select count(id)::integer from public.roster_players),0,'disabling the switch removes membership access');
select is((select count(id)::integer from public.players),0,'disabling the switch removes catalog access');
select is((select count(id)::integer from public.sync_runs),0,'disabling the switch removes import status access');
reset role;
select * from finish();
rollback;
