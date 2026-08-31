-- Task 005 is already deployed. Correct its discovery-removal ordering with an
-- additive constraint replacement so existing inconsistent data fails closed.
alter table public.fantasy_account_leagues
drop constraint fantasy_account_leagues_removed_time_is_valid;

alter table public.fantasy_account_leagues
add constraint fantasy_account_leagues_removed_time_is_valid check (
  removed_at is null or removed_at >= last_seen_at
);

comment on constraint fantasy_account_leagues_removed_time_is_valid
on public.fantasy_account_leagues is
  'A discovery association can be removed only at or after its last observation.';

-- Provider-data mutation crosses one reviewed boundary:
-- validated Server Action
-- -> service-role client
-- -> narrowly scoped SECURITY DEFINER RPC
-- -> provider-data tables
-- Future imports grant service_role EXECUTE only on those reviewed functions.
revoke select, insert, update, delete
on table public.provider_season_states
from service_role;
revoke select, insert, update, delete
on table public.leagues
from service_role;
revoke select, insert, update, delete
on table public.fantasy_account_leagues
from service_role;
revoke select, insert, update, delete
on table public.sync_runs
from service_role;
