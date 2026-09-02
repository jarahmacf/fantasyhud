# Conceptual data model

This document summarizes the conceptual model. `FANTASY_DATA_ARCHITECTURE.md` is the long-term grain and history contract, and reviewed migrations remain the SQL source of truth.

## Entities

- **App user:** A person who uses FANTASY HUD.
- **Fantasy account:** One shared provider identity keyed by provider and external user ID.
- **User-to-fantasy-account link:** An app user's tracked association to a shared fantasy account.
- **League:** A shared fantasy competition from a provider.
- **Provider season state:** The latest shared season and period state for one provider and sport.
- **Account-to-league discovery:** The observation that a provider reported a shared league for a tracked fantasy account. Its presence alone does not prove roster ownership; paired account/league resolution status and observation time record that truth separately on the same association.
- **League user:** One provider user identity as represented within one league.
- **Roster:** A team roster within a league.
- **Account-to-roster ownership:** One explicit tracked fantasy-account association to one roster in one league.
- **Roster-player membership:** One canonical player's current membership on one roster, including source-grounded starter, reserve, taxi, and keeper state.
- **Player:** One shared canonical football entity with a mutable current profile; this may be an individual, team defense, or sparse unknown entity.
- **Player external identity:** One exact namespace, sport, and external ID mapped historically to one canonical player.
- **Provider catalog run:** One global provider, sport, catalog resource, and refresh attempt.
- **Draft:** A draft associated with a league or provider context.
- **Account-to-draft membership:** The association between a connected account and a draft.
- **Complete draft board:** The full ordered set of selections from every drafter.
- **Draft pick:** One selection at an exact position in a draft.
- **Matchup:** A scoring comparison for a roster and period.
- **League-standing snapshot:** One roster's source or versioned standing within one league, season, and scoring period or snapshot time.
- **Sync run:** One traceable attempt to import or reconcile provider data.

## Implemented fantasy-data grains

- `provider_season_states`: one latest state row per provider and sport.
- `leagues`: one shared league per provider and exact external league ID, including the latest published complete roster-bundle watermark.
- `fantasy_account_leagues`: one discovery association per fantasy account and shared league, including nullable `owned`, `not_owned`, or `unresolved` roster-ownership resolution and its observation time.
- `sync_runs`: one tracked fantasy account, scope, and attempt.
- `players`: one shared canonical NFL entity and mutable current profile.
- `player_external_ids`: one exact historical namespace, sport, and external ID mapping.
- `provider_catalog_runs`: one global provider, sport, catalog resource, and attempt.
- `league_users`: one provider user identity as represented within one canonical league.
- `rosters`: one league-local current provider roster with exact nullable source arrays that distinguish absent from explicitly empty.
- `fantasy_account_rosters`: one explicit tracked-account ownership association to one roster in one league.
- `roster_players`: one canonical player's current membership on one roster, tied to its exact source identity mapping.

Task 006 populates these grains for the first time through one validated current-season Sleeper collection. `leagues.fetched_at` is the required observation time. Shared provider state and league representations are monotonic by this time, while account associations remain independent observations. `leagues.provider_updated_at` remains nullable, is never replaced with request time, and is not erased by a null incoming value.

Task 007B.2 populates the four roster-domain grains through one frozen current-season scope and one complete validated users-and-rosters bundle per expected league. Exact source arrays remain beside normalized membership. `players` is the membership authority; null preserves prior confirmed normalized state while explicit empty confirms absence. `leagues.roster_bundle_fetched_at` records the latest fully validated users-and-rosters collection published for the shared league. Shared league users, rosters, memberships, annotations, and removals advance only when the incoming complete bundle is at least as fresh as that watermark, so an older collection cannot resurrect a resource that a newer collection proved absent. Per-row freshness checks remain defense in depth.

Roster ownership resolution is account/league state on `fantasy_account_leagues`, with paired `roster_ownership_status` and `roster_ownership_observed_at`. The status is `owned`, `not_owned`, `unresolved`, or null when never evaluated. Resolution reads the current canonical shared rosters at the league roster-bundle watermark. A preserved `fantasy_account_rosters` row under `unresolved` remains historical account state, not current confirmed ownership. Current owned-roster and holdings reads require the matching account/league status to be `owned`.

The browser authorization path is `auth user → user_fantasy_accounts → fantasy account → fantasy_account_leagues → league`. Browser roles receive read-only, RLS-scoped access. Provider data is written only through reviewed service-only RPCs; `service_role` has no direct provider-table CRUD.

The canonical player catalog is globally readable to an authenticated app user after the application confirms a tracked Sleeper account. It is not owned by one fantasy account. Global catalog-run status is browser-readable only through explicitly granted safe columns. Its `triggered_by_user_id` records server-only audit and run-ownership state and is not browser-selectable; source freshness and active-run uniqueness are global to Sleeper/NFL/players.

## Planned fantasy-data grains

- `league_standing_snapshots`: one league + season + scoring period or snapshot time + roster. It preserves source or versioned standings when immutable facts alone cannot reproduce provider and commissioner rules.

## Invariants

- Shared Sleeper resources are stored once.
- Sleeper player IDs are primary canonical identity inputs; secondary IDs never auto-merge players.
- A removed primary mapping is retained and reactivated if the exact Sleeper ID returns.
- Current player profiles advance only for an equal or newer profile fetch observation.
- Team defenses are canonical entities, while sparse valid source rows remain explicit unknown entities.
- Canonical-entity counts include retained historical rows even after their primary Sleeper mapping is removed.
- Active-player counts include only active individual player entities with an active primary Sleeper/NFL mapping.
- Current team-defense counts include only team-defense entities with an active primary Sleeper/NFL mapping and do not depend on the optional provider active field.
- Optional display fields reject original ASCII control characters before trimming supported outer whitespace.
- Sleeper search rank is source search metadata, never fantasy rank or ADP.
- The global full player map is fetched at most once per successful rolling 24-hour window.
- Concurrent first creation of a shared resource reuses one canonical row.
- Shared-resource locks are acquired in deterministic canonical-key order.
- Older provider observations never overwrite newer shared current representations.
- Complete mutable collections use a collection-level watermark because per-row timestamps cannot protect the absence of a row.
- Auth users and provider identities remain separate concepts.
- Provider plus external user ID is canonical; usernames are mutable.
- A user may have at most one primary fantasy-account link.
- Browser sessions cannot create fantasy accounts or links.
- User ownership is represented through associations.
- League discovery never implies roster ownership.
- One tracked account may have at most one active roster ownership association in one league.
- Shared rosters and memberships contain no app-user ownership.
- Every roster membership references both a canonical player and its exact source identity mapping.
- Exact roster source arrays remain stored beside normalized current memberships.
- Current shared roster-domain reads require an active account-to-league discovery association.
- Active source and starter membership orders are unique within each roster.
- Current keeper state never substitutes for immutable completed-draft keeper history.
- Roster import validates every expected league before private staging and publishes the exact staged scope atomically.
- Only exact `players` source arrays define current roster membership; annotation arrays only preserve or clear current flags and order.
- Repeated exact `"0"` starter placeholders remain source facts and never create canonical player identities.
- Valid exact unmapped roster references create sparse source-marked canonical identities rather than being discarded.
- A null co-owner source state is unresolved and cannot prove that prior account ownership ended.
- Roster ownership status and observation time are paired on each account/league association; current ownership analytics require status `owned`.
- Preserved ownership history for an `unresolved` association is excluded from current owned-roster and holdings reads.
- Source-null roster arrays render as not reported, while explicit empty arrays render as confirmed zero.
- Membership annotation source state is validated per starter, reserve, taxi, and keeper field and renders as yes, no, or not reported.
- Every league-user source object must provide an exact `league_id` matching the requested canonical league before normalization; provider avatar IDs remain exact rather than display-trimmed.
- Roster import never updates `fantasy_accounts.last_synced_at`.
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
- Player catalog refresh never updates `fantasy_accounts.last_synced_at`.
- Best-ball starter and bench labels do not affect exposure.
- Best-ball exposure counts every current `roster_players` membership while preserving source starter, reserve, taxi, and keeper facts.
- Drafted exposure comes from immutable `draft_picks`; weekly lineup history comes from `matchup_player_points`; acquisitions, drops, and trades come from transaction facts.
- Current mutable state and historical facts use separate grains.
- Historical standings are reproducible from immutable facts or stored as source/versioned snapshots; provider-only ranking rules and commissioner adjustments are not discarded.
- Historical facts preserve period-specific player ID, position, NFL-team, and scoring context rather than joining only to current player profiles.
- Player rankings require source, period, scoring context, and ranking type.
- Scoreboards use roster-week entries and per-player score lines.
- Generic entity, document, object, and record stores are prohibited.
