begin;
select plan(32);
select ok(has_function_privilege('service_role','public.start_sleeper_draft_sync(uuid,uuid)','execute'),'trusted service can start draft imports');
select ok(not has_function_privilege('anon','public.start_sleeper_draft_sync(uuid,uuid)','execute'),'anonymous callers cannot start imports');
select ok(not has_function_privilege('authenticated','public.complete_sleeper_draft_sync(uuid,uuid,uuid)','execute'),'browser roles cannot publish sources');
select ok(not has_table_privilege('service_role','public.drafts','INSERT'),'no direct service draft writes');
select ok(not has_table_privilege('anon','app_private.sleeper_draft_sync_stage','SELECT'),'staging remains private');
select throws_ok($$select public.start_sleeper_draft_sync(gen_random_uuid(),gen_random_uuid())$$,'42501','Draft import account access is required.','unlinked users cannot start imports');
select is(app_private.draft_collection_ids('["b","a"]'::jsonb),array['a','b'],'collection identities sort deterministically');
select throws_ok($$select app_private.draft_collection_ids('["a","a"]'::jsonb)$$,'22023','Invalid draft collection identities.','duplicate collections fail closed');
select throws_ok($$select app_private.draft_collection_ids('null'::jsonb)$$,'22023','Invalid draft collection identities.','source null is not empty');
select is(app_private.draft_collection_ids('[]'::jsonb),'{}'::text[],'explicit empty collection is valid');

create temporary table source_fixture(payload jsonb);
insert into source_fixture values(jsonb_build_object(
  'detailFetchedAt',clock_timestamp(),'boardFetchedAt',clock_timestamp(),
  'detail',jsonb_build_object('externalDraftId','import-test-board','externalLeagueId',null,'season',2026,'seasonType','regular','draftType','snake','status','complete',
    'teamCount',2,'roundCount',1,'pickTimerSeconds',120,'settings',jsonb_build_object('teams',2,'rounds',1,'pick_timer',120),
    'metadata','{}'::jsonb,'draftPoolType','unknown','draftOrder',jsonb_build_object('source-a',1,'source-b',2),'slotToRoster',null,'creators',null),
  'slots',jsonb_build_array(jsonb_build_object('draftSlot',1,'sourceUserIds',jsonb_build_array('source-a'),'externalRosterId',null),jsonb_build_object('draftSlot',2,'sourceUserIds',jsonb_build_array('source-b'),'externalRosterId',null)),
  'picks',(select jsonb_agg(jsonb_build_object('pickNo',n,'round',1,'draftSlot',n,'externalPlayerId','draft-import-player-'||n,'pickedBy','source-'||case when n=1 then 'a' else 'b' end,
    'isKeeper',null,'auctionAmount',null,'entityType','player','position','RB','metadata','{}'::jsonb,'sourceMetadata','{}'::jsonb) order by n) from generate_series(1,2) n)
));
select lives_ok($$select app_private.publish_sleeper_draft_board(payload,2026) from source_fixture$$,'complete source publishes every pick');
select is((select count(*)::integer from public.draft_picks p join public.drafts d on d.id=p.draft_id where d.external_draft_id='import-test-board'),2,'both seats are persisted');
select is((select board_state from public.drafts where external_draft_id='import-test-board'),'finalized','complete board finalizes');
select is((select count(*)::integer from public.draft_picks p join public.drafts d on d.id=p.draft_id where d.external_draft_id='import-test-board' and p.is_keeper is null),2,'keeper unknown remains null');
select is((select draft_environment_quality from public.drafts where external_draft_id='import-test-board'),'unknown','missing historical context remains unknown');
select lives_ok($$select app_private.publish_sleeper_draft_board(payload,2026) from source_fixture$$,'identical finalized replay is idempotent');
select throws_ok($$select app_private.publish_sleeper_draft_board(jsonb_set(payload,'{picks,0,position}','"WR"'),2026) from source_fixture$$,'55000','The finalized draft source changed; correction review is required.','changed finalized source fails closed');
select throws_ok($$select app_private.publish_sleeper_draft_board(jsonb_set(payload,'{picks,0,externalPlayerId}','"0"'),2026) from source_fixture$$,'22023','Invalid complete selection board.','placeholders never create players');
select is((select count(*)::integer from public.player_external_ids where namespace='sleeper' and external_id like 'draft-import-player-%'),2,'exact sparse mappings are reused');
select ok(not exists(select 1 from public.fantasy_accounts where last_synced_at is not null),'draft import never sets the portfolio watermark');


create temporary table import_actor as select gen_random_uuid() as user_id,gen_random_uuid() as account_id,gen_random_uuid() as league_id;
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select user_id,'authenticated','authenticated','draft-source-import@example.test','{}'::jsonb,'{}'::jsonb,clock_timestamp(),clock_timestamp() from import_actor;
insert into public.fantasy_accounts(id,provider,external_user_id,username,normalized_username)
select account_id,'sleeper','source-a','draft_source_import','draft_source_import' from import_actor;
insert into public.user_fantasy_accounts(user_id,fantasy_account_id,is_primary) select user_id,account_id,true from import_actor;
insert into public.provider_season_states(provider,sport,season,league_season,season_type,fetched_at)
values('sleeper','nfl',2026,2026,'regular',clock_timestamp()) on conflict(provider,sport) do update set league_season=2026;
insert into public.leagues(id,provider,external_league_id,sport,season,name,status,season_type,team_count,roster_size,roster_management_type,is_best_ball,has_superflex,has_idp,scoring_format,settings,scoring_settings,roster_positions,fetched_at)
select league_id,'sleeper','import-test-league','nfl',2026,'Import test','in_season','regular',2,1,'redraft',false,false,false,'ppr','{}'::jsonb,'{"rec":1}'::jsonb,'["RB"]'::jsonb,clock_timestamp() from import_actor;
insert into public.fantasy_account_leagues(fantasy_account_id,league_id,first_seen_at,last_seen_at) select account_id,league_id,clock_timestamp(),clock_timestamp() from import_actor;
create temporary table import_run as select public.start_sleeper_draft_sync(user_id,account_id) as result from import_actor;
select is((select result->>'season' from import_run),'2026','start freezes the provider league season');
select is((select public.start_sleeper_draft_sync(user_id,account_id)->>'reused' from import_actor),'true','a live run is reused without duplicate work');
update source_fixture set payload=jsonb_set(jsonb_set(payload,'{detailFetchedAt}',to_jsonb(clock_timestamp())),'{boardFetchedAt}',to_jsonb(clock_timestamp()));
create temporary table collection_fixture as select jsonb_build_object('version','sleeper-draft-collection/v1',
  'scope',jsonb_build_object('externalUserId','source-a','season',2026,'externalLeagueIds',jsonb_build_array('import-test-league')),
  'userCollection',jsonb_build_object('externalDraftIds',jsonb_build_array('import-test-board'),'sourceFetchedAt',clock_timestamp()),
  'leagueCollections',jsonb_build_array(jsonb_build_object('externalLeagueId','import-test-league','externalDraftIds','[]'::jsonb,'sourceFetchedAt',clock_timestamp()))) as payload;
select public.stage_sleeper_draft_source(a.user_id,a.account_id,(r.result->>'runId')::uuid,'collections',c.payload) from import_actor a,import_run r,collection_fixture c;
select is((select count(*)::integer from app_private.sleeper_draft_sync_stage),1,'collections stage privately');
select throws_ok($$select public.stage_sleeper_draft_source(a.user_id,a.account_id,(r.result->>'runId')::uuid,'collections','{}'::jsonb) from import_actor a,import_run r$$,'22023','Draft source replay changed.','changed staged replay is rejected');
select public.stage_sleeper_draft_source(a.user_id,a.account_id,(r.result->>'runId')::uuid,'draft:import-test-board',s.payload) from import_actor a,import_run r,source_fixture s;
select lives_ok($$select public.complete_sleeper_draft_sync(a.user_id,a.account_id,(r.result->>'runId')::uuid) from import_actor a,import_run r$$,'the complete scoped collection publishes atomically');
select is((select status from public.sync_runs where id=(select (result->>'runId')::uuid from import_run)),'succeeded','successful collection closes its run');
select is((select source_draft_count from public.fantasy_account_draft_collections where fantasy_account_id=(select account_id from import_actor)),1,'account collection records the exact source count');
select is((select draft_slot from public.fantasy_account_drafts where fantasy_account_id=(select account_id from import_actor)),1,'exact provider evidence confirms one seat');
select is((select count(*)::integer from app_private.sleeper_draft_sync_stage),0,'terminal success cleans private stages');
select ok((select last_synced_at is null from public.fantasy_accounts where id=(select account_id from import_actor)),'successful drafts do not claim complete portfolio sync');
select throws_ok($$select public.heartbeat_sleeper_draft_sync(a.user_id,a.account_id,(r.result->>'runId')::uuid) from import_actor a,import_run r$$,'55000','The draft import is not active.','completed attempts cannot be revived by a heartbeat');
create temporary table failed_run as select public.start_sleeper_draft_sync(user_id,account_id) as result from import_actor;
select public.fail_sleeper_draft_sync(a.user_id,a.account_id,(r.result->>'runId')::uuid) from import_actor a,failed_run r;
select is((select status from public.sync_runs where id=(select (result->>'runId')::uuid from failed_run)),'failed','failed attempts retain terminal history');
select * from finish();
rollback;
