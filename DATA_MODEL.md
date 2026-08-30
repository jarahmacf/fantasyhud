# Conceptual data model

This document names future domain entities and invariants only. It does not define SQL, migrations, production schemas, or production types.

## Entities

- **App user:** A person who uses FANTASY HUD.
- **Connected fantasy account:** A provider account associated with an app user.
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
- User ownership is represented through associations.
- Complete draft boards include every drafter’s picks.
- Pick ownership is derived, not stored as a universal boolean.
- One league may have multiple drafts.
- Provider IDs remain strings.
- Best-ball starter and bench labels do not affect exposure.
