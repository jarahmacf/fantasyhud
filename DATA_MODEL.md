# Conceptual data model

This document names future domain entities and invariants only. It does not define SQL, migrations, production schemas, or production types.

## Entities

- **App user:** A person who uses FANTASY HUD.
- **Fantasy account:** One shared provider identity keyed by provider and external user ID.
- **User-to-fantasy-account link:** An app user's tracked association to a shared fantasy account.
- **League:** A shared fantasy competition from a provider.
- **Account-to-league membership:** The association between a connected account and a league.
- **Roster:** A team roster within a league.
- **Player:** A provider-identified football player.
- **Draft:** A draft associated with a league or provider context.
- **Account-to-draft membership:** The association between a connected account and a draft.
- **Complete draft board:** The full ordered set of selections from every drafter.
- **Draft pick:** One selection at an exact position in a draft.
- **Matchup:** A scoring comparison for a roster and period.
- **Sync run:** One traceable attempt to import or reconcile provider data.

## Invariants

- Shared Sleeper resources are stored once.
- Auth users and provider identities remain separate concepts.
- Provider plus external user ID is canonical; usernames are mutable.
- A user may have at most one primary fantasy-account link.
- Browser sessions cannot create fantasy accounts or links.
- User ownership is represented through associations.
- Complete draft boards include every drafter’s picks.
- Pick ownership is derived, not stored as a universal boolean.
- One league may have multiple drafts.
- Provider IDs remain strings.
- Best-ball starter and bench labels do not affect exposure.
