-- Task 008A.1 introduces immutable, versioned scoring and league-format
-- contexts. Exact provider source remains on leagues and is copied into these
-- owner-maintained contexts; broad labels are routing aids, never identity.

create extension if not exists pgcrypto with schema extensions;

create or replace function app_private.context_sha256(
  p_namespace text,
  p_version integer,
  p_value jsonb
)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
begin
  if p_namespace is null
    or p_namespace <> pg_catalog.btrim(p_namespace)
    or pg_catalog.char_length(p_namespace) not between 1 and 128
    or p_namespace ~ '[[:cntrl:]]'
    or p_version is null
    or p_version not between 1 and 1000000
    or p_value is null
    or pg_catalog.jsonb_typeof(p_value) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_value::text, 'UTF8')
    ) > 131072
  then
    raise exception using
      errcode = '22023',
      message = 'The context fingerprint input is invalid.';
  end if;

  return pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'namespace', p_namespace,
          'version', p_version,
          'value', p_value
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
end;
$$;

create or replace function app_private.context_text_array_sha256(
  p_namespace text,
  p_version integer,
  p_values text[]
)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
begin
  if p_namespace is null
    or p_namespace <> pg_catalog.btrim(p_namespace)
    or pg_catalog.char_length(p_namespace) not between 1 and 128
    or p_namespace ~ '[[:cntrl:]]'
    or p_version is null
    or p_version not between 1 and 1000000
    or p_values is null
    or coalesce(pg_catalog.array_ndims(p_values), 1) <> 1
    or pg_catalog.cardinality(p_values) > 1000
    or exists (
      select 1
      from pg_catalog.unnest(p_values) as item(value)
      where item.value is null
        or item.value <> pg_catalog.btrim(item.value)
        or pg_catalog.char_length(item.value) not between 1 and 255
        or item.value ~ '[[:cntrl:]]'
    )
  then
    raise exception using
      errcode = '22023',
      message = 'The context array fingerprint input is invalid.';
  end if;

  return app_private.context_sha256(
    p_namespace,
    p_version,
    pg_catalog.jsonb_build_object('ordered_values', p_values)
  );
end;
$$;

create or replace function app_private.league_format_fingerprint(
  p_version integer,
  p_provider text,
  p_sport text,
  p_scoring_fingerprint text,
  p_league_settings_fingerprint text,
  p_roster_positions text[],
  p_team_count integer,
  p_roster_size integer,
  p_roster_management_type text,
  p_is_best_ball boolean,
  p_has_superflex boolean,
  p_has_idp boolean
)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
begin
  if p_version is null
    or p_version not between 1 and 1000000
    or p_provider is null
    or p_provider !~ '^[a-z][a-z0-9_-]{0,31}$'
    or p_sport is null
    or p_sport !~ '^[a-z][a-z0-9_-]{0,31}$'
    or p_scoring_fingerprint is null
    or p_scoring_fingerprint !~ '^[0-9a-f]{64}$'
    or p_league_settings_fingerprint is null
    or p_league_settings_fingerprint !~ '^[0-9a-f]{64}$'
    or p_roster_positions is null
    or coalesce(pg_catalog.array_ndims(p_roster_positions), 1) <> 1
    or pg_catalog.cardinality(p_roster_positions) > 1000
    or exists (
      select 1
      from pg_catalog.unnest(p_roster_positions) as position(value)
      where position.value is null
        or position.value !~ '^[A-Z0-9_]{1,64}$'
    )
    or p_team_count is null
    or p_team_count not between 1 and 1000
    or p_roster_size is null
    or p_roster_size not between 0 and 1000
    or p_roster_size <> pg_catalog.cardinality(p_roster_positions)
    or p_roster_management_type is null
    or p_roster_management_type not in (
      'redraft', 'keeper', 'dynasty', 'unknown'
    )
    or p_is_best_ball is null
    or p_has_superflex is null
    or p_has_idp is null
  then
    raise exception using
      errcode = '22023',
      message = 'The league format fingerprint input is invalid.';
  end if;

  return app_private.context_sha256(
    'league_format:' || p_provider || ':' || p_sport,
    p_version,
    pg_catalog.jsonb_build_object(
      'scoring_fingerprint', p_scoring_fingerprint,
      'league_settings_fingerprint', p_league_settings_fingerprint,
      'roster_positions', p_roster_positions,
      'team_count', p_team_count,
      'roster_size', p_roster_size,
      'roster_management_type', p_roster_management_type,
      'is_best_ball', p_is_best_ball,
      'has_superflex', p_has_superflex,
      'has_idp', p_has_idp
    )
  );
end;
$$;

create or replace function app_private.exact_roster_positions_are_safe(
  p_values text[]
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
    p_values is not null
    and coalesce(pg_catalog.array_ndims(p_values), 1) = 1
    and pg_catalog.cardinality(p_values) <= 1000
    and not exists (
      select 1
      from pg_catalog.unnest(p_values) as item(value)
      where item.value is null
        or item.value !~ '^[A-Z0-9_]{1,64}$'
    ),
    false
  );
$$;

create or replace function app_private.sleeper_effective_scoring_v1(
  p_scoring_settings jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_effective_scoring jsonb;
begin
  if p_scoring_settings is null
    or pg_catalog.jsonb_typeof(p_scoring_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_scoring_settings::text, 'UTF8')
    ) > 131072
  then
    raise exception using
      errcode = '22023',
      message = 'The Sleeper scoring settings are invalid.';
  end if;

  -- Version one removes only two reviewed semantic no-op families:
  -- zero-valued keys in the explicit audited additive-bonus allowlist below,
  -- and exact rec_{position} values that equal the numeric base rec value.
  -- Every other key and exact JSON value, including a future bonus_* key or
  -- unknown or malformed input, remains in the effective object.
  select coalesce(
    pg_catalog.jsonb_object_agg(
      setting.key,
      setting.value
      order by setting.key collate "C"
    ),
    '{}'::jsonb
  )
  into v_effective_scoring
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where not (
      setting.key in (
        'bonus_def_fum_td_50p',
        'bonus_def_int_td_50p',
        'bonus_fd_qb',
        'bonus_fd_rb',
        'bonus_fd_te',
        'bonus_fd_wr',
        'bonus_pass_cmp_25',
        'bonus_pass_yd_300',
        'bonus_pass_yd_400',
        'bonus_rec_rb',
        'bonus_rec_te',
        'bonus_rec_wr',
        'bonus_rec_yd_100',
        'bonus_rec_yd_200',
        'bonus_rush_att_20',
        'bonus_rush_rec_yd_100',
        'bonus_rush_rec_yd_200',
        'bonus_rush_td_qb',
        'bonus_rush_yd_100',
        'bonus_rush_yd_200',
        'bonus_sack_2p',
        'bonus_tkl_10p'
      )
      and case
        when pg_catalog.jsonb_typeof(setting.value) = 'number'
          then (setting.value #>> '{}')::numeric = 0
        else false
      end
    )
    and not (
      setting.key ~ '^rec_(fb|qb|rb|te|wr)$'
      and case
        when pg_catalog.jsonb_typeof(setting.value) = 'number'
          and pg_catalog.jsonb_typeof(p_scoring_settings -> 'rec') = 'number'
        then (setting.value #>> '{}')::numeric =
          (p_scoring_settings ->> 'rec')::numeric
        else false
      end
    );

  return v_effective_scoring;
end;
$$;

create or replace function app_private.lineup_profile_is_safe(
  p_profile jsonb
)
returns boolean
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_item record;
  v_count numeric;
  v_total numeric := 0;
begin
  if p_profile is null
    or pg_catalog.jsonb_typeof(p_profile) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_profile::text, 'UTF8')
    ) > 131072
  then
    return false;
  end if;

  for v_item in
    select setting.key, setting.value
    from pg_catalog.jsonb_each(p_profile) as setting(key, value)
  loop
    if v_item.key !~ '^[A-Z0-9_]{1,64}$'
      or pg_catalog.jsonb_typeof(v_item.value) <> 'number'
    then
      return false;
    end if;

    v_count := (v_item.value #>> '{}')::numeric;
    if v_count <> pg_catalog.trunc(v_count)
      or v_count not between 1 and 1000
    then
      return false;
    end if;
    v_total := v_total + v_count;
  end loop;

  return v_total <= 1000;
end;
$$;

revoke all on function app_private.context_sha256(text, integer, jsonb)
from public, anon, authenticated, service_role;
revoke all on function app_private.context_text_array_sha256(
  text,
  integer,
  text[]
) from public, anon, authenticated, service_role;
revoke all on function app_private.league_format_fingerprint(
  integer,
  text,
  text,
  text,
  text,
  text[],
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) from public, anon, authenticated, service_role;
revoke all on function app_private.exact_roster_positions_are_safe(text[])
from public, anon, authenticated, service_role;
revoke all on function app_private.sleeper_effective_scoring_v1(jsonb)
from public, anon, authenticated, service_role;
revoke all on function app_private.lineup_profile_is_safe(jsonb)
from public, anon, authenticated, service_role;

comment on function app_private.context_sha256(text, integer, jsonb) is
  'Owner-only immutable SHA-256 helper over canonical JSON context identity.';
comment on function app_private.context_text_array_sha256(
  text,
  integer,
  text[]
) is
  'Owner-only immutable SHA-256 helper that preserves exact text-array order.';
comment on function app_private.league_format_fingerprint(
  integer,
  text,
  text,
  text,
  text,
  text[],
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) is
  'Owner-only immutable fingerprint over every exact league-format identity dimension.';
comment on function app_private.sleeper_effective_scoring_v1(jsonb) is
  'Owner-only immutable version-one semantic scoring projection. It removes only reviewed no-ops and conservatively retains every other exact key/value.';
comment on function app_private.lineup_profile_is_safe(jsonb) is
  'Owner-only immutable validation for bounded canonical slot-count profiles.';

create table public.scoring_contexts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  sport text not null,
  normalization_version integer not null,
  scoring_fingerprint text not null,
  exact_scoring_settings jsonb not null,
  broad_scoring_format text not null,
  reception_points numeric,
  passing_touchdown_points numeric,
  tight_end_reception_bonus numeric,
  has_position_specific_reception boolean not null,
  has_bonus_scoring boolean not null,
  has_idp_scoring boolean not null,
  compatibility_key text not null,
  derived_dimensions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint scoring_contexts_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint scoring_contexts_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint scoring_contexts_version_is_bounded check (
    normalization_version between 1 and 1000000
  ),
  constraint scoring_contexts_fingerprint_is_sha256 check (
    scoring_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  constraint scoring_contexts_exact_settings_are_bounded_object check (
    pg_catalog.jsonb_typeof(exact_scoring_settings) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(exact_scoring_settings::text, 'UTF8')
    ) <= 131072
  ),
  constraint scoring_contexts_fingerprint_matches_exact_settings check (
    scoring_fingerprint = app_private.context_sha256(
      'scoring_context:' || provider || ':' || sport,
      normalization_version,
      exact_scoring_settings
    )
  ),
  constraint scoring_contexts_broad_format_is_known check (
    broad_scoring_format in (
      'ppr', 'half_ppr', 'standard', 'custom', 'unknown'
    )
  ),
  constraint scoring_contexts_dimensions_are_bounded check (
    (reception_points is null or pg_catalog.abs(reception_points) <= 1000000)
    and (
      passing_touchdown_points is null
      or pg_catalog.abs(passing_touchdown_points) <= 1000000
    )
    and (
      tight_end_reception_bonus is null
      or pg_catalog.abs(tight_end_reception_bonus) <= 1000000
    )
  ),
  constraint scoring_contexts_compatibility_key_is_safe check (
    compatibility_key = pg_catalog.btrim(compatibility_key)
    and pg_catalog.char_length(compatibility_key) between 1 and 255
    and compatibility_key !~ '[[:cntrl:]]'
  ),
  constraint scoring_contexts_derived_dimensions_are_bounded_object check (
    pg_catalog.jsonb_typeof(derived_dimensions) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(derived_dimensions::text, 'UTF8')
    ) <= 32768
  ),
  constraint scoring_contexts_created_at_is_finite check (
    pg_catalog.isfinite(created_at)
  ),
  constraint scoring_contexts_provider_sport_version_fingerprint_key unique (
    provider,
    sport,
    normalization_version,
    scoring_fingerprint
  )
);

comment on table public.scoring_contexts is
  'One immutable exact provider scoring-rules context for one normalization version.';
comment on column public.scoring_contexts.exact_scoring_settings is
  'Exact provider scoring settings; excluded from context-table browser grants.';
comment on column public.scoring_contexts.compatibility_key is
  'Provider-neutral FANTASY HUD semantic scoring key for explicit compatibility routing; never exact provider scoring identity.';

create index scoring_contexts_broad_format_idx
  on public.scoring_contexts (provider, sport, broad_scoring_format);
create index scoring_contexts_compatibility_key_idx
  on public.scoring_contexts (
    provider,
    sport,
    normalization_version,
    compatibility_key
  );

create table public.league_format_contexts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  sport text not null,
  normalization_version integer not null,
  scoring_context_id uuid not null
    references public.scoring_contexts(id) on delete restrict,
  format_fingerprint text not null,
  league_settings_fingerprint text not null,
  lineup_fingerprint text not null,
  lineup_profile_fingerprint text not null,
  lineup_profile jsonb not null,
  exact_roster_positions text[] not null,
  exact_league_settings jsonb not null,
  team_count integer not null,
  roster_size integer not null,
  roster_management_type text not null,
  is_best_ball boolean not null,
  has_superflex boolean not null,
  has_idp boolean not null,
  quarterback_format text not null,
  compatibility_key text not null,
  context_quality text not null,
  derived_dimensions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint league_format_contexts_provider_is_safe check (
    provider ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint league_format_contexts_sport_is_safe check (
    sport ~ '^[a-z][a-z0-9_-]{0,31}$'
  ),
  constraint league_format_contexts_version_is_bounded check (
    normalization_version between 1 and 1000000
  ),
  constraint league_format_contexts_fingerprints_are_sha256 check (
    format_fingerprint ~ '^[0-9a-f]{64}$'
    and league_settings_fingerprint ~ '^[0-9a-f]{64}$'
    and lineup_fingerprint ~ '^[0-9a-f]{64}$'
    and lineup_profile_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  constraint league_format_contexts_roster_positions_are_safe check (
    app_private.exact_roster_positions_are_safe(exact_roster_positions)
  ),
  constraint league_format_contexts_lineup_fingerprint_matches check (
    lineup_fingerprint = app_private.context_text_array_sha256(
      'lineup:' || provider || ':' || sport,
      normalization_version,
      exact_roster_positions
    )
  ),
  constraint league_format_contexts_exact_settings_are_bounded_object check (
    pg_catalog.jsonb_typeof(exact_league_settings) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(exact_league_settings::text, 'UTF8')
    ) <= 131072
  ),
  constraint league_format_contexts_settings_fingerprint_matches check (
    league_settings_fingerprint = app_private.context_sha256(
      'league_settings:' || provider || ':' || sport,
      normalization_version,
      exact_league_settings
    )
  ),
  constraint league_format_contexts_lineup_profile_is_bounded_object check (
    app_private.lineup_profile_is_safe(lineup_profile)
  ),
  constraint league_format_contexts_lineup_profile_fingerprint_matches check (
    lineup_profile_fingerprint = app_private.context_sha256(
      'fantasyhud:' || sport || ':lineup_profile',
      normalization_version,
      lineup_profile
    )
  ),
  constraint league_format_contexts_counts_are_consistent check (
    team_count between 1 and 1000
    and roster_size between 0 and 1000
    and roster_size = pg_catalog.cardinality(exact_roster_positions)
  ),
  constraint league_format_contexts_management_is_known check (
    roster_management_type in ('redraft', 'keeper', 'dynasty', 'unknown')
  ),
  constraint league_format_contexts_quarterback_format_is_known check (
    quarterback_format in (
      'one_qb',
      'superflex',
      'two_qb',
      'two_qb_superflex',
      'no_qb',
      'custom',
      'unknown'
    )
  ),
  constraint league_format_contexts_compatibility_key_is_safe check (
    compatibility_key = pg_catalog.btrim(compatibility_key)
    and pg_catalog.char_length(compatibility_key) between 1 and 255
    and compatibility_key !~ '[[:cntrl:]]'
  ),
  constraint league_format_contexts_quality_is_known check (
    context_quality in ('exact', 'partial', 'unknown')
  ),
  constraint league_format_contexts_derived_dimensions_are_bounded_object check (
    pg_catalog.jsonb_typeof(derived_dimensions) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(derived_dimensions::text, 'UTF8')
    ) <= 32768
  ),
  constraint league_format_contexts_created_at_is_finite check (
    pg_catalog.isfinite(created_at)
  ),
  constraint league_format_contexts_provider_sport_version_fingerprint_key unique (
    provider,
    sport,
    normalization_version,
    format_fingerprint
  )
);

comment on table public.league_format_contexts is
  'One immutable exact league-level draft-relevant format for one normalization version.';
comment on column public.league_format_contexts.exact_roster_positions is
  'Exact ordered provider roster positions; excluded from context-table browser grants.';
comment on column public.league_format_contexts.exact_league_settings is
  'Exact provider league settings, distinct from scoring rules and excluded from context-table browser grants.';
comment on column public.league_format_contexts.league_settings_fingerprint is
  'Provider-specific exact league-settings identity included in the exact format fingerprint.';
comment on column public.league_format_contexts.lineup_profile is
  'Provider-neutral order-independent exact slot-count profile; excluded from context-table browser grants.';
comment on column public.league_format_contexts.lineup_profile_fingerprint is
  'Provider-neutral versioned identity for count-sensitive lineup compatibility.';
comment on column public.league_format_contexts.quarterback_format is
  'Versioned quarterback topology independent from the has_idp dimension.';
comment on column public.league_format_contexts.compatibility_key is
  'Provider-neutral semantic format key over scoring, full lineup composition, league dimensions, reviewed settings, and conservative unknown fallback.';

create index league_format_contexts_scoring_context_idx
  on public.league_format_contexts (scoring_context_id);
create index league_format_contexts_compatibility_key_idx
  on public.league_format_contexts (
    provider,
    sport,
    normalization_version,
    compatibility_key
  );
create index league_format_contexts_dimensions_idx
  on public.league_format_contexts (
    team_count,
    is_best_ball,
    quarterback_format,
    has_superflex,
    has_idp
  );

alter table public.leagues
add column current_format_context_id uuid
references public.league_format_contexts(id) on delete restrict;

comment on column public.leagues.current_format_context_id is
  'Immutable format context for the latest accepted current league representation.';

create index leagues_current_format_context_idx
  on public.leagues (current_format_context_id)
  where current_format_context_id is not null;

create table public.league_format_observations (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  format_context_id uuid not null
    references public.league_format_contexts(id) on delete restrict,
  observed_at timestamptz not null,
  source text not null,
  normalization_version integer not null,
  created_at timestamptz not null default now(),
  constraint league_format_observations_source_is_known check (
    source in ('league_discovery', 'migration_backfill')
  ),
  constraint league_format_observations_version_is_bounded check (
    normalization_version between 1 and 1000000
  ),
  constraint league_format_observations_timestamps_are_finite check (
    pg_catalog.isfinite(observed_at)
    and pg_catalog.isfinite(created_at)
  ),
  constraint league_format_observations_league_time_key unique (
    league_id,
    observed_at
  )
);

comment on table public.league_format_observations is
  'Append-only accepted league-format observations with at most one context per league and source observation time. Exact same-context/version replay is idempotent; conflict fails closed.';

create index league_format_observations_league_observed_idx
  on public.league_format_observations (league_id, observed_at desc);
create index league_format_observations_context_observed_idx
  on public.league_format_observations (format_context_id, observed_at desc);

create or replace function app_private.classify_sleeper_scoring_settings(
  p_scoring_settings jsonb
)
returns table (
  broad_scoring_format text,
  reception_points numeric,
  passing_touchdown_points numeric,
  tight_end_reception_bonus numeric,
  has_position_specific_reception boolean,
  has_bonus_scoring boolean,
  has_idp_scoring boolean,
  compatibility_key text,
  derived_dimensions jsonb
)
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  -- This is the complete key union from the controlled 30-league audit, plus
  -- reviewed plain pass_def and FB/QB/RB/TE/WR position-reception variants
  -- that were absent from that snapshot. It is deliberately explicit: a
  -- future key, including one under a familiar prefix, remains material and
  -- is diagnosed as unknown until a later normalization version reviews it.
  v_reviewed_scoring_keys constant text[] := array[
    'blk_kick',
    'blk_kick_ret_yd',
    'bonus_def_fum_td_50p',
    'bonus_def_int_td_50p',
    'bonus_fd_qb',
    'bonus_fd_rb',
    'bonus_fd_te',
    'bonus_fd_wr',
    'bonus_pass_cmp_25',
    'bonus_pass_yd_300',
    'bonus_pass_yd_400',
    'bonus_rec_fb',
    'bonus_rec_qb',
    'bonus_rec_rb',
    'bonus_rec_te',
    'bonus_rec_wr',
    'bonus_rec_yd_100',
    'bonus_rec_yd_200',
    'bonus_rush_att_20',
    'bonus_rush_rec_yd_100',
    'bonus_rush_rec_yd_200',
    'bonus_rush_td_qb',
    'bonus_rush_yd_100',
    'bonus_rush_yd_200',
    'bonus_sack_2p',
    'bonus_tkl_10p',
    'def_2pt',
    'def_3_and_out',
    'def_4_and_stop',
    'def_forced_punts',
    'def_kr_yd',
    'def_pass_def',
    'def_pr_yd',
    'def_st_ff',
    'def_st_fum_rec',
    'def_st_td',
    'def_st_tkl_solo',
    'def_td',
    'ff',
    'fg_ret_yd',
    'fgm',
    'fgm_0_19',
    'fgm_20_29',
    'fgm_30_39',
    'fgm_40_49',
    'fgm_50_59',
    'fgm_50p',
    'fgm_60p',
    'fgm_yds',
    'fgm_yds_over_30',
    'fgmiss',
    'fgmiss_0_19',
    'fgmiss_20_29',
    'fgmiss_30_39',
    'fgmiss_40_49',
    'fgmiss_50_59',
    'fgmiss_50p',
    'fgmiss_60p',
    'fum',
    'fum_lost',
    'fum_rec',
    'fum_rec_td',
    'fum_ret_yd',
    'idp_blk_kick',
    'idp_def_td',
    'idp_ff',
    'idp_fum_rec',
    'idp_fum_ret_yd',
    'idp_int',
    'idp_int_ret_yd',
    'idp_pass_def',
    'idp_pass_def_3p',
    'idp_qb_hit',
    'idp_sack',
    'idp_sack_yd',
    'idp_safe',
    'idp_tkl',
    'idp_tkl_ast',
    'idp_tkl_loss',
    'idp_tkl_solo',
    'int',
    'int_ret_yd',
    'kr_yd',
    'pass_2pt',
    'pass_att',
    'pass_cmp',
    'pass_cmp_40p',
    'pass_def',
    'pass_fd',
    'pass_inc',
    'pass_int',
    'pass_int_td',
    'pass_sack',
    'pass_td',
    'pass_td_40p',
    'pass_td_50p',
    'pass_yd',
    'pr_yd',
    'pts_allow',
    'pts_allow_0',
    'pts_allow_1_6',
    'pts_allow_7_13',
    'pts_allow_14_20',
    'pts_allow_21_27',
    'pts_allow_28_34',
    'pts_allow_35p',
    'qb_hit',
    'rec',
    'rec_0_4',
    'rec_2pt',
    'rec_5_9',
    'rec_10_19',
    'rec_20_29',
    'rec_30_39',
    'rec_40p',
    'rec_fb',
    'rec_fd',
    'rec_qb',
    'rec_rb',
    'rec_td',
    'rec_td_40p',
    'rec_td_50p',
    'rec_te',
    'rec_wr',
    'rec_yd',
    'rush_2pt',
    'rush_40p',
    'rush_att',
    'rush_fd',
    'rush_td',
    'rush_td_40p',
    'rush_td_50p',
    'rush_yd',
    'sack',
    'sack_yd',
    'safe',
    'st_ff',
    'st_fum_rec',
    'st_td',
    'st_tkl_solo',
    'tkl',
    'tkl_ast',
    'tkl_loss',
    'tkl_solo',
    'xpm',
    'xpmiss',
    'yds_allow',
    'yds_allow_0_100',
    'yds_allow_100_199',
    'yds_allow_200_299',
    'yds_allow_300_349',
    'yds_allow_350_399',
    'yds_allow_400_449',
    'yds_allow_450_499',
    'yds_allow_500_549',
    'yds_allow_550p'
  ]::text[];
  v_reception_points numeric;
  v_passing_touchdown_points numeric;
  v_tight_end_reception_bonus numeric;
  v_broad_scoring_format text;
  v_has_position_specific_reception boolean;
  v_has_material_position_reception boolean;
  v_has_bonus_scoring boolean;
  v_has_idp_scoring boolean;
  v_position_keys text[];
  v_bonus_keys text[];
  v_idp_keys text[];
  v_unknown_keys text[];
  v_malformed_keys text[];
  v_reviewed_noop_keys text[];
  v_position_key_count integer;
  v_bonus_key_count integer;
  v_idp_key_count integer;
  v_unknown_key_count integer;
  v_malformed_key_count integer;
  v_reviewed_noop_key_count integer;
  v_effective_rule_count integer;
  v_bonus_values jsonb;
  v_idp_values jsonb;
  v_effective_scoring jsonb;
  v_effective_scoring_fingerprint text;
begin
  if p_scoring_settings is null
    or pg_catalog.jsonb_typeof(p_scoring_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_scoring_settings::text, 'UTF8')
    ) > 131072
  then
    raise exception using
      errcode = '22023',
      message = 'The Sleeper scoring settings are invalid.';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where setting.key = any(v_reviewed_scoring_keys)
      and case
        when pg_catalog.jsonb_typeof(setting.value) = 'number'
          then pg_catalog.abs((setting.value #>> '{}')::numeric) > 1000000
        else false
      end
  ) then
    raise exception using
      errcode = '22023',
      message = 'A reviewed Sleeper scoring dimension is outside the supported range.';
  end if;

  v_effective_scoring :=
    app_private.sleeper_effective_scoring_v1(p_scoring_settings);

  v_reception_points := case
    when pg_catalog.jsonb_typeof(p_scoring_settings -> 'rec') = 'number'
      then (p_scoring_settings ->> 'rec')::numeric
    else null
  end;
  v_passing_touchdown_points := case
    when pg_catalog.jsonb_typeof(p_scoring_settings -> 'pass_td') = 'number'
      then (p_scoring_settings ->> 'pass_td')::numeric
    else null
  end;

  select pg_catalog.count(*)::integer
  into v_position_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where setting.key ~ '^(bonus_rec|rec)_(fb|qb|rb|te|wr)$';

  select coalesce(
    pg_catalog.array_agg(category_setting.key order by category_setting.key collate "C"),
    array[]::text[]
  )
  into v_position_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where setting.key ~ '^(bonus_rec|rec)_(fb|qb|rb|te|wr)$'
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as category_setting;

  select pg_catalog.count(*)::integer
  into v_bonus_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where setting.key like 'bonus\_%' escape '\';

  select coalesce(
    pg_catalog.array_agg(category_setting.key order by category_setting.key collate "C"),
    array[]::text[]
  )
  into v_bonus_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where setting.key like 'bonus\_%' escape '\'
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as category_setting;

  select pg_catalog.count(*)::integer
  into v_idp_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where setting.key like 'idp\_%' escape '\'
    or setting.key in (
      'tkl', 'tkl_solo', 'tkl_ast', 'tkl_loss', 'qb_hit', 'pass_def'
    );

  select coalesce(
    pg_catalog.array_agg(category_setting.key order by category_setting.key collate "C"),
    array[]::text[]
  )
  into v_idp_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where (
        setting.key like 'idp\_%' escape '\'
        or setting.key in (
          'tkl', 'tkl_solo', 'tkl_ast', 'tkl_loss', 'qb_hit', 'pass_def'
        )
      )
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as category_setting;

  select pg_catalog.count(*)::integer
  into v_unknown_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where not (setting.key = any(v_reviewed_scoring_keys));

  select coalesce(
    pg_catalog.array_agg(unknown_setting.key order by unknown_setting.key collate "C"),
    array[]::text[]
  )
  into v_unknown_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where not (setting.key = any(v_reviewed_scoring_keys))
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as unknown_setting;

  select coalesce(
    pg_catalog.array_agg(malformed_setting.key order by malformed_setting.key collate "C"),
    array[]::text[]
  )
  into v_malformed_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where setting.key = any(v_reviewed_scoring_keys)
      and pg_catalog.jsonb_typeof(setting.value) <> 'number'
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as malformed_setting;

  select pg_catalog.count(*)::integer
  into v_malformed_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where setting.key = any(v_reviewed_scoring_keys)
    and pg_catalog.jsonb_typeof(setting.value) <> 'number';

  select pg_catalog.count(*)::integer
  into v_reviewed_noop_key_count
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where not (v_effective_scoring ? setting.key);

  select coalesce(
    pg_catalog.array_agg(noop_setting.key order by noop_setting.key collate "C"),
    array[]::text[]
  )
  into v_reviewed_noop_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where not (v_effective_scoring ? setting.key)
      and setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as noop_setting;

  select coalesce(
    pg_catalog.jsonb_object_agg(
      setting.key,
      setting.value
      order by setting.key collate "C"
    ),
    '{}'::jsonb
  )
  into v_bonus_values
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
  where setting.key like 'bonus\_%' escape '\'
    and case
      when pg_catalog.jsonb_typeof(setting.value) = 'number'
        then (setting.value #>> '{}')::numeric <> 0
      else false
    end;

  select coalesce(
    pg_catalog.jsonb_object_agg(
      setting.key,
      setting.value
      order by setting.key collate "C"
    ),
    '{}'::jsonb
  )
  into v_idp_values
  from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where (
      setting.key like 'idp\_%' escape '\'
      or setting.key in (
        'tkl', 'tkl_solo', 'tkl_ast', 'tkl_loss', 'qb_hit', 'pass_def'
      )
    )
    and case
      when pg_catalog.jsonb_typeof(setting.value) = 'number'
        then (setting.value #>> '{}')::numeric <> 0
      else false
    end;

  v_has_position_specific_reception :=
    pg_catalog.cardinality(v_position_keys) > 0;
  v_has_material_position_reception := exists (
    select 1
    from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
    where setting.key ~ '^(bonus_rec|rec)_(fb|qb|rb|te|wr)$'
      and case
        when pg_catalog.jsonb_typeof(setting.value) = 'number' then (
          (
            setting.key like 'bonus\_rec\_%' escape '\'
            and (setting.value #>> '{}')::numeric <> 0
          )
          or (
            setting.key like 'rec\_%' escape '\'
            and (
              v_reception_points is null
              or (setting.value #>> '{}')::numeric <> v_reception_points
            )
          )
        )
        else false
      end
  );
  v_has_bonus_scoring := v_bonus_values <> '{}'::jsonb;
  v_has_idp_scoring := v_idp_values <> '{}'::jsonb;

  v_tight_end_reception_bonus := case
    when pg_catalog.jsonb_typeof(
      p_scoring_settings -> 'bonus_rec_te'
    ) = 'number'
      then (p_scoring_settings ->> 'bonus_rec_te')::numeric
    when pg_catalog.jsonb_typeof(p_scoring_settings -> 'rec_te') = 'number'
      and v_reception_points is not null
      then (p_scoring_settings ->> 'rec_te')::numeric - v_reception_points
    else null
  end;

  v_broad_scoring_format := case
    when pg_catalog.jsonb_typeof(p_scoring_settings -> 'rec')
      is distinct from 'number'
      then 'unknown'
    when exists (
      select 1
      from pg_catalog.jsonb_each(p_scoring_settings) as setting(key, value)
      where setting.key ~ '^(bonus_rec|rec)_(fb|qb|rb|te|wr)$'
        and pg_catalog.jsonb_typeof(setting.value) <> 'number'
    ) then 'unknown'
    when v_has_material_position_reception then 'custom'
    when v_reception_points = 1 then 'ppr'
    when v_reception_points = 0.5 then 'half_ppr'
    when v_reception_points = 0 then 'standard'
    else 'custom'
  end;

  select pg_catalog.count(*)::integer
  into v_effective_rule_count
  from pg_catalog.jsonb_each(v_effective_scoring);
  v_effective_scoring_fingerprint := app_private.context_sha256(
    'fantasyhud:nfl:effective_scoring',
    1,
    v_effective_scoring
  );

  broad_scoring_format := v_broad_scoring_format;
  reception_points := v_reception_points;
  passing_touchdown_points := v_passing_touchdown_points;
  tight_end_reception_bonus := v_tight_end_reception_bonus;
  has_position_specific_reception := v_has_position_specific_reception;
  has_bonus_scoring := v_has_bonus_scoring;
  has_idp_scoring := v_has_idp_scoring;
  compatibility_key := app_private.context_sha256(
    'fantasyhud:nfl:scoring_compatibility',
    1,
    v_effective_scoring
  );
  derived_dimensions := pg_catalog.jsonb_build_object(
    'normalization_version', 1,
    'effective_scoring_fingerprint', v_effective_scoring_fingerprint,
    'effective_rule_count', v_effective_rule_count,
    'reviewed_noop_keys', v_reviewed_noop_keys,
    'reviewed_noop_key_count', v_reviewed_noop_key_count,
    'reviewed_noop_keys_truncated',
      v_reviewed_noop_key_count > pg_catalog.cardinality(v_reviewed_noop_keys),
    'position_specific_reception_keys', v_position_keys,
    'position_specific_reception_key_count', v_position_key_count,
    'position_specific_reception_keys_truncated',
      v_position_key_count > pg_catalog.cardinality(v_position_keys),
    'bonus_scoring_keys', v_bonus_keys,
    'bonus_scoring_key_count', v_bonus_key_count,
    'bonus_scoring_keys_truncated',
      v_bonus_key_count > pg_catalog.cardinality(v_bonus_keys),
    'idp_scoring_keys', v_idp_keys,
    'idp_scoring_key_count', v_idp_key_count,
    'idp_scoring_keys_truncated',
      v_idp_key_count > pg_catalog.cardinality(v_idp_keys),
    'unknown_keys', v_unknown_keys,
    'unknown_key_count', v_unknown_key_count,
    'unknown_keys_truncated',
      v_unknown_key_count > pg_catalog.cardinality(v_unknown_keys),
    'malformed_reviewed_keys', v_malformed_keys,
    'malformed_reviewed_key_count', v_malformed_key_count,
    'malformed_reviewed_keys_truncated',
      v_malformed_key_count > pg_catalog.cardinality(v_malformed_keys)
  );

  return next;
end;
$$;

revoke all on function app_private.classify_sleeper_scoring_settings(jsonb)
from public, anon, authenticated, service_role;

comment on function app_private.classify_sleeper_scoring_settings(jsonb) is
  'Owner-only immutable version-one Sleeper scoring classifier. Compatibility hashes the provider-neutral effective object; every material or unknown exact rule remains unless it is one of the two reviewed no-op families.';

create or replace function app_private.classify_sleeper_league_format_v1(
  p_scoring_compatibility_key text,
  p_roster_positions text[],
  p_league_settings jsonb,
  p_team_count integer,
  p_roster_size integer,
  p_roster_management_type text,
  p_is_best_ball boolean,
  p_has_superflex boolean,
  p_has_idp boolean
)
returns table (
  lineup_profile jsonb,
  lineup_profile_fingerprint text,
  quarterback_format text,
  draft_relevant_settings jsonb,
  compatibility_key text,
  context_quality text,
  derived_dimensions jsonb
)
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  -- The 30-row controlled Production audit found 49 numeric settings keys.
  -- Version one reviews only these structural draft/player-pool dimensions;
  -- every other key/value is retained by the exact unknown fallback hash.
  v_reviewed_setting_keys constant text[] := array[
    'best_ball',
    'capacity_override',
    'draft_rounds',
    'max_keepers',
    'num_teams',
    'pick_trading',
    'reserve_allow_cov',
    'reserve_allow_dnr',
    'reserve_allow_doubtful',
    'reserve_allow_na',
    'reserve_allow_out',
    'reserve_allow_sus',
    'reserve_slots',
    'taxi_allow_vets',
    'taxi_deadline',
    'taxi_slots',
    'taxi_years',
    'type'
  ]::text[];
  v_lineup_profile jsonb;
  v_lineup_profile_fingerprint text;
  v_quarterback_format text;
  v_draft_relevant_settings jsonb;
  v_draft_relevant_setting_keys text[];
  v_unknown_settings jsonb;
  v_unknown_setting_keys text[];
  v_unknown_setting_key_count integer;
  v_unknown_settings_fingerprint text;
  v_expected_management text;
  v_expected_best_ball boolean;
  v_expected_superflex boolean;
  v_expected_idp boolean;
  v_qb_slots integer;
  v_superflex_slots integer;
  v_idp_slots integer;
  v_lineup_profile_token_count integer;
begin
  if p_scoring_compatibility_key is null
    or p_scoring_compatibility_key !~ '^[0-9a-f]{64}$'
    or not app_private.exact_roster_positions_are_safe(p_roster_positions)
    or p_league_settings is null
    or pg_catalog.jsonb_typeof(p_league_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_league_settings::text, 'UTF8')
    ) > 131072
    or p_team_count is null
    or p_team_count not between 1 and 1000
    or p_roster_size is null
    or p_roster_size not between 0 and 1000
    or p_roster_size <> pg_catalog.cardinality(p_roster_positions)
    or p_roster_management_type is null
    or p_roster_management_type not in (
      'redraft', 'keeper', 'dynasty', 'unknown'
    )
    or p_is_best_ball is null
    or p_has_superflex is null
    or p_has_idp is null
  then
    raise exception using
      errcode = '22023',
      message = 'The version-one Sleeper league format input is invalid.';
  end if;

  select coalesce(
    pg_catalog.jsonb_object_agg(
      profile.position,
      profile.slot_count
      order by profile.position collate "C"
    ),
    '{}'::jsonb
  )
  into v_lineup_profile
  from (
    select position.value as position, pg_catalog.count(*)::integer as slot_count
    from pg_catalog.unnest(p_roster_positions) as position(value)
    group by position.value
  ) as profile;

  select pg_catalog.count(*)::integer
  into v_lineup_profile_token_count
  from pg_catalog.jsonb_each(v_lineup_profile);

  select
    pg_catalog.count(*) filter (where position.value = 'QB')::integer,
    pg_catalog.count(*) filter (
      where position.value in ('SUPER_FLEX', 'QB_FLEX')
    )::integer,
    pg_catalog.count(*) filter (
      where position.value in (
        'DL', 'DE', 'DT', 'LB', 'DB', 'CB', 'S', 'EDGE', 'IDP_FLEX'
      )
    )::integer
  into v_qb_slots, v_superflex_slots, v_idp_slots
  from pg_catalog.unnest(p_roster_positions) as position(value);

  v_expected_management := case
    when p_league_settings -> 'type' = '0'::jsonb then 'redraft'
    when p_league_settings -> 'type' = '1'::jsonb then 'keeper'
    when p_league_settings -> 'type' = '2'::jsonb then 'dynasty'
    else 'unknown'
  end;
  v_expected_best_ball := coalesce(
    p_league_settings -> 'best_ball' = '1'::jsonb,
    false
  );
  v_expected_superflex := v_superflex_slots > 0;
  v_expected_idp := v_idp_slots > 0;

  if p_roster_management_type <> v_expected_management
    or p_is_best_ball <> v_expected_best_ball
    or p_has_superflex <> v_expected_superflex
    or p_has_idp <> v_expected_idp
  then
    raise exception using
      errcode = '22023',
      message = 'The derived Sleeper league format does not match exact source state.';
  end if;

  v_quarterback_format := case
    when pg_catalog.cardinality(p_roster_positions) = 0 then 'unknown'
    when v_qb_slots = 0 and v_superflex_slots = 0 then 'no_qb'
    when v_qb_slots = 1 and v_superflex_slots = 0 then 'one_qb'
    when v_qb_slots in (0, 1) and v_superflex_slots = 1
      then 'superflex'
    when v_qb_slots = 2 and v_superflex_slots = 0 then 'two_qb'
    when v_qb_slots = 2 and v_superflex_slots = 1
      then 'two_qb_superflex'
    else 'custom'
  end;

  v_lineup_profile_fingerprint := app_private.context_sha256(
    'fantasyhud:nfl:lineup_profile',
    1,
    v_lineup_profile
  );

  select coalesce(
    pg_catalog.jsonb_object_agg(
      setting.key,
      setting.value
      order by setting.key collate "C"
    ),
    '{}'::jsonb
  )
  into v_draft_relevant_settings
  from pg_catalog.jsonb_each(p_league_settings) as setting(key, value)
  where setting.key = any(v_reviewed_setting_keys)
    and case
      when pg_catalog.jsonb_typeof(setting.value) = 'number'
        then pg_catalog.abs((setting.value #>> '{}')::numeric) <= 1000000
      else false
    end;

  select coalesce(
    pg_catalog.array_agg(setting.key order by setting.key collate "C"),
    array[]::text[]
  )
  into v_draft_relevant_setting_keys
  from pg_catalog.jsonb_each(v_draft_relevant_settings) as setting(key, value);

  select coalesce(
    pg_catalog.jsonb_object_agg(
      setting.key,
      setting.value
      order by setting.key collate "C"
    ),
    '{}'::jsonb
  )
  into v_unknown_settings
  from pg_catalog.jsonb_each(p_league_settings) as setting(key, value)
  where not (
    setting.key = any(v_reviewed_setting_keys)
    and case
      when pg_catalog.jsonb_typeof(setting.value) = 'number'
        then pg_catalog.abs((setting.value #>> '{}')::numeric) <= 1000000
      else false
    end
  );

  select pg_catalog.count(*)::integer
  into v_unknown_setting_key_count
  from pg_catalog.jsonb_each(v_unknown_settings);

  select coalesce(
    pg_catalog.array_agg(setting.key order by setting.key collate "C"),
    array[]::text[]
  )
  into v_unknown_setting_keys
  from (
    select setting.key
    from pg_catalog.jsonb_each(v_unknown_settings) as setting(key, value)
    where setting.key ~ '^[A-Za-z0-9_.:-]{1,128}$'
    order by setting.key collate "C"
    limit 32
  ) as setting;

  v_unknown_settings_fingerprint := case
    when v_unknown_settings <> '{}'::jsonb
      then app_private.context_sha256(
        'fantasyhud:nfl:league_settings_unknown',
        1,
        v_unknown_settings
      )
    else null
  end;

  lineup_profile := v_lineup_profile;
  lineup_profile_fingerprint := v_lineup_profile_fingerprint;
  quarterback_format := v_quarterback_format;
  draft_relevant_settings := v_draft_relevant_settings;
  compatibility_key := app_private.context_sha256(
    'fantasyhud:nfl:league_format_compatibility',
    1,
    pg_catalog.jsonb_strip_nulls(
      pg_catalog.jsonb_build_object(
        'scoring_compatibility_key', p_scoring_compatibility_key,
        'lineup_profile_fingerprint', v_lineup_profile_fingerprint,
        'team_count', p_team_count,
        'roster_size', p_roster_size,
        'roster_management_type', p_roster_management_type,
        'is_best_ball', p_is_best_ball,
        'quarterback_format', v_quarterback_format,
        'has_idp', p_has_idp,
        'draft_relevant_settings', v_draft_relevant_settings,
        'unknown_settings_fingerprint', v_unknown_settings_fingerprint
      )
    )
  );
  context_quality := 'exact';
  derived_dimensions := pg_catalog.jsonb_build_object(
    'normalization_version', 1,
    'qb_slots', v_qb_slots,
    'superflex_slots', v_superflex_slots,
    'idp_slots', v_idp_slots,
    'lineup_profile_token_count', v_lineup_profile_token_count,
    'draft_relevant_settings', v_draft_relevant_settings,
    'draft_relevant_setting_keys', v_draft_relevant_setting_keys,
    'unknown_league_setting_keys', v_unknown_setting_keys,
    'unknown_league_setting_key_count', v_unknown_setting_key_count,
    'unknown_league_setting_keys_truncated',
      v_unknown_setting_key_count >
        pg_catalog.cardinality(v_unknown_setting_keys),
    'unknown_league_settings_fingerprint', v_unknown_settings_fingerprint
  );

  return next;
end;
$$;

revoke all on function app_private.classify_sleeper_league_format_v1(
  text,
  text[],
  jsonb,
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) from public, anon, authenticated, service_role;

comment on function app_private.classify_sleeper_league_format_v1(
  text,
  text[],
  jsonb,
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) is
  'Owner-only immutable version-one Sleeper/NFL format classifier. It preserves every slot count, keeps QB topology independent from IDP, and hashes unclassified exact settings conservatively.';

create or replace function app_private.ensure_sleeper_league_format_context(
  p_provider text,
  p_sport text,
  p_scoring_settings jsonb,
  p_roster_positions jsonb,
  p_league_settings jsonb,
  p_team_count integer,
  p_roster_size integer,
  p_roster_management_type text,
  p_is_best_ball boolean,
  p_has_superflex boolean,
  p_has_idp boolean
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_normalization_version constant integer := 1;
  v_scoring_classification record;
  v_format_classification record;
  v_scoring_fingerprint text;
  v_scoring_context_id uuid;
  v_roster_positions text[];
  v_league_settings_fingerprint text;
  v_lineup_fingerprint text;
  v_format_fingerprint text;
  v_format_context_id uuid;
begin
  if p_provider is null
    or p_provider <> 'sleeper'
    or p_sport is null
    or p_sport <> 'nfl'
    or p_scoring_settings is null
    or pg_catalog.jsonb_typeof(p_scoring_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_scoring_settings::text, 'UTF8')
    ) > 131072
    or p_roster_positions is null
    or pg_catalog.jsonb_typeof(p_roster_positions) <> 'array'
    or pg_catalog.jsonb_array_length(p_roster_positions) > 1000
    or p_league_settings is null
    or pg_catalog.jsonb_typeof(p_league_settings) <> 'object'
    or pg_catalog.octet_length(
      pg_catalog.convert_to(p_league_settings::text, 'UTF8')
    ) > 131072
    or p_team_count is null
    or p_team_count not between 1 and 1000
    or p_roster_size is null
    or p_roster_size not between 0 and 1000
    or p_roster_size <> pg_catalog.jsonb_array_length(p_roster_positions)
    or p_roster_management_type is null
    or p_roster_management_type not in (
      'redraft', 'keeper', 'dynasty', 'unknown'
    )
    or p_is_best_ball is null
    or p_has_superflex is null
    or p_has_idp is null
  then
    raise exception using
      errcode = '22023',
      message = 'The exact Sleeper league format input is invalid.';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(p_roster_positions) as position(value)
    where pg_catalog.jsonb_typeof(position.value) <> 'string'
      or position.value #>> '{}' !~ '^[A-Z0-9_]{1,64}$'
  ) then
    raise exception using
      errcode = '22023',
      message = 'The exact Sleeper roster positions are invalid.';
  end if;

  select pg_catalog.array_agg(
    position.value
    order by position.ordinality
  )
  into v_roster_positions
  from pg_catalog.jsonb_array_elements_text(p_roster_positions)
    with ordinality as position(value, ordinality);

  v_roster_positions := coalesce(v_roster_positions, array[]::text[]);

  select classified.*
  into v_scoring_classification
  from app_private.classify_sleeper_scoring_settings(
    p_scoring_settings
  ) as classified;

  v_scoring_fingerprint := app_private.context_sha256(
    'scoring_context:' || p_provider || ':' || p_sport,
    v_normalization_version,
    p_scoring_settings
  );

  insert into public.scoring_contexts (
    provider,
    sport,
    normalization_version,
    scoring_fingerprint,
    exact_scoring_settings,
    broad_scoring_format,
    reception_points,
    passing_touchdown_points,
    tight_end_reception_bonus,
    has_position_specific_reception,
    has_bonus_scoring,
    has_idp_scoring,
    compatibility_key,
    derived_dimensions
  )
  values (
    p_provider,
    p_sport,
    v_normalization_version,
    v_scoring_fingerprint,
    p_scoring_settings,
    v_scoring_classification.broad_scoring_format,
    v_scoring_classification.reception_points,
    v_scoring_classification.passing_touchdown_points,
    v_scoring_classification.tight_end_reception_bonus,
    v_scoring_classification.has_position_specific_reception,
    v_scoring_classification.has_bonus_scoring,
    v_scoring_classification.has_idp_scoring,
    v_scoring_classification.compatibility_key,
    v_scoring_classification.derived_dimensions
  )
  on conflict on constraint
    scoring_contexts_provider_sport_version_fingerprint_key
  do nothing
  returning public.scoring_contexts.id into v_scoring_context_id;

  if not found then
    select scoring.id
    into v_scoring_context_id
    from public.scoring_contexts as scoring
    where scoring.provider = p_provider
      and scoring.sport = p_sport
      and scoring.normalization_version = v_normalization_version
      and scoring.scoring_fingerprint = v_scoring_fingerprint;

    if not found then
      raise exception using
        errcode = '55000',
        message = 'The immutable scoring context could not be resolved.';
    end if;
  end if;

  if not exists (
    select 1
    from public.scoring_contexts as scoring
    where scoring.id = v_scoring_context_id
      and scoring.provider = p_provider
      and scoring.sport = p_sport
      and scoring.normalization_version = v_normalization_version
      and scoring.scoring_fingerprint = v_scoring_fingerprint
      and scoring.exact_scoring_settings = p_scoring_settings
      and scoring.broad_scoring_format =
        v_scoring_classification.broad_scoring_format
      and scoring.reception_points is not distinct from
        v_scoring_classification.reception_points
      and scoring.passing_touchdown_points is not distinct from
        v_scoring_classification.passing_touchdown_points
      and scoring.tight_end_reception_bonus is not distinct from
        v_scoring_classification.tight_end_reception_bonus
      and scoring.has_position_specific_reception =
        v_scoring_classification.has_position_specific_reception
      and scoring.has_bonus_scoring =
        v_scoring_classification.has_bonus_scoring
      and scoring.has_idp_scoring =
        v_scoring_classification.has_idp_scoring
      and scoring.compatibility_key =
        v_scoring_classification.compatibility_key
      and scoring.derived_dimensions =
        v_scoring_classification.derived_dimensions
  ) then
    raise exception using
      errcode = '55000',
      message = 'The immutable scoring context identity is inconsistent.';
  end if;

  v_league_settings_fingerprint := app_private.context_sha256(
    'league_settings:' || p_provider || ':' || p_sport,
    v_normalization_version,
    p_league_settings
  );
  v_lineup_fingerprint := app_private.context_text_array_sha256(
    'lineup:' || p_provider || ':' || p_sport,
    v_normalization_version,
    v_roster_positions
  );

  select classified.*
  into v_format_classification
  from app_private.classify_sleeper_league_format_v1(
    v_scoring_classification.compatibility_key,
    v_roster_positions,
    p_league_settings,
    p_team_count,
    p_roster_size,
    p_roster_management_type,
    p_is_best_ball,
    p_has_superflex,
    p_has_idp
  ) as classified;

  v_format_fingerprint := app_private.league_format_fingerprint(
    v_normalization_version,
    p_provider,
    p_sport,
    v_scoring_fingerprint,
    v_league_settings_fingerprint,
    v_roster_positions,
    p_team_count,
    p_roster_size,
    p_roster_management_type,
    p_is_best_ball,
    p_has_superflex,
    p_has_idp
  );

  insert into public.league_format_contexts (
    provider,
    sport,
    normalization_version,
    scoring_context_id,
    format_fingerprint,
    league_settings_fingerprint,
    lineup_fingerprint,
    lineup_profile_fingerprint,
    lineup_profile,
    exact_roster_positions,
    exact_league_settings,
    team_count,
    roster_size,
    roster_management_type,
    is_best_ball,
    has_superflex,
    has_idp,
    quarterback_format,
    compatibility_key,
    context_quality,
    derived_dimensions
  )
  values (
    p_provider,
    p_sport,
    v_normalization_version,
    v_scoring_context_id,
    v_format_fingerprint,
    v_league_settings_fingerprint,
    v_lineup_fingerprint,
    v_format_classification.lineup_profile_fingerprint,
    v_format_classification.lineup_profile,
    v_roster_positions,
    p_league_settings,
    p_team_count,
    p_roster_size,
    p_roster_management_type,
    p_is_best_ball,
    p_has_superflex,
    p_has_idp,
    v_format_classification.quarterback_format,
    v_format_classification.compatibility_key,
    v_format_classification.context_quality,
    v_format_classification.derived_dimensions
  )
  on conflict on constraint
    league_format_contexts_provider_sport_version_fingerprint_key
  do nothing
  returning public.league_format_contexts.id into v_format_context_id;

  if not found then
    select format.id
    into v_format_context_id
    from public.league_format_contexts as format
    where format.provider = p_provider
      and format.sport = p_sport
      and format.normalization_version = v_normalization_version
      and format.format_fingerprint = v_format_fingerprint;

    if not found then
      raise exception using
        errcode = '55000',
        message = 'The immutable league format context could not be resolved.';
    end if;
  end if;

  if not exists (
    select 1
    from public.league_format_contexts as format
    where format.id = v_format_context_id
      and format.provider = p_provider
      and format.sport = p_sport
      and format.normalization_version = v_normalization_version
      and format.scoring_context_id = v_scoring_context_id
      and format.format_fingerprint = v_format_fingerprint
      and format.league_settings_fingerprint =
        v_league_settings_fingerprint
      and format.lineup_fingerprint = v_lineup_fingerprint
      and format.lineup_profile_fingerprint =
        v_format_classification.lineup_profile_fingerprint
      and format.lineup_profile = v_format_classification.lineup_profile
      and format.exact_roster_positions = v_roster_positions
      and format.exact_league_settings = p_league_settings
      and format.team_count = p_team_count
      and format.roster_size = p_roster_size
      and format.roster_management_type = p_roster_management_type
      and format.is_best_ball = p_is_best_ball
      and format.has_superflex = p_has_superflex
      and format.has_idp = p_has_idp
      and format.quarterback_format =
        v_format_classification.quarterback_format
      and format.compatibility_key =
        v_format_classification.compatibility_key
      and format.context_quality = v_format_classification.context_quality
      and format.derived_dimensions =
        v_format_classification.derived_dimensions
  ) then
    raise exception using
      errcode = '55000',
      message = 'The immutable league format context identity is inconsistent.';
  end if;

  return v_format_context_id;
end;
$$;

revoke all on function app_private.ensure_sleeper_league_format_context(
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) from public, anon, authenticated, service_role;

comment on function app_private.ensure_sleeper_league_format_context(
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  integer,
  integer,
  text,
  boolean,
  boolean,
  boolean
) is
  'Owner-only reviewed lifecycle boundary that validates exact Sleeper league state and creates or reuses immutable version-one contexts.';

create or replace function app_private.reject_context_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception using
    errcode = '55000',
    message = case
      when tg_table_name = 'league_format_observations'
        then 'League format observations are append-only.'
      else 'Scoring and league format contexts are immutable.'
    end;
end;
$$;

create or replace function app_private.validate_scoring_context_insert()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_classification record;
begin
  if new.provider = 'sleeper'
    and new.sport = 'nfl'
    and new.normalization_version = 1
  then
    select classified.*
    into v_classification
    from app_private.classify_sleeper_scoring_settings(
      new.exact_scoring_settings
    ) as classified;

    if new.broad_scoring_format is distinct from
        v_classification.broad_scoring_format
      or new.reception_points is distinct from
        v_classification.reception_points
      or new.passing_touchdown_points is distinct from
        v_classification.passing_touchdown_points
      or new.tight_end_reception_bonus is distinct from
        v_classification.tight_end_reception_bonus
      or new.has_position_specific_reception is distinct from
        v_classification.has_position_specific_reception
      or new.has_bonus_scoring is distinct from
        v_classification.has_bonus_scoring
      or new.has_idp_scoring is distinct from
        v_classification.has_idp_scoring
      or new.compatibility_key is distinct from
        v_classification.compatibility_key
      or new.derived_dimensions is distinct from
        v_classification.derived_dimensions
    then
      raise exception using
        errcode = '23514',
        message = 'The scoring context does not match normalization version one.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function app_private.validate_league_format_context_insert()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_scoring_fingerprint text;
  v_scoring_compatibility_key text;
  v_expected_league_settings_fingerprint text;
  v_expected_lineup_fingerprint text;
  v_expected_format_fingerprint text;
  v_classification record;
begin
  select scoring.scoring_fingerprint, scoring.compatibility_key
  into v_scoring_fingerprint, v_scoring_compatibility_key
  from public.scoring_contexts as scoring
  where scoring.id = new.scoring_context_id
    and scoring.provider = new.provider
    and scoring.sport = new.sport
    and scoring.normalization_version = new.normalization_version;

  if not found then
    raise exception using
      errcode = '23514',
      message = 'The scoring context does not match the league format namespace.';
  end if;

  v_expected_league_settings_fingerprint := app_private.context_sha256(
    'league_settings:' || new.provider || ':' || new.sport,
    new.normalization_version,
    new.exact_league_settings
  );
  v_expected_lineup_fingerprint := app_private.context_text_array_sha256(
    'lineup:' || new.provider || ':' || new.sport,
    new.normalization_version,
    new.exact_roster_positions
  );
  v_expected_format_fingerprint := app_private.league_format_fingerprint(
    new.normalization_version,
    new.provider,
    new.sport,
    v_scoring_fingerprint,
    v_expected_league_settings_fingerprint,
    new.exact_roster_positions,
    new.team_count,
    new.roster_size,
    new.roster_management_type,
    new.is_best_ball,
    new.has_superflex,
    new.has_idp
  );

  if new.league_settings_fingerprint is distinct from
      v_expected_league_settings_fingerprint
    or new.lineup_fingerprint is distinct from
      v_expected_lineup_fingerprint
    or new.format_fingerprint is distinct from
      v_expected_format_fingerprint
  then
    raise exception using
      errcode = '23514',
      message = 'The league format exact fingerprints do not match source.';
  end if;

  if new.provider = 'sleeper'
    and new.sport = 'nfl'
    and new.normalization_version = 1
  then
    select classified.*
    into v_classification
    from app_private.classify_sleeper_league_format_v1(
      v_scoring_compatibility_key,
      new.exact_roster_positions,
      new.exact_league_settings,
      new.team_count,
      new.roster_size,
      new.roster_management_type,
      new.is_best_ball,
      new.has_superflex,
      new.has_idp
    ) as classified;

    if new.lineup_profile is distinct from
        v_classification.lineup_profile
      or new.lineup_profile_fingerprint is distinct from
        v_classification.lineup_profile_fingerprint
      or new.quarterback_format is distinct from
        v_classification.quarterback_format
      or new.compatibility_key is distinct from
        v_classification.compatibility_key
      or new.context_quality is distinct from
        v_classification.context_quality
      or new.derived_dimensions is distinct from
        v_classification.derived_dimensions
    then
      raise exception using
        errcode = '23514',
        message = 'The league format context does not match version one.';
    end if;
  elsif new.context_quality = 'exact' then
    raise exception using
      errcode = '23514',
      message = 'Exact league format context requires a reviewed classifier.';
  end if;

  return new;
end;
$$;

create or replace function app_private.validate_league_format_observation_insert()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_format_provider text;
  v_format_sport text;
  v_format_version integer;
  v_league_provider text;
  v_league_sport text;
  v_existing_format_context_id uuid;
  v_existing_version integer;
begin
  if new.league_id is null
    or new.format_context_id is null
    or new.observed_at is null
    or not pg_catalog.isfinite(new.observed_at)
    or new.source is null
    or new.source not in ('league_discovery', 'migration_backfill')
    or new.normalization_version is null
    or new.normalization_version not between 1 and 1000000
    or new.created_at is null
    or not pg_catalog.isfinite(new.created_at)
  then
    raise exception using
      errcode = '23514',
      message = 'The league format observation is invalid.';
  end if;

  select league.provider, league.sport
  into v_league_provider, v_league_sport
  from public.leagues as league
  where league.id = new.league_id
  for update;

  if not found then
    raise exception using
      errcode = '23514',
      message = 'The league format observation namespace is inconsistent.';
  end if;

  select
    format.provider,
    format.sport,
    format.normalization_version
  into v_format_provider, v_format_sport, v_format_version
  from public.league_format_contexts as format
  where format.id = new.format_context_id;

  if not found
    or v_format_provider is distinct from v_league_provider
    or v_format_sport is distinct from v_league_sport
    or v_format_version is distinct from new.normalization_version
  then
    raise exception using
      errcode = '23514',
      message = 'The league format observation namespace is inconsistent.';
  end if;

  select observation.format_context_id, observation.normalization_version
  into v_existing_format_context_id, v_existing_version
  from public.league_format_observations as observation
  where observation.league_id = new.league_id
    and observation.observed_at = new.observed_at;

  if found then
    if v_existing_format_context_id = new.format_context_id
      and v_existing_version = new.normalization_version
    then
      return null;
    end if;

    raise exception using
      errcode = '23505',
      message = 'A league format observation timestamp already has a conflicting context.';
  end if;

  return new;
end;
$$;

revoke all on function app_private.reject_context_mutation()
from public, anon, authenticated, service_role;
revoke all on function app_private.validate_scoring_context_insert()
from public, anon, authenticated, service_role;
revoke all on function app_private.validate_league_format_context_insert()
from public, anon, authenticated, service_role;
revoke all on function app_private.validate_league_format_observation_insert()
from public, anon, authenticated, service_role;

create trigger scoring_contexts_validate_insert
before insert on public.scoring_contexts
for each row execute function app_private.validate_scoring_context_insert();

create trigger scoring_contexts_reject_mutation
before update or delete on public.scoring_contexts
for each row execute function app_private.reject_context_mutation();

create trigger league_format_contexts_validate_insert
before insert on public.league_format_contexts
for each row execute function app_private.validate_league_format_context_insert();

create trigger league_format_contexts_reject_mutation
before update or delete on public.league_format_contexts
for each row execute function app_private.reject_context_mutation();

create trigger league_format_observations_reject_mutation
before update or delete on public.league_format_observations
for each row execute function app_private.reject_context_mutation();

create trigger league_format_observations_validate_insert
before insert on public.league_format_observations
for each row execute function app_private.validate_league_format_observation_insert();

-- Updating only the new pointer must not rewrite a previously accepted league
-- source timestamp during migration backfill.
alter table public.leagues disable trigger leagues_set_updated_at;

do $$
declare
  v_league record;
  v_format_context_id uuid;
begin
  for v_league in
    select league.*
    from public.leagues as league
    order by league.provider, league.external_league_id
  loop
    v_format_context_id :=
      app_private.ensure_sleeper_league_format_context(
        v_league.provider,
        v_league.sport,
        v_league.scoring_settings,
        v_league.roster_positions,
        v_league.settings,
        v_league.team_count,
        v_league.roster_size,
        v_league.roster_management_type,
        v_league.is_best_ball,
        v_league.has_superflex,
        v_league.has_idp
      );

    update public.leagues as league
    set current_format_context_id = v_format_context_id
    where league.id = v_league.id;

    insert into public.league_format_observations (
      league_id,
      format_context_id,
      observed_at,
      source,
      normalization_version
    )
    values (
      v_league.id,
      v_format_context_id,
      v_league.fetched_at,
      'migration_backfill',
      1
    );
  end loop;

  if exists (
    select 1
    from public.leagues as league
    where league.current_format_context_id is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'Every current league must have a format context after backfill.';
  end if;
end;
$$;

alter table public.leagues enable trigger leagues_set_updated_at;

alter table public.scoring_contexts enable row level security;
alter table public.league_format_contexts enable row level security;
alter table public.league_format_observations enable row level security;

create policy "authenticated users can select reachable scoring contexts"
on public.scoring_contexts
for select
to authenticated
using (
  exists (
    select 1
    from public.league_format_contexts as format
    inner join public.leagues as league
      on league.current_format_context_id = format.id
    inner join public.fantasy_account_leagues as discovered_league
      on discovered_league.league_id = league.id
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where format.scoring_context_id = scoring_contexts.id
      and account_link.user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.league_format_contexts as format
    inner join public.league_format_observations as observation
      on observation.format_context_id = format.id
    inner join public.fantasy_account_leagues as discovered_league
      on discovered_league.league_id = observation.league_id
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where format.scoring_context_id = scoring_contexts.id
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select reachable league format contexts"
on public.league_format_contexts
for select
to authenticated
using (
  exists (
    select 1
    from public.leagues as league
    inner join public.fantasy_account_leagues as discovered_league
      on discovered_league.league_id = league.id
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where league.current_format_context_id = league_format_contexts.id
      and account_link.user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.league_format_observations as observation
    inner join public.fantasy_account_leagues as discovered_league
      on discovered_league.league_id = observation.league_id
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where observation.format_context_id = league_format_contexts.id
      and account_link.user_id = (select auth.uid())
  )
);

create policy "authenticated users can select reachable format observations"
on public.league_format_observations
for select
to authenticated
using (
  exists (
    select 1
    from public.fantasy_account_leagues as discovered_league
    inner join public.user_fantasy_accounts as account_link
      on account_link.fantasy_account_id =
        discovered_league.fantasy_account_id
    where discovered_league.league_id = league_format_observations.league_id
      and account_link.user_id = (select auth.uid())
  )
);

revoke all on table public.scoring_contexts
from public, anon, authenticated, service_role;
revoke all on table public.league_format_contexts
from public, anon, authenticated, service_role;
revoke all on table public.league_format_observations
from public, anon, authenticated, service_role;

grant select (
  id,
  provider,
  sport,
  normalization_version,
  scoring_fingerprint,
  broad_scoring_format,
  reception_points,
  passing_touchdown_points,
  tight_end_reception_bonus,
  has_position_specific_reception,
  has_bonus_scoring,
  has_idp_scoring,
  compatibility_key,
  created_at
) on public.scoring_contexts to authenticated;

grant select (
  id,
  provider,
  sport,
  normalization_version,
  scoring_context_id,
  format_fingerprint,
  league_settings_fingerprint,
  lineup_fingerprint,
  lineup_profile_fingerprint,
  team_count,
  roster_size,
  roster_management_type,
  is_best_ball,
  has_superflex,
  has_idp,
  quarterback_format,
  compatibility_key,
  context_quality,
  created_at
) on public.league_format_contexts to authenticated;

grant select (
  id,
  league_id,
  format_context_id,
  observed_at,
  source,
  normalization_version,
  created_at
) on public.league_format_observations to authenticated;

-- Preserve the reviewed Task 006 implementation as an owner-only inner
-- lifecycle function. The public wrapper retains its exact API and delegates
-- every existing authorization, validation, freshness, reconciliation, and
-- result-count decision before maintaining contexts for accepted rows.
alter function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) rename to complete_sleeper_league_discovery_without_context;

alter function public.complete_sleeper_league_discovery_without_context(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) set schema app_private;

revoke all on function
  app_private.complete_sleeper_league_discovery_without_context(
    uuid,
    uuid,
    uuid,
    jsonb,
    jsonb
  ) from public, anon, authenticated, service_role;

create or replace function public.complete_sleeper_league_discovery(
  p_user_id uuid,
  p_fantasy_account_id uuid,
  p_sync_run_id uuid,
  p_state jsonb,
  p_leagues jsonb
)
returns table (
  sync_run_id uuid,
  observed_leagues integer,
  created_leagues integer,
  updated_leagues integer,
  stale_shared_leagues_skipped integer,
  created_associations integer,
  reactivated_associations integer,
  removed_associations integer,
  active_associations integer,
  provider_state_applied boolean,
  provider_state_stale_skipped boolean
)
language plpgsql
security definer
set search_path = pg_catalog
set statement_timeout = '60s'
as $$
declare
  v_completion record;
  v_item jsonb;
  v_league public.leagues%rowtype;
  v_fetched_at timestamptz;
  v_format_context_id uuid;
begin
  select completed.*
  into v_completion
  from app_private.complete_sleeper_league_discovery_without_context(
    p_user_id,
    p_fantasy_account_id,
    p_sync_run_id,
    p_state,
    p_leagues
  ) as completed;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The league discovery completion did not return a result.';
  end if;

  for v_item in
    select league.value
    from pg_catalog.jsonb_array_elements(p_leagues) as league(value)
    order by league.value ->> 'external_league_id'
  loop
    v_fetched_at := (v_item ->> 'fetched_at')::timestamptz;

    select league.*
    into v_league
    from public.leagues as league
    where league.provider = 'sleeper'
      and league.external_league_id = v_item ->> 'external_league_id'
    for update;

    if not found then
      raise exception using
        errcode = '55000',
        message = 'The accepted shared league could not be resolved for context maintenance.';
    end if;

    -- Equality is accepted by the established shared-league freshness rule.
    -- Older representations skip both the pointer and observation history.
    if v_league.fetched_at = v_fetched_at then
      v_format_context_id :=
        app_private.ensure_sleeper_league_format_context(
          v_league.provider,
          v_league.sport,
          v_league.scoring_settings,
          v_league.roster_positions,
          v_league.settings,
          v_league.team_count,
          v_league.roster_size,
          v_league.roster_management_type,
          v_league.is_best_ball,
          v_league.has_superflex,
          v_league.has_idp
        );

      if v_league.current_format_context_id is distinct from
        v_format_context_id
      then
        update public.leagues as league
        set current_format_context_id = v_format_context_id
        where league.id = v_league.id;
      end if;

      insert into public.league_format_observations (
        league_id,
        format_context_id,
        observed_at,
        source,
        normalization_version
      )
      values (
        v_league.id,
        v_format_context_id,
        v_fetched_at,
        'league_discovery',
        1
      );
    end if;
  end loop;

  return query
  select
    v_completion.sync_run_id,
    v_completion.observed_leagues,
    v_completion.created_leagues,
    v_completion.updated_leagues,
    v_completion.stale_shared_leagues_skipped,
    v_completion.created_associations,
    v_completion.reactivated_associations,
    v_completion.removed_associations,
    v_completion.active_associations,
    v_completion.provider_state_applied,
    v_completion.provider_state_stale_skipped;
end;
$$;

revoke all on function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) to service_role, postgres;

comment on function public.complete_sleeper_league_discovery(
  uuid,
  uuid,
  uuid,
  jsonb,
  jsonb
) is
  'Completes validated Sleeper league discovery and atomically maintains immutable version-one scoring and format contexts only for accepted shared-league representations.';
