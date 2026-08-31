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
- **Player:** A provider-identified football player.
- **Draft:** A draft associated with a league or provider context.
- **Account-to-draft membership:** The association between a connected account and a draft.
- **Complete draft board:** The full ordered set of selections from every drafter.
- **Draft pick:** One selection at an exact position in a draft.
- **Matchup:** A scoring comparison for a roster and period.
- **Sync run:** One traceable attempt to import or reconcile provider data.

## Implemented fantasy-data grains

- `provider_season_states`: one latest state row per provider and sport.
- `leagues`: one shared league per provider and exact external league ID.
- `fantasy_account_leagues`: one discovery association per fantasy account and shared league.
- `sync_runs`: one tracked fantasy account, scope, and attempt.

The browser authorization path is `auth user → user_fantasy_accounts → fantasy account → fantasy_account_leagues → league`. Provider data is server-written; browser roles receive read-only, RLS-scoped access.

## Invariants

- Shared Sleeper resources are stored once.
- Auth users and provider identities remain separate concepts.
- Provider plus external user ID is canonical; usernames are mutable.
- A user may have at most one primary fantasy-account link.
- Browser sessions cannot create fantasy accounts or links.
- User ownership is represented through associations.
- League discovery never implies roster ownership.
- Removing one account-to-league discovery association never deletes the shared league.
- Dynasty, keeper/redraft, best ball, superflex, IDP, and broad scoring are independent context dimensions.
- Exact provider settings, scoring settings, roster positions, and metadata remain available beside derived dimensions.
- Complete draft boards include every drafter’s picks.
- Pick ownership is derived, not stored as a universal boolean.
- One league may have multiple drafts.
- Provider IDs remain strings.
- Sleeper usernames are mutable; Sleeper `user_id` is the canonical account key.
- Resolving an identity creates no league, roster, player, draft, or synchronization data.
- Best-ball starter and bench labels do not affect exposure.
- Current mutable state and historical facts use separate grains.
- Player rankings require source, period, scoring context, and ranking type.
- Scoreboards use roster-week entries and per-player score lines.
- Generic entity, document, object, and record stores are prohibited.
