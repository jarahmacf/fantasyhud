# Conceptual data model

This document summarizes the conceptual model. `FANTASY_DATA_ARCHITECTURE.md` is the long-term grain and history contract, and reviewed migrations remain the SQL source of truth.

## Entities

- **App user:** A person who uses FANTASY HUD.
- **Fantasy account:** One shared provider identity keyed by provider and external user ID.
- **User-to-fantasy-account link:** An app user's tracked association to a shared fantasy account.
- **League:** A shared fantasy competition from a provider.
- **Provider season state:** The latest shared season and period state for one provider and sport.
- **Account-to-league discovery:** The observation that a provider reported a shared league for a tracked fantasy account; it does not prove roster ownership.
- **Roster:** A team roster within a league.
- **Roster-player membership:** One canonical player's current membership on one roster, including source-grounded starter, reserve, and taxi state.
- **Player:** A provider-identified football player.
- **Draft:** A draft associated with a league or provider context.
- **Account-to-draft membership:** The association between a connected account and a draft.
- **Complete draft board:** The full ordered set of selections from every drafter.
- **Draft pick:** One selection at an exact position in a draft.
- **Matchup:** A scoring comparison for a roster and period.
- **League-standing snapshot:** One roster's source or versioned standing within one league, season, and scoring period or snapshot time.
- **Sync run:** One traceable attempt to import or reconcile provider data.

## Implemented fantasy-data grains

- `provider_season_states`: one latest state row per provider and sport.
- `leagues`: one shared league per provider and exact external league ID.
- `fantasy_account_leagues`: one discovery association per fantasy account and shared league.
- `sync_runs`: one tracked fantasy account, scope, and attempt.

Task 006 populates these grains for the first time through one validated current-season Sleeper collection. `leagues.fetched_at` is the required observation time. Shared provider state and league representations are monotonic by this time, while account associations remain independent observations. `leagues.provider_updated_at` remains nullable, is never replaced with request time, and is not erased by a null incoming value.

The browser authorization path is `auth user → user_fantasy_accounts → fantasy account → fantasy_account_leagues → league`. Browser roles receive read-only, RLS-scoped access. Provider data is written only through reviewed service-only RPCs; `service_role` has no direct provider-table CRUD.

## Planned fantasy-data grains

- `roster_players`: one current roster + canonical player membership. It preserves source status or roster-position metadata, starter/reserve/taxi state, and first/last observation times. It is mutable current state, not draft, weekly-lineup, or transaction history.
- `league_standing_snapshots`: one league + season + scoring period or snapshot time + roster. It preserves source or versioned standings when immutable facts alone cannot reproduce provider and commissioner rules.

## Invariants

- Shared Sleeper resources are stored once.
- Concurrent first creation of a shared resource reuses one canonical row.
- Shared-resource locks are acquired in deterministic canonical-key order.
- Older provider observations never overwrite newer shared current representations.
- Auth users and provider identities remain separate concepts.
- Provider plus external user ID is canonical; usernames are mutable.
- A user may have at most one primary fantasy-account link.
- Browser sessions cannot create fantasy accounts or links.
- User ownership is represented through associations.
- League discovery never implies roster ownership.
- League-discovery persistence requires `fantasy_accounts.provider = leagues.provider = sync_runs.provider`; cross-provider associations are invalid.
- Removing one account-to-league discovery association never deletes the shared league.
- Dynasty, keeper/redraft, best ball, superflex, IDP, and broad scoring are independent context dimensions.
- Exact provider settings, scoring settings, roster positions, and metadata remain available beside derived dimensions.
- Complete draft boards include every drafter’s picks.
- Pick ownership is derived, not stored as a universal boolean.
- One league may have multiple drafts.
- Provider IDs remain strings.
- Sleeper usernames are mutable; Sleeper `user_id` is the canonical account key.
- Resolving an identity creates no league, roster, player, draft, or synchronization data.
- A valid empty current-season league collection is a successful observed zero; a source failure is not.
- Current-season league rows and success are scoped to the provider-resolved league season; historical associations remain stored.
- League discovery never updates `fantasy_accounts.last_synced_at`.
- Best-ball starter and bench labels do not affect exposure.
- Best-ball exposure counts every current `roster_players` membership while preserving source starter, reserve, and taxi facts.
- Drafted exposure comes from immutable `draft_picks`; weekly lineup history comes from `matchup_player_points`; acquisitions, drops, and trades come from transaction facts.
- Current mutable state and historical facts use separate grains.
- Historical standings are reproducible from immutable facts or stored as source/versioned snapshots; provider-only ranking rules and commissioner adjustments are not discarded.
- Historical facts preserve period-specific player ID, position, NFL-team, and scoring context rather than joining only to current player profiles.
- Player rankings require source, period, scoring context, and ranking type.
- Scoreboards use roster-week entries and per-player score lines.
- Generic entity, document, object, and record stores are prohibited.
