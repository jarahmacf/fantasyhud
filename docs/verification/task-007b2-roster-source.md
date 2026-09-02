# Task 007B.2 Sleeper roster-source verification

Status: **CONTROLLED PRE-IMPLEMENTATION SOURCE AUDIT PASSED**

Checked on 2026-09-01. This document contains aggregate source-shape evidence only. It deliberately records no username, user ID, league ID, league name, roster ID, player ID, player name, raw JSON, credential, or secret. The generic literal starter placeholder `"0"` is not a real identity and is recorded because its exact behavior is material to validation.

## Official contract reviewed

[Sleeper's official API documentation](https://docs.sleeper.com/) defines these read-only, token-free endpoints:

```text
GET /v1/league/{league_id}/users
GET /v1/league/{league_id}/rosters
```

The documentation shows array responses, league-local integer roster IDs, exact text user and player IDs, ordered starter and player arrays, roster settings, owner identity, league-user display fields, optional team-name metadata, and commissioner state. Sleeper recommends remaining below 1,000 API calls per minute and requires a separate licensing discussion for commercial use.

The official examples do not fully specify co-owner, taxi, keeper, or null-versus-absent behavior. The controlled audit below establishes only the observed categories needed by this import; validation remains fail-closed for unexplained shapes.

## Collection method

- Active provider-resolved league season: 2026
- Active current-season leagues checked: 30
- Users endpoint requests: 30
- Rosters endpoint requests: 30
- Total source requests: 60
- Maximum source concurrency: four leagues
- Authentication or API token: none
- Raw responses committed or retained: none

Every endpoint returned an array. No array contained a null element. Every audited league produced both source collections.

## League-user findings

```text
leagues checked                            30
total user objects                        387
duplicate user IDs within a league          0
username present                            0
username absent                           387
metadata object                           387
metadata.team_name present                 35
is_owner null                             309
is_owner boolean                           78
is_owner true                              51
display values with outer whitespace        4
display values with ASCII controls           0
decoded payload range            1,452–7,860 bytes
```

Observed top-level field names were:

```text
avatar
display_name
is_bot
is_owner
league_id
metadata
settings
user_id
```

The absence of `username` in every observed league-user row is valid. Dedicated username persistence must therefore remain nullable, while exact `user_id` remains required identity. Human-readable display and team-name values may trim outer whitespace only after rejecting ASCII controls in the original source value.

The privacy-preserving one-pass aggregate did not retain separate presence/null counts for `avatar`, `display_name`, `is_bot`, or `settings`. It did retain the username, metadata, team-name, and commissioner counts above. Source values were still shape-validated during the pass, and none of the omitted optional aggregates affected an audit stop condition. This documentation gap remains a limitation of the retained aggregate rather than a reason to invent evidence or change the passing gate result.

## Roster findings

```text
total roster objects                         372
roster-count distribution     10×6, 12×21, 14×2, 32×1
owner_id non-null                            358
owner_id null                                 14
co_owners absent                               0
co_owners null                               371
co_owners explicit empty                       0
co_owners nonempty                             1
players absent                                 0
players nonempty                             306
players null                                  44
players explicit empty                        22
starters absent                                0
starters null                                  0
starters explicit empty                        0
starters nonempty                            372
reserve absent                                 0
reserve null                                 347
reserve nonempty                               3
reserve explicit empty                        22
taxi absent                                    0
taxi null                                    350
taxi nonempty                                  0
taxi explicit empty                           22
keepers absent                                 0
keepers null                                 350
keepers nonempty                               0
keepers explicit empty                        22
duplicate roster IDs within a league           0
duplicate real IDs within players              0
unsafe integer roster IDs                      0
decoded payload range              3,687–11,105 bytes
```

Observed top-level field names were:

```text
co_owners
keepers
league_id
metadata
owner_id
player_map
players
reserve
roster_id
settings
starters
taxi
```

Every roster `settings` value was an object. Roster metadata was null on 357 rows and an object on 15 rows.

The audit found 230 starter-array values outside the corresponding `players` array. Every one was the exact literal `"0"`. No other unexplained starter value existed, and no reserve, taxi, or keeper value lay outside `players`. The import therefore permits only repeated exact `"0"` starter placeholders, preserves them in the exact starter array, and excludes them from canonical player resolution and normalized membership. Every other unexplained annotation value fails closed.

## Ownership and identity findings

- The connected canonical account matched exactly one roster in every one of the 30 leagues.
- No league contained more than one ownership match.
- Owner identity has precedence over a co-owner match on the same roster.
- The audit observed 383 unique exact roster player references.
- A source-null co-owner array remains distinct from an explicit empty array so a future zero-match result can remain unresolved rather than asserting removal.

The one-pass privacy-preserving audit intentionally retained no player ID list, so it did not perform a post-request mapping-catalog cross-check. That check remains deferred to deterministic database coverage and the controlled post-merge canary. The completion path conflict-safely reuses or reactivates exact mappings and creates a sparse source-marked canonical reference only for a valid exact non-placeholder ID that remains unmapped.

## Audit gate result

No stop condition was observed:

- no non-array endpoint response
- no null array element
- no unsafe integer roster ID
- no duplicate real current player ID
- no unexplained non-player starter value
- no reserve, taxi, or keeper value outside `players`
- no league with multiple ownership matches
- no source type the deployed architecture cannot represent safely
- no normal payload near the two-megabyte normalized stage bound

Implementation may proceed against this observed contract while continuing to validate all source data fail-closed. The exact post-merge canary remains required before Task 008 begins.
