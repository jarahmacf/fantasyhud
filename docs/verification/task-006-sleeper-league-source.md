# Task 006 Sleeper source verification

Status: **DEFERRED TO CONTROLLED POST-MERGE CANARY**

Checked on 2026-08-31. This document is deliberately sanitized.

## Official contract reviewed

Sleeper's official API documentation defines these read-only, token-free endpoint patterns:

```text
GET /v1/state/nfl
GET /v1/user/{user_id}/leagues/nfl/{season}
```

The documented state response includes season and league-season context. The documented user-leagues collection includes league identity, sport, season, name, status, season type, total rosters, settings, scoring settings, roster positions, avatar, previous league identity, and other provider metadata. The account request uses the stored canonical Sleeper `user_id` because usernames can change.

Sleeper's documentation also states that the API is free for noncommercial use. Commercial use is a product licensing dependency, not an engineering assumption.

## Live audit result

The signed-in hosted preflight and database checks succeeded, but the Codex host could not retain a live source response. No uncontrolled read was used to manufacture evidence, and the unavailable live read is not treated as a code failure.

Therefore the following live facts remain unverified:

- actual state field population and nullability at the observation time
- actual current-season collection shape for the connected identity
- representative live setting, scoring, and roster-position shapes
- actual empty-versus-nonempty collection status

Implementation and CI fixtures are based on Sleeper's official documented contract only. They contain fabricated IDs and names. Changed or malformed source shapes fail closed during full application validation and again inside the atomic persistence RPC.

The first Production import after merge is the controlled live verification. Sign in, import the connected account's current-season leagues once, confirm the run succeeds, and immediately compare real Sleeper settings, scoring settings, and roster positions with the stored exact fields and derived management, best-ball, superflex, IDP, and scoring classifications. Confirm the resolved provider season, current-season count, canonical league uniqueness, account associations, and bounded sync result counts. Record only sanitized field names and aggregate findings; do not commit identifiers or payloads.

## Data-exposure boundary

This document and repository contain no canonical real Sleeper user ID, real league ID, league name, avatar ID, draft ID, settings object, scoring object, roster-position array, or raw source payload.
