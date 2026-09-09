-- Draft imports stage complete collections privately. Public publication is atomic.
create table app_private.sleeper_draft_sync_scopes (
  run_id uuid primary key references public.sync_runs(id) on delete cascade,
  external_user_id text not null,
  league_season integer not null check (league_season between 1900 and 2999),
  expected_external_league_ids text[] not null,
  check (app_private.sorted_exact_text_array_is_safe(expected_external_league_ids, 250))
);
create table app_private.sleeper_draft_sync_stage (
  run_id uuid not null references app_private.sleeper_draft_sync_scopes(run_id) on delete cascade,
  source_key text not null check (source_key = 'collections' or source_key ~ '^draft:.{1,255}$'),
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 12000000),
  primary key (run_id, source_key)
);
revoke all on app_private.sleeper_draft_sync_scopes, app_private.sleeper_draft_sync_stage from public, anon, authenticated, service_role;

create function app_private.lock_sleeper_draft_run(p_user_id uuid, p_account_id uuid, p_run_id uuid)
returns public.sync_runs language plpgsql set search_path = pg_catalog as $$
declare v_run public.sync_runs%rowtype;
begin
  perform 1 from public.fantasy_accounts a
  join public.user_fantasy_accounts u on u.fantasy_account_id = a.id
  join auth.users au on au.id = u.user_id
  where a.id = p_account_id and u.user_id = p_user_id and a.provider = 'sleeper'
  for update of a;
  if not found then raise exception using errcode = '42501', message = 'Draft import account access is required.'; end if;
  select r.* into v_run from public.sync_runs r
  where r.id = p_run_id and r.fantasy_account_id = p_account_id and r.triggered_by_user_id = p_user_id
    and r.provider = 'sleeper' and r.sport = 'nfl' and r.scope = 'draft_sync' and r.status = 'running'
  for update;
  if not found or v_run.updated_at < clock_timestamp() - interval '15 minutes' then
    raise exception using errcode = '55000', message = 'The draft import is not active.';
  end if;
  return v_run;
end;
$$;
revoke all on function app_private.lock_sleeper_draft_run(uuid,uuid,uuid) from public, anon, authenticated, service_role;

create function public.start_sleeper_draft_sync(p_user_id uuid, p_fantasy_account_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog set statement_timeout = '10s' as $$
declare
  v_user text; v_season integer; v_ids text[]; v_run public.sync_runs%rowtype; v_now timestamptz := clock_timestamp();
begin
  select a.external_user_id into v_user from public.fantasy_accounts a
  join public.user_fantasy_accounts u on u.fantasy_account_id = a.id
  join auth.users au on au.id = u.user_id
  where a.id = p_fantasy_account_id and a.provider = 'sleeper' and u.user_id = p_user_id for update of a;
  if not found then raise exception using errcode = '42501', message = 'Draft import account access is required.'; end if;
  select r.* into v_run from public.sync_runs r where r.fantasy_account_id = p_fantasy_account_id and r.scope = 'draft_sync' and r.status = 'running' for update;
  if found then
    if v_run.updated_at >= v_now - interval '15 minutes' and exists(select 1 from app_private.sleeper_draft_sync_scopes s where s.run_id = v_run.id) then
      return jsonb_build_object('runId', v_run.id, 'reused', true);
    end if;
    update public.sync_runs set status = 'failed', finished_at = v_now,
      error_summary = jsonb_build_object('code','stale_draft_sync','message','The draft import stopped before completion.','retryable',true,'stage','draft_sync') where id = v_run.id;
    delete from app_private.sleeper_draft_sync_scopes where run_id = v_run.id;
  end if;
  select league_season into v_season from public.provider_season_states where provider = 'sleeper' and sport = 'nfl';
  select array_agg(l.external_league_id order by l.external_league_id collate "C") into v_ids
  from public.fantasy_account_leagues a join public.leagues l on l.id = a.league_id
  where a.fantasy_account_id = p_fantasy_account_id and a.removed_at is null and l.provider = 'sleeper' and l.sport = 'nfl' and l.season = v_season;
  if v_season is null or cardinality(v_ids) is null or cardinality(v_ids) not between 1 and 250 then
    raise exception using errcode = '55000', message = 'Import current-season leagues before drafts.';
  end if;
  insert into public.sync_runs(fantasy_account_id,triggered_by_user_id,provider,sport,season,scope,status,progress_current,progress_total,started_at)
  values(p_fantasy_account_id,p_user_id,'sleeper','nfl',v_season,'draft_sync','running',0,0,v_now) returning * into v_run;
  insert into app_private.sleeper_draft_sync_scopes values(v_run.id,v_user,v_season,v_ids);
  return jsonb_build_object('runId',v_run.id,'reused',false,'externalUserId',v_user,'season',v_season,'externalLeagueIds',v_ids);
end;
$$;

create function public.heartbeat_sleeper_draft_sync(p_user_id uuid, p_fantasy_account_id uuid, p_sync_run_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog set statement_timeout = '10s' as $$
begin
  perform app_private.lock_sleeper_draft_run(p_user_id,p_fantasy_account_id,p_sync_run_id);
  update public.sync_runs set updated_at = clock_timestamp() where id = p_sync_run_id;
end;
$$;

create function public.stage_sleeper_draft_source(p_user_id uuid, p_fantasy_account_id uuid, p_sync_run_id uuid, p_source_key text, p_payload jsonb)
returns void language plpgsql security definer set search_path = pg_catalog set statement_timeout = '10s' as $$
declare v_old jsonb;
begin
  perform app_private.lock_sleeper_draft_run(p_user_id,p_fantasy_account_id,p_sync_run_id);
  if p_source_key is null or p_payload is null then raise exception using errcode='22023',message='A complete draft source is required.'; end if;
  select payload into v_old from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id and source_key=p_source_key;
  if found and v_old is distinct from p_payload then raise exception using errcode='22023',message='Draft source replay changed.'; end if;
  if not found then
    if (select count(*) from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id)>=1001
      or (select coalesce(sum(octet_length(payload::text)),0) from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id)+octet_length(p_payload::text)>64000000 then
      raise exception using errcode='22023',message='Draft staging exceeds the bounded collection limit.';
    end if;
    insert into app_private.sleeper_draft_sync_stage values(p_sync_run_id,p_source_key,p_payload);
    update public.sync_runs set progress_current=progress_current+1,updated_at=clock_timestamp() where id=p_sync_run_id;
  end if;
end;
$$;

create function public.fail_sleeper_draft_sync(p_user_id uuid, p_fantasy_account_id uuid, p_sync_run_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog set statement_timeout = '10s' as $$
begin
  perform app_private.lock_sleeper_draft_run(p_user_id,p_fantasy_account_id,p_sync_run_id);
  update public.sync_runs set status='failed', finished_at=clock_timestamp(),
    error_summary=jsonb_build_object('code','draft_import_failed','message','Draft import could not be completed.','retryable',true,'stage','draft_sync') where id=p_sync_run_id;
  delete from app_private.sleeper_draft_sync_scopes where run_id=p_sync_run_id;
end;
$$;

revoke all on function public.start_sleeper_draft_sync(uuid,uuid), public.heartbeat_sleeper_draft_sync(uuid,uuid,uuid), public.stage_sleeper_draft_source(uuid,uuid,uuid,text,jsonb), public.fail_sleeper_draft_sync(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.start_sleeper_draft_sync(uuid,uuid), public.heartbeat_sleeper_draft_sync(uuid,uuid,uuid), public.stage_sleeper_draft_source(uuid,uuid,uuid,text,jsonb), public.fail_sleeper_draft_sync(uuid,uuid,uuid) to service_role;

-- Structural corroboration is separate from exact draft-setting identity.
create function app_private.sleeper_draft_lineup_matches_v1(p_settings jsonb,p_positions text[],p_teams integer)
returns boolean language plpgsql immutable set search_path=pg_catalog as $$
declare
  v_map jsonb:='{"QB":"slots_qb","RB":"slots_rb","WR":"slots_wr","TE":"slots_te","K":"slots_k","DEF":"slots_def","FLEX":"slots_flex","SUPER_FLEX":"slots_super_flex","BN":"slots_bn"}'::jsonb;
  v_entry record; v_count integer;
begin
  if p_settings->'teams' is distinct from to_jsonb(p_teams) or p_positions is null then return false; end if;
  if exists(select 1 from unnest(p_positions) p where not v_map ? p)
    or exists(select 1 from jsonb_each(p_settings) s where s.key like 'slots_%' and not exists(select 1 from jsonb_each_text(v_map) m where m.value=s.key)) then return false; end if;
  for v_entry in select * from jsonb_each_text(v_map) loop
    select count(*)::integer into v_count from unnest(p_positions) p where p=v_entry.key;
    if p_settings ? v_entry.value then
      if p_settings->v_entry.value is distinct from to_jsonb(v_count) then return false; end if;
    elsif v_count>0 then return false;
    end if;
  end loop;
  return true;
end;
$$;
revoke all on function app_private.sleeper_draft_lineup_matches_v1(jsonb,text[],integer) from public,anon,authenticated,service_role;

-- This helper receives a bounded staged board, never browser-supplied identities.
create function app_private.publish_sleeper_draft_board(p_payload jsonb, p_season integer)
returns uuid language plpgsql set search_path = pg_catalog as $$
declare
  v_detail jsonb := p_payload->'detail'; v_pick jsonb; v_slot jsonb; v_id uuid;
  v_league uuid; v_old public.drafts%rowtype; v_class record; v_format record;
  v_context text := 'unknown'; v_context_id uuid; v_context_time timestamptz;
  v_fingerprint text; v_complete boolean; v_keepers boolean; v_players integer;
  v_detail_time timestamptz := (p_payload->>'detailFetchedAt')::timestamptz;
  v_board_time timestamptz := (p_payload->>'boardFetchedAt')::timestamptz;
  v_player uuid; v_mapping uuid; v_candidate uuid; v_roster uuid;
  v_teams integer := (v_detail->>'teamCount')::integer; v_rounds integer := (v_detail->>'roundCount')::integer;
  v_created timestamptz := clock_timestamp();
begin
  if jsonb_typeof(v_detail) is distinct from 'object' or jsonb_typeof(p_payload->'slots') is distinct from 'array'
    or jsonb_typeof(p_payload->'picks') is distinct from 'array' or v_detail->>'season' is distinct from p_season::text
    or v_detail->>'draftPoolType' is distinct from 'unknown'
    or v_detail_time is null or v_board_time is null or not isfinite(v_detail_time) or not isfinite(v_board_time)
    or v_board_time < v_detail_time or v_board_time > v_created + interval '1 minute'
    or jsonb_array_length(p_payload->'slots') > 1000 or jsonb_array_length(p_payload->'picks') > 10000 then
    raise exception using errcode='22023',message='Invalid complete draft source.';
  end if;
  select count(distinct p->>'externalPlayerId') into v_players from jsonb_array_elements(p_payload->'picks') p;
  if v_players <> jsonb_array_length(p_payload->'picks') or exists(
    select 1 from jsonb_array_elements(p_payload->'picks') with ordinality p(value,n)
    where (value->>'pickNo')::integer is distinct from n::integer
      or value->>'externalPlayerId' = '0'
      or jsonb_typeof(value->'isKeeper') not in ('boolean','null')
      or value->'auctionAmount' is distinct from 'null'::jsonb
      or (value->>'draftSlot')::integer > v_teams or (value->>'round')::integer > v_rounds
  ) then raise exception using errcode='22023',message='Invalid complete selection board.'; end if;
  v_complete := coalesce(v_detail->>'status'='complete' and v_teams is not null and v_rounds is not null
    and jsonb_array_length(p_payload->'picks')=v_teams*v_rounds and jsonb_array_length(p_payload->'slots')=v_teams,false);
  select coalesce(bool_or((p->>'isKeeper')::boolean is true),false) into v_keepers from jsonb_array_elements(p_payload->'picks') p;
  -- Observation times and chat activity do not define a completed selection board.
  v_fingerprint := app_private.context_sha256('fantasyhud:sleeper:draft_board',1,
    jsonb_build_object('detail',v_detail-array['lastMessageAt','lastMessageId']::text[], 'slots',p_payload->'slots','picks',p_payload->'picks'));
  select id into v_league from public.leagues where provider='sleeper' and sport='nfl' and season=p_season and external_league_id=v_detail->>'externalLeagueId';
  select * into v_old from public.drafts where provider='sleeper' and external_draft_id=v_detail->>'externalDraftId' for update;
  if found then
    if v_old.season <> p_season or v_old.league_id is distinct from v_league then
      raise exception using errcode='22023',message='A draft cannot change its canonical league or season.';
    end if;
    if v_old.board_state='finalized' then
      if v_old.board_fingerprint is distinct from v_fingerprint or not v_complete then
        raise exception using errcode='55000',message='The finalized draft source changed; correction review is required.';
      end if;
      update public.drafts set last_seen_at=greatest(last_seen_at,v_board_time),removed_at=null where id=v_old.id;
      return v_old.id;
    end if;
    if v_detail_time < v_old.draft_fetched_at or v_board_time < v_old.board_fetched_at then
      raise exception using errcode='55000',message='The draft source is older than the accepted board.';
    end if;
  end if;
  -- Use the latest accepted pre-anchor observation; never skip a conflicting newer
  -- observation to find a more convenient old format. Later evidence remains partial.
  select null::uuid as format_context_id,null::timestamptz as observed_at,null::text as format_fingerprint,null::text as compatibility_key,false as structurally_matches into v_format;
  if v_league is not null then
    select o.format_context_id,o.observed_at,f.format_fingerprint,f.compatibility_key,
      app_private.sleeper_draft_lineup_matches_v1(v_detail->'settings',f.exact_roster_positions,f.team_count) as structurally_matches into v_format
    from public.league_format_observations o join public.league_format_contexts f on f.id=o.format_context_id
    where o.league_id=v_league order by case when o.observed_at<=coalesce((v_detail->>'startTime')::timestamptz,(v_detail->>'createdAt')::timestamptz) then 0 else 1 end,o.observed_at desc limit 1;
    if found then
      v_context:=case when v_format.structurally_matches and v_format.observed_at<=coalesce((v_detail->>'startTime')::timestamptz,(v_detail->>'createdAt')::timestamptz) then 'exact' else 'partial' end;
      v_context_id:=v_format.format_context_id; v_context_time:=v_format.observed_at;
    end if;
  end if;
  select * into v_class from app_private.classify_sleeper_draft_environment_v1('sleeper','nfl',
    case when v_context in ('partial','exact') then v_format.format_fingerprint end,
    case when v_context in ('partial','exact') then v_format.compatibility_key end,v_context,v_detail->>'draftType','unknown',v_detail->'settings',v_teams,v_rounds,(v_detail->>'pickTimerSeconds')::integer);
  insert into public.drafts(provider,external_draft_id,context_type,league_id,sport,season,season_type,draft_type,draft_type_family,status,
    settings,metadata,context_resolution_status,league_format_context_id,context_observed_at,draft_environment_version,
    draft_settings_fingerprint,draft_environment_fingerprint,draft_environment_compatibility_key,draft_environment_quality,draft_pool_type,capital_type,
    team_count,round_count,pick_timer_seconds,draft_fetched_at,first_seen_at,last_seen_at)
  values('sleeper',v_detail->>'externalDraftId',case when v_league is not null then 'league' when v_detail->>'externalLeagueId' is null then 'standalone' else 'unknown' end,
    v_league,'nfl',p_season,v_detail->>'seasonType',v_detail->>'draftType',v_class.draft_type_family,v_detail->>'status',
    v_detail->'settings',v_detail->'metadata',v_context,v_context_id,v_context_time,1,v_class.draft_settings_fingerprint,
    v_class.draft_environment_fingerprint,v_class.draft_environment_compatibility_key,v_class.environment_quality,'unknown',v_class.capital_type,
    v_teams,v_rounds,(v_detail->>'pickTimerSeconds')::integer,v_detail_time,v_detail_time,v_board_time)
  on conflict on constraint drafts_provider_external_draft_id_key do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.drafts where provider='sleeper' and external_draft_id=v_detail->>'externalDraftId' for update; end if;
  update public.drafts set name=v_detail->>'name',description=v_detail->>'description',status=v_detail->>'status',
    team_count=v_teams,round_count=v_rounds,pick_timer_seconds=(v_detail->>'pickTimerSeconds')::integer,
    start_time=(v_detail->>'startTime')::timestamptz,provider_created_at=(v_detail->>'createdAt')::timestamptz,
    last_picked_at=(v_detail->>'lastPickedAt')::timestamptz,last_message_at=(v_detail->>'lastMessageAt')::timestamptz,last_message_id=v_detail->>'lastMessageId',
    source_creators=case when v_detail->'creators'='null'::jsonb then null else array(select jsonb_array_elements_text(v_detail->'creators')) end,
    source_draft_order=nullif(v_detail->'draftOrder','null'::jsonb),source_slot_to_roster_id=nullif(v_detail->'slotToRoster','null'::jsonb),
    settings=v_detail->'settings',metadata=v_detail->'metadata',league_format_context_id=v_context_id,context_resolution_status=v_context,context_observed_at=v_context_time,
    draft_settings_fingerprint=v_class.draft_settings_fingerprint,draft_environment_fingerprint=v_class.draft_environment_fingerprint,
    draft_environment_compatibility_key=v_class.draft_environment_compatibility_key,draft_environment_quality=v_class.environment_quality,
    draft_fetched_at=v_detail_time,last_seen_at=greatest(last_seen_at,v_board_time),removed_at=null
  where id=v_id;
  update public.drafts set board_state='mutable',board_fetched_at=v_board_time,board_slot_count=jsonb_array_length(p_payload->'slots'),
    board_pick_count=jsonb_array_length(p_payload->'picks'),board_fingerprint_version=1,board_fingerprint=v_fingerprint,contains_keeper_picks=v_keepers where id=v_id;
  -- Keep child identities stable; only a mutable complete collection reconciles absence.
  for v_slot in select value from jsonb_array_elements(p_payload->'slots') order by (value->>'draftSlot')::integer loop
    if v_slot->'sourceUserIds' is distinct from (case when v_detail->'draftOrder'='null'::jsonb then 'null'::jsonb else
        (select coalesce(jsonb_agg(key order by key collate "C"),'[]'::jsonb) from jsonb_each(v_detail->'draftOrder') where (value::text)::integer=(v_slot->>'draftSlot')::integer) end)
      or v_slot->'externalRosterId' is distinct from coalesce(v_detail->'slotToRoster'->(v_slot->>'draftSlot'),'null'::jsonb) then
      raise exception using errcode='22023',message='Normalized draft slots disagree with exact source maps.';
    end if;
    v_roster:=null;
    select id into v_roster from public.rosters where league_id=v_league and external_roster_id=(v_slot->>'externalRosterId')::integer;
    insert into public.draft_slots(draft_id,draft_slot,source_user_ids,external_roster_id,roster_id,fetched_at,first_seen_at,last_seen_at)
    values(v_id,(v_slot->>'draftSlot')::integer,case when v_slot->'sourceUserIds'='null'::jsonb then null else array(select jsonb_array_elements_text(v_slot->'sourceUserIds')) end,
      (v_slot->>'externalRosterId')::integer,v_roster,v_board_time,v_board_time,v_board_time)
    on conflict on constraint draft_slots_draft_slot_key do update set source_user_ids=excluded.source_user_ids,
      external_roster_id=excluded.external_roster_id,roster_id=excluded.roster_id,fetched_at=excluded.fetched_at,last_seen_at=excluded.last_seen_at,removed_at=null;
  end loop;
  for v_pick in select value from jsonb_array_elements(p_payload->'picks') order by (value->>'pickNo')::integer loop
    select id,player_id into v_mapping,v_player from public.player_external_ids where namespace='sleeper' and sport='nfl' and external_id=v_pick->>'externalPlayerId';
    if not found then
      v_candidate:=gen_random_uuid();
      insert into public.players(id,sport,entity_type,profile_source,source_metadata,profile_fetched_at)
      values(v_candidate,'nfl','unknown','sleeper',jsonb_build_object('reference_only',true,'reference_source','draft'),v_board_time);
      insert into public.player_external_ids(player_id,namespace,sport,external_id,reported_by,is_primary,source_metadata,first_seen_at,last_seen_at)
      values(v_candidate,'sleeper','nfl',v_pick->>'externalPlayerId','sleeper',true,jsonb_build_object('reference_only',true,'reference_source','draft'),v_board_time,v_board_time)
      on conflict on constraint player_external_ids_namespace_sport_external_key do nothing returning id,player_id into v_mapping,v_player;
      if not found then
        delete from public.players where id=v_candidate;
        select id,player_id into v_mapping,v_player from public.player_external_ids where namespace='sleeper' and sport='nfl' and external_id=v_pick->>'externalPlayerId';
      end if;
    end if;
    v_roster:=null;
    select id into v_roster from public.rosters where league_id=v_league and external_roster_id=(v_pick->>'externalRosterId')::integer;
    insert into public.draft_picks(draft_id,draft_slot,pick_no,round,player_id,source_player_external_id_id,picked_by_external_user_id,external_roster_id,roster_id,is_keeper,
      player_display_name_at_draft,player_entity_type_at_draft,player_primary_position_at_draft,nfl_team_at_draft,player_status_at_draft,injury_status_at_draft,
      source_player_metadata,source_metadata,source_fetched_at,first_seen_at,last_seen_at)
    values(v_id,(v_pick->>'draftSlot')::integer,(v_pick->>'pickNo')::integer,(v_pick->>'round')::integer,v_player,v_mapping,v_pick->>'pickedBy',(v_pick->>'externalRosterId')::integer,v_roster,(v_pick->>'isKeeper')::boolean,
      v_pick->>'displayName',v_pick->>'entityType',v_pick->>'position',v_pick->>'team',v_pick->>'status',v_pick->>'injuryStatus',v_pick->'metadata',v_pick->'sourceMetadata',v_board_time,v_board_time,v_board_time)
    on conflict on constraint draft_picks_draft_pick_key do update set draft_slot=excluded.draft_slot,round=excluded.round,player_id=excluded.player_id,
      source_player_external_id_id=excluded.source_player_external_id_id,picked_by_external_user_id=excluded.picked_by_external_user_id,external_roster_id=excluded.external_roster_id,
      roster_id=excluded.roster_id,is_keeper=excluded.is_keeper,player_display_name_at_draft=excluded.player_display_name_at_draft,
      player_entity_type_at_draft=excluded.player_entity_type_at_draft,player_primary_position_at_draft=excluded.player_primary_position_at_draft,
      nfl_team_at_draft=excluded.nfl_team_at_draft,player_status_at_draft=excluded.player_status_at_draft,injury_status_at_draft=excluded.injury_status_at_draft,
      source_player_metadata=excluded.source_player_metadata,source_metadata=excluded.source_metadata,source_fetched_at=excluded.source_fetched_at,last_seen_at=excluded.last_seen_at,removed_at=null;
  end loop;
  update public.draft_picks set removed_at=v_board_time where draft_id=v_id and removed_at is null and pick_no>jsonb_array_length(p_payload->'picks');
  update public.draft_slots s set removed_at=v_board_time where draft_id=v_id and removed_at is null
    and not exists(select 1 from jsonb_array_elements(p_payload->'slots') p where (p->>'draftSlot')::integer=s.draft_slot);
  update public.drafts set board_state='mutable',board_fetched_at=v_board_time,board_slot_count=jsonb_array_length(p_payload->'slots'),
    board_pick_count=jsonb_array_length(p_payload->'picks'),board_fingerprint_version=1,board_fingerprint=v_fingerprint,contains_keeper_picks=v_keepers where id=v_id;
  if v_complete then update public.drafts set board_state='finalized',board_finalized_at=v_created where id=v_id; end if;
  return v_id;
end;
$$;
revoke all on function app_private.publish_sleeper_draft_board(jsonb,integer) from public,anon,authenticated,service_role;

create function app_private.draft_collection_ids(p_ids jsonb)
returns text[] language plpgsql immutable set search_path=pg_catalog as $$
declare v_ids text[];
begin
  if jsonb_typeof(p_ids) is distinct from 'array' or jsonb_array_length(p_ids)>1000
    or exists(select 1 from jsonb_array_elements(p_ids) x where jsonb_typeof(x)<>'string') then
    raise exception using errcode='22023',message='Invalid draft collection identities.';
  end if;
  select coalesce(array_agg(x order by x collate "C"),'{}'::text[]) into v_ids from jsonb_array_elements_text(p_ids) x;
  if cardinality(v_ids)>0 and not app_private.sorted_exact_text_array_is_safe(v_ids,1000) then
    raise exception using errcode='22023',message='Invalid draft collection identities.';
  end if;
  return v_ids;
end;
$$;
revoke all on function app_private.draft_collection_ids(jsonb) from public,anon,authenticated,service_role;

create function public.complete_sleeper_draft_sync(p_user_id uuid,p_fantasy_account_id uuid,p_sync_run_id uuid)
returns jsonb language plpgsql security definer set search_path=pg_catalog set statement_timeout='60s' as $$
declare
  v_run public.sync_runs%rowtype; v_scope app_private.sleeper_draft_sync_scopes%rowtype;
  v_header jsonb; v_collection jsonb; v_stage record; v_league public.leagues%rowtype;
  v_expected text[]; v_user_ids text[]; v_league_ids text[]; v_ids text[]; v_key text;
  v_user_time timestamptz; v_time timestamptz; v_existing_time timestamptz; v_fingerprint text;
  v_draft uuid; v_slot integer; v_candidates integer[]; v_status text; v_old public.fantasy_account_drafts%rowtype;
  v_confirmed integer:=0; v_unresolved integer:=0; v_finalized integer:=0; v_negative boolean;
  v_now timestamptz:=clock_timestamp();
begin
  v_run:=app_private.lock_sleeper_draft_run(p_user_id,p_fantasy_account_id,p_sync_run_id);
  select * into strict v_scope from app_private.sleeper_draft_sync_scopes where run_id=p_sync_run_id;
  select payload into v_header from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id and source_key='collections';
  if v_header is null or v_header->>'version' is distinct from 'sleeper-draft-collection/v1'
    or v_header#>>'{scope,externalUserId}' is distinct from v_scope.external_user_id
    or v_header#>>'{scope,season}' is distinct from v_scope.league_season::text
    or app_private.draft_collection_ids(v_header#>'{scope,externalLeagueIds}') is distinct from v_scope.expected_external_league_ids
    or jsonb_typeof(v_header->'leagueCollections') is distinct from 'array' then
    raise exception using errcode='22023',message='The complete draft collection does not match the frozen scope.';
  end if;
  v_user_ids:=app_private.draft_collection_ids(v_header#>'{userCollection,externalDraftIds}');
  v_user_time:=(v_header#>>'{userCollection,sourceFetchedAt}')::timestamptz;
  if v_user_time is null or not isfinite(v_user_time) or v_user_time<v_run.started_at or v_user_time>v_now+interval '1 minute' then
    raise exception using errcode='22023',message='Invalid draft collection observation.';
  end if;
  select array_agg(x->>'externalLeagueId' order by x->>'externalLeagueId' collate "C") into v_league_ids from jsonb_array_elements(v_header->'leagueCollections') x;
  if v_league_ids is distinct from v_scope.expected_external_league_ids then
    raise exception using errcode='22023',message='The complete league set is required.';
  end if;
  v_expected:=v_user_ids;
  for v_collection in select value from jsonb_array_elements(v_header->'leagueCollections') loop
    v_ids:=app_private.draft_collection_ids(v_collection->'externalDraftIds');
    v_expected:=v_expected||v_ids;
  end loop;
  select coalesce(array_agg(distinct x collate "C" order by x collate "C"),'{}'::text[]) into v_expected from unnest(v_expected) x;
  select coalesce(array_agg(substring(source_key from 7) order by substring(source_key from 7) collate "C"),'{}'::text[])
    into v_ids from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id and source_key<>'collections';
  if v_expected is distinct from v_ids or cardinality(v_expected)>1000 then
    raise exception using errcode='22023',message='Every included draft needs a complete source bundle.';
  end if;
  -- Same lock order as roster publication, then canonical league and draft order.
  foreach v_key in array v_scope.expected_external_league_ids loop
    perform pg_advisory_xact_lock(hashtextextended('sleeper:nfl:roster-league:'||v_key,0));
  end loop;
  perform pg_advisory_xact_lock(hashtextextended('sleeper:nfl:players',0));
  perform 1 from public.leagues where provider='sleeper' and external_league_id=any(v_scope.expected_external_league_ids)
    order by external_league_id collate "C" for update;
  foreach v_key in array v_expected loop perform pg_advisory_xact_lock(hashtextextended('sleeper:nfl:draft:'||v_key,0)); end loop;
  select source_fetched_at into v_existing_time from public.fantasy_account_draft_collections
    where fantasy_account_id=p_fantasy_account_id and sport='nfl' and season=v_scope.league_season for update;
  if v_existing_time is not null and v_user_time<=v_existing_time then
    raise exception using errcode='55000',message='A newer account draft collection already exists.';
  end if;
  -- Validate every collection before public writes. A stale collection aborts the whole attempt.
  for v_collection in select value from jsonb_array_elements(v_header->'leagueCollections') order by value->>'externalLeagueId' collate "C" loop
    select * into strict v_league from public.leagues where provider='sleeper' and sport='nfl' and season=v_scope.league_season and external_league_id=v_collection->>'externalLeagueId';
    v_time:=(v_collection->>'sourceFetchedAt')::timestamptz;
    if v_time is null or not isfinite(v_time) or v_time<v_run.started_at or v_time>v_now+interval '1 minute'
      or (v_league.draft_collection_fetched_at is not null and v_time<v_league.draft_collection_fetched_at) then
      raise exception using errcode='55000',message='The league draft collection is invalid or stale.';
    end if;
    v_ids:=app_private.draft_collection_ids(v_collection->'externalDraftIds');
    if v_time=v_league.draft_collection_fetched_at and v_league.draft_collection_fingerprint is distinct from app_private.context_sha256('fantasyhud:sleeper:league_draft_collection',1,to_jsonb(v_ids)) then
      raise exception using errcode='55000',message='Equal-time draft collections disagree.';
    end if;
    if exists(select 1 from app_private.sleeper_draft_sync_stage s where s.run_id=p_sync_run_id and substring(s.source_key from 7)=any(v_ids)
      and s.payload#>>'{detail,externalLeagueId}' is distinct from v_league.external_league_id) then
      raise exception using errcode='22023',message='A source draft belongs to another league.';
    end if;
  end loop;
  for v_stage in select * from app_private.sleeper_draft_sync_stage where run_id=p_sync_run_id and source_key<>'collections' order by source_key collate "C" loop
    if v_stage.payload#>>'{detail,externalDraftId}' is distinct from substring(v_stage.source_key from 7)
      or (v_stage.payload->>'detailFetchedAt')::timestamptz<v_run.started_at then
      raise exception using errcode='22023',message='Draft source identity does not match its collection.';
    end if;
    v_draft:=app_private.publish_sleeper_draft_board(v_stage.payload,v_scope.league_season);
    -- Resolve exact provider evidence from the accepted board, never current holdings.
    select array_agg(distinct slot order by slot) into v_candidates from (
      select s.draft_slot as slot from public.draft_slots s where s.draft_id=v_draft and s.removed_at is null and v_scope.external_user_id=any(s.source_user_ids)
      union
      select s.draft_slot from public.draft_slots s
      join public.drafts d on d.id=s.draft_id
      join public.fantasy_account_rosters ar on ar.roster_id=s.roster_id and ar.fantasy_account_id=p_fantasy_account_id and ar.removed_at is null
      join public.fantasy_account_leagues al on al.league_id=d.league_id and al.fantasy_account_id=p_fantasy_account_id and al.removed_at is null and al.roster_ownership_status='owned'
      where s.draft_id=v_draft and s.removed_at is null
      union
      select p.draft_slot from public.draft_picks p where p.draft_id=v_draft and p.removed_at is null and p.picked_by_external_user_id=v_scope.external_user_id
    ) evidence;
    if coalesce(cardinality(v_candidates),0)>1 then raise exception using errcode='22023',message='Draft participation resolves to multiple seats.'; end if;
    v_slot:=null; v_status:='unresolved';
    if cardinality(v_candidates)=1 and substring(v_stage.source_key from 7)=any(v_user_ids) then
      v_slot:=v_candidates[1]; v_status:='confirmed';
      if exists(select 1 from public.draft_slots s where s.draft_id=v_draft and s.draft_slot=v_slot
        and cardinality(s.source_user_ids)>0 and not v_scope.external_user_id=any(s.source_user_ids)) then
        v_slot:=null; v_status:='unresolved';
      end if;
    elsif coalesce(cardinality(v_candidates),0)=0 and not substring(v_stage.source_key from 7)=any(v_user_ids) then
      select d.board_state='finalized' and d.source_draft_order is not null
        and not exists(select 1 from public.draft_slots s where s.draft_id=d.id and s.removed_at is null and coalesce(cardinality(s.source_user_ids),0)=0)
      into v_negative from public.drafts d where id=v_draft;
      if v_negative then v_status:='not_participant'; end if;
    end if;
    v_time:=greatest(v_user_time,(v_stage.payload->>'boardFetchedAt')::timestamptz);
    select * into v_old from public.fantasy_account_drafts where fantasy_account_id=p_fantasy_account_id and draft_id=v_draft;
    if found and v_old.observed_at>v_time then raise exception using errcode='55000',message='Newer participation evidence already exists.'; end if;
    insert into public.fantasy_account_drafts(fantasy_account_id,draft_id,participation_status,draft_slot,source_metadata,observed_at,first_seen_at,last_seen_at)
    values(p_fantasy_account_id,v_draft,v_status,v_slot,jsonb_build_object('user_collection_included',substring(v_stage.source_key from 7)=any(v_user_ids),'resolver','exact-provider-evidence/v1'),v_time,v_time,v_time)
    on conflict on constraint fantasy_account_drafts_account_draft_key do update set participation_status=excluded.participation_status,draft_slot=excluded.draft_slot,
      source_metadata=excluded.source_metadata,observed_at=excluded.observed_at,last_seen_at=greatest(public.fantasy_account_drafts.last_seen_at,excluded.last_seen_at),removed_at=null;
    if v_status='confirmed' then v_confirmed:=v_confirmed+1; elsif v_status='unresolved' then v_unresolved:=v_unresolved+1; end if;
    if exists(select 1 from public.drafts where id=v_draft and board_state='finalized') then v_finalized:=v_finalized+1; end if;
  end loop;
  for v_collection in select value from jsonb_array_elements(v_header->'leagueCollections') order by value->>'externalLeagueId' collate "C" loop
    v_ids:=app_private.draft_collection_ids(v_collection->'externalDraftIds'); v_time:=(v_collection->>'sourceFetchedAt')::timestamptz;
    v_fingerprint:=app_private.context_sha256('fantasyhud:sleeper:league_draft_collection',1,to_jsonb(v_ids));
    update public.leagues set draft_collection_fetched_at=v_time,draft_collection_count=cardinality(v_ids),draft_collection_fingerprint=v_fingerprint
      where provider='sleeper' and external_league_id=v_collection->>'externalLeagueId' returning id into v_league.id;
    update public.drafts set removed_at=greatest(last_seen_at,v_time) where league_id=v_league.id and removed_at is null and not external_draft_id=any(v_ids);
  end loop;
  insert into public.fantasy_account_draft_collections(fantasy_account_id,sport,season,source_fetched_at,source_draft_count,collection_fingerprint,source_metadata)
    values(p_fantasy_account_id,'nfl',v_scope.league_season,v_user_time,cardinality(v_user_ids),app_private.context_sha256('fantasyhud:sleeper:account_draft_collection',1,to_jsonb(v_user_ids)),jsonb_build_object('version',1))
    on conflict on constraint fantasy_account_draft_collections_pkey do update set source_fetched_at=excluded.source_fetched_at,source_draft_count=excluded.source_draft_count,collection_fingerprint=excluded.collection_fingerprint,source_metadata=excluded.source_metadata;
  update public.fantasy_account_drafts a set removed_at=greatest(a.last_seen_at,v_user_time)
    from public.drafts d where a.fantasy_account_id=p_fantasy_account_id and a.draft_id=d.id and d.season=v_scope.league_season and a.removed_at is null
    and not d.external_draft_id=any(v_expected) and not(d.board_state='finalized' and a.participation_status='confirmed');
  update public.sync_runs set status=case when v_unresolved>0 then 'partial' else 'succeeded' end,finished_at=clock_timestamp(),
    result_counts=jsonb_build_object('drafts',cardinality(v_expected),'finalized_boards',v_finalized,'confirmed_participations',v_confirmed,'unresolved_participations',v_unresolved),
    progress_current=cardinality(v_expected)+1,progress_total=cardinality(v_expected)+1 where id=p_sync_run_id;
  delete from app_private.sleeper_draft_sync_scopes where run_id=p_sync_run_id;
  return jsonb_build_object('drafts',cardinality(v_expected),'finalizedBoards',v_finalized,'confirmedParticipations',v_confirmed,'unresolvedParticipations',v_unresolved);
end;
$$;
revoke all on function public.complete_sleeper_draft_sync(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.complete_sleeper_draft_sync(uuid,uuid,uuid) to service_role;
