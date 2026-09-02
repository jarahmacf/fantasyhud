# Roster domain architecture

Task 007B.1 establishes the relational current-roster domain. Task 007B.2 uses that schema for a complete current-season Sleeper users-and-rosters import while preserving the existing integrity and read-authorization boundaries.

## Official source boundary

Task 007B.2 uses Sleeper's official read-only endpoints:

```text
GET /league/{league_id}/users
GET /league/{league_id}/rosters
```

Sleeper requires no API token. Browser code must never call either endpoint. Canonical provider IDs remain exact strings; the league-local `roster_id` is the only bounded integer source key and is meaningful only with its canonical league.

## Implemented grains

- `league_users`: one provider user identity as represented within one canonical league. This is league-member display and commissioner context, not a global fantasy account or app-user link.
- `rosters`: one league-local current provider roster. It retains the exact current source representation and observation window.
- `fantasy_account_rosters`: one explicit tracked fantasy-account ownership association to one roster in one league. `owner` and `co_owner` are the only roles.
- `roster_players`: one canonical player's current membership on one current roster, including the exact source identity mapping that established the membership.

`leagues.roster_bundle_fetched_at` is the nullable complete-collection watermark for the latest fully validated users-and-rosters bundle published for that shared league. `fantasy_account_leagues.roster_ownership_status` and `roster_ownership_observed_at` pair the account/league resolution truth (`owned`, `not_owned`, or `unresolved`) with the canonical shared roster observation used to resolve it.

The portfolio path is:

```text
auth user
→ user_fantasy_accounts
→ fantasy account
→ fantasy_account_leagues with roster_ownership_status = owned
→ fantasy_account_rosters
→ roster
→ roster_players
→ canonical player and exact player_external_ids mapping
```

League discovery remains distinct. An unevaluated `fantasy_account_leagues` row only says the provider reported a league for an account. Current confirmed ownership requires its resolution status to be `owned` plus the explicit `fantasy_account_rosters` association that identifies the roster.

## Exact source representation and normalized membership

Each `rosters` row retains the exact ordered provider arrays separately:

```text
source_player_ids
source_starter_ids
source_reserve_ids
source_taxi_ids
source_keeper_ids
co_owner_external_user_ids
```

Every exact source array is nullable. `NULL` means the source field was absent or null; `{}` means the source explicitly reported an empty array. Task 007B.2 preserves that distinction without filling source nulls with empty arrays. Co-owner, player, reserve, taxi, and keeper IDs must be exact, bounded, and unique when present. Starter IDs are exact and bounded but may repeat because source placeholder sentinels can occupy more than one slot.

Current queryable membership lives in `roster_players`. `source_order`, `starter_order`, `starter_slot`, `is_starter`, `is_reserve`, `is_taxi`, and `is_keeper` retain current source context. Active non-null source orders are unique within a roster, as are active non-null starter orders. A starter has a bounded order and an optional safe slot; a nonstarter has neither a starter order nor a starter slot. The controlled audit verified only repeated exact `"0"` starter sentinels outside `players`. They remain valid in the exact starter array but never create canonical players or normalized memberships. Every other unexplained annotation fails closed.

Best-ball exposure counts every active `roster_players` row where `removed_at is null`, regardless of starter, reserve, or taxi labels. Those labels remain source facts. Current membership is not draft ownership, acquisition history, transaction history, or weekly lineup history.

The exact source arrays remain product truth as well as storage truth. A null source array renders as `Not reported`; an explicit empty array renders as confirmed `0`. Each membership's bounded source metadata records `known` or `unknown` independently for starters, reserve, taxi, and keepers, plus bounded safe normalization-warning tokens. The latest-source UI renders these annotations as `Yes`, `No`, or `Not reported`. An unknown source state never renders a retained last-confirmed boolean as a current false value.

Keeper state has two deliberately separate meanings. `roster_players.is_keeper` is mutable current roster context from the latest accepted source collection. A future completed `draft_picks.is_keeper` is an immutable fact about that completed draft selection. Neither may substitute for the other.

Current roster settings retain exact current standings fields published by Sleeper. Historical standings require their separate planned snapshot grain; current settings must not be presented as historical snapshots.

## Ownership and co-ownership

One fantasy account may have at most one active roster association in one league. Removed associations remain stored and permit a later different active roster. Several tracked fantasy accounts may associate with the same roster, including provider co-ownership and multiple app users tracking one canonical external account.

Ownership resolution always reads the current canonical active rosters after shared bundle application or stale-bundle skipping. Exactly one account match records `owned` and creates or reactivates the association. A complete known zero match records `not_owned` and soft-removes only that account's association. A zero match with any relevant null co-owner array records `unresolved` and preserves the prior association as history. A preserved association under `unresolved` is excluded from owned-roster tables, current holdings, and owned analytics. Resolution advances only when the canonical shared roster watermark is at least the association's prior ownership observation time; another fantasy account's ownership state is never mutated.

Shared league users, rosters, and memberships never contain `user_id`, `is_mine`, or equivalent app-user ownership. Removing one tracked-account association never deletes a shared roster.

## Canonical player integrity

Every membership references both:

1. one `players` row; and
2. one exact `player_external_ids` row that references that same player.

Task 007B.2 resolves every exact roster player ID through a Sleeper/NFL primary mapping, including a historically removed mapping. When a valid exact ID is absent after the shared catalog exists, the import creates one sparse reference-only canonical unknown entity and one exact primary Sleeper mapping. It invents no player name, team, position, or active state, and its bounded source metadata identifies the roster reference. A later full catalog refresh updates that same identity when present, while catalog absence cannot retire a mapping still referenced by an active current membership.

Roster membership must not be discarded because the profile catalog lagged. Provider placeholder starter values must never create canonical players. Task 007B.2 must identify allowed placeholder behavior from sanitized live evidence and fail closed on unexplained values.

## Read authorization and supporting indexes

Authenticated league-user, roster, and roster-player reads use:

```text
row.league_id
→ fantasy_account_leagues(league_id, fantasy_account_id, removed_at is null)
→ user_fantasy_accounts(fantasy_account_id, user_id)
→ auth.uid()
```

The exact supporting indexes are `fantasy_account_leagues_league_account_idx` and `user_fantasy_accounts_account_user_idx`. Table-local league indexes support roster and current-membership access paths.

Authenticated ownership reads use:

```text
fantasy_account_rosters.fantasy_account_id
→ user_fantasy_accounts(fantasy_account_id, user_id)
→ auth.uid()
```

The supporting index is `user_fantasy_accounts_account_user_idx`; `fantasy_account_rosters_account_league_removed_idx` supports account-scoped current and historical ownership queries.

Users who reach a league through at least one active `fantasy_account_leagues` association may read all its league users, rosters, and holdings for future standings and scoreboards. A removed discovery association no longer authorizes shared current roster-domain reads. Another tracked account with an active association to the same league continues to provide reachability. Users may read current and historical ownership associations for fantasy accounts they track even when the corresponding discovery association is removed; ownership authorization remains account-scoped rather than league-reachability-scoped.

Authenticated users have read-only grants. `anon` cannot read. Browser roles and `service_role` have no direct mutation access. Future provider writes remain restricted to reviewed, fixed-search-path `SECURITY DEFINER` RPCs with execute-only service grants.

## Synchronization scope and privacy

`sync_runs` permits `league_discovery` and `roster_sync`. A partial unique index permits one running roster sync per fantasy account while preserving the independent league-discovery index. Task 007B.2 freezes private scope at start, updates the run heartbeat when each distinct league bundle stages, reuses a valid run for 15 minutes, and fails and cleans stale or inconsistent private state before replacement.

Authenticated sync-run reads use an explicit safe column grant. `triggered_by_user_id` remains server-only audit and lifecycle ownership state and is excluded from browser-selectable columns, even when several app users track the same fantasy account.

## Task 007B.2 complete-collection implementation

Task 007B.2:

- import every active current-season discovered league for one fantasy account;
- fetch both users and rosters for every league;
- validate the complete collection before any public write;
- write exact nullable arrays and normalized memberships atomically;
- preserve source-null versus explicit-empty arrays and current keeper state;
- reconcile only the exact account, provider, sport, season, and discovered-league collection;
- preserve another fantasy account's ownership associations;
- never translate a source failure into an empty collection;
- retain removed current-state rows instead of deleting shared resources; and
- leave drafts, matchups, transactions, and standings snapshots untouched.

Shared current state is monotonic by `leagues.roster_bundle_fetched_at`, the incoming fully validated collection observation time. After the deterministic league lock, an equal-or-newer bundle applies all shared league-user, roster, membership, annotation, and removal logic and advances the watermark in the same transaction. An older bundle performs no shared create, update, reactivation, or removal, so stale inclusion cannot resurrect a user, roster, or membership that a newer complete bundle proved absent. Existing per-row freshness guards remain defense in depth.

After shared application or skipping, account ownership resolves from the current canonical representation at the stored league watermark rather than from stale staged rows. A newer negative or unresolved result therefore cannot be overwritten by a later-completing older positive bundle, while a newer confirmed match restores `owned` without duplicating association history.

Concurrent first creation must use insert-or-load behavior that returns the existing canonical shared row after a conflict. Catching and ignoring a uniqueness error is not an implementation. Shared resources and memberships must be processed and locked in this deterministic order:

```text
canonical external league ID
→ external league-user ID
→ external roster ID
→ exact player ID
```

Removal reconciliation is limited to the exact fantasy account, provider, sport, season, and league set represented by the validated collection. Shared league-user, roster, and membership removals are guarded by the collection watermark; another fantasy account's ownership row is never touched. Local-Supabase integration coverage retains the simultaneous same-resource race and adds deterministic stale-absence plus newer `not_owned`/`unresolved` versus older-positive scenarios with a later confirmed recovery.

Every raw league-user source object must include an exact bounded `league_id` equal to the requested canonical league before normalization. Missing, padded, control-bearing, null, or mismatched values fail closed; the normalized stage is already scoped by that canonical league and does not repeat the ID on every user. Avatar IDs are optional exact provider identifiers: null or absent remains null, a valid bounded string is preserved byte-for-byte, and padding or controls fail rather than being display-trimmed. Username, display name, and team name retain their existing safe display normalization.

The implementation details, lifecycle RPCs, source audit, placeholder behavior, and product terminology are documented in `ROSTER_IMPORT.md` and `docs/verification/task-007b2-roster-source.md`.

No provider request, import RPC, Server Action, route, UI, or roster-domain row is introduced by Task 007B.1.
