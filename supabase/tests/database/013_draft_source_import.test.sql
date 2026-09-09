begin;
select plan(20);
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
select * from finish();
rollback;
