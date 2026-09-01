# Task 007A Audit Correction — Privacy, Catalog Semantics, and Validation Integrity

# Codex execution setting

Use **High reasoning effort** for this entire correction.

Do not downgrade to Medium or Low reasoning.

This is a focused audit correction to the existing Task 007A pull request. Do not begin Task 007B.

---

Repository:

`jarahmacf/fantasyhud`

Existing pull request:

```text
PR #9
branch: task/007a-canonical-player-catalog
current head before correction: d8c77bb1c889671acebc8c92c0b894285e4b0217
```

Continue on the existing PR branch and update PR #9.

Do not create another pull request.

Do not merge PR #9.

Keep it in draft until this correction is audited.

Because the Task 007A migration is unmerged and undeployed, amend the existing migration:

```text
supabase/migrations/20260831235900_canonical_sleeper_player_catalog.sql
```

Do not create a second corrective migration.

Read and obey:

- `AGENTS.md`
- `PLAYER_CATALOG.md`
- `FANTASY_DATA_ARCHITECTURE.md`
- `SYNC_ARCHITECTURE.md`
- `VISUAL_SYSTEM.md`
- `supabase/migrations/20260831235900_canonical_sleeper_player_catalog.sql`
- `supabase/tests/database/006_player_catalog.test.sql`
- `src/lib/sleeper/player-normalization.ts`
- `src/lib/sleeper/player-normalization.test.ts`
- `src/lib/players/dashboard.server.ts`
- `src/components/players/player-catalog-summary.tsx`
- `e2e/auth/player-catalog.spec.ts`
- `scripts/test-player-catalog-load.mjs`

---

# Audit result

Task 007A is broadly strong:

- Canonical player and external-ID grains are appropriate.
- Full-map freshness is global.
- Staging is bounded and private.
- Publication is atomic.
- Primary Sleeper identity history is retained.
- Secondary IDs do not auto-merge canonical players.
- The 5,000-record load test passes.
- CI and Vercel Preview are green.

Four issues remain before merge:

1. `provider_catalog_runs.triggered_by_user_id` is browser-readable to every authenticated app user even though it is an audit-only field.
2. `active_players` currently counts every active entity, including team defenses and sparse unknown entities.
3. Optional display fields silently trim leading or trailing ASCII control characters instead of returning null plus a normalization warning.
4. The Task 007A pgTAP file uses `no_plan()` despite the task requiring an exact assertion plan.

Preserve the rest of Task 007A unless a compilation or test update is directly required by these corrections.

---

# Correction 1 — Hide the triggering app-user ID from browser reads

## Problem

`public.provider_catalog_runs` contains `triggered_by_user_id`, but the migration grants table-wide `SELECT` to `authenticated` and uses a global authenticated select policy.

That makes every catalog run's triggering Auth UUID selectable by every authenticated user.

The field is needed internally for run ownership and audit. It is not global product status and must not be browser-readable.

## Required grant model

Keep the column.

Replace the table-wide authenticated `SELECT` grant on `provider_catalog_runs` with explicit column-level `SELECT` grants for only:

```text
id
provider
sport
catalog
status
progress_current
progress_total
source_fetched_at
source_record_count
source_bytes
result_counts
error_summary
started_at
finished_at
created_at
updated_at
```

Do not grant authenticated access to:

```text
triggered_by_user_id
```

The existing authenticated row policy may remain global because the exposed fields are shared sanitized catalog status.

Add a column comment stating that `triggered_by_user_id` is server-only audit/run-ownership state and is intentionally excluded from browser grants.

Do not:

- remove lifecycle ownership checks
- expose the UUID through a view
- add a public audit route
- grant direct `service_role` table CRUD

## Required tests

Add pgTAP coverage proving:

1. Authenticated has `SELECT` on every safe column.
2. Authenticated has no `SELECT` on `triggered_by_user_id`.
3. Authenticated can query a safe status projection.
4. Authenticated selection of `triggered_by_user_id` fails with insufficient privilege.
5. `anon` still cannot read the table.
6. Browser roles still cannot mutate it.
7. Lifecycle functions continue to use the private audit field internally.

In authenticated E2E or a focused authenticated integration test:

- query `provider_catalog_runs.status` successfully
- attempt to query `provider_catalog_runs.triggered_by_user_id`
- assert that the second query returns a permission error and no UUID data

Do not surface that database error in product UI.

---

# Correction 2 — Define and calculate Active players precisely

## Problem

The completion function and dashboard currently count `active = true` across all entity types while the UI labels the result `Active players`.

That includes `team_defense` and `unknown` entities.

## Required definitions

### Canonical entities

```text
all retained rows in public.players
```

These may include historical canonical rows whose primary Sleeper mapping was later removed.

### Active players

```text
players.entity_type = player
and players.active = true
and the player has an active primary Sleeper/NFL external-ID mapping
```

This excludes defenses, unknown entities, and canonical rows whose primary Sleeper mapping was removed.

### Team defenses

```text
players.entity_type = team_defense
and the player has an active primary Sleeper/NFL external-ID mapping
```

Do not require the provider's optional `active` field for the team-defense count.

### External ID mappings

Keep the existing definition:

```text
all mappings where removed_at is null
```

## Database result correction

In `complete_sleeper_player_catalog_sync`:

- calculate `active_players` only from staged records where `entity_type = player` and `active = true`
- keep `team_defenses` as the staged current-catalog count of `entity_type = team_defense`
- keep `unknown_entities` as the staged current-catalog count of `entity_type = unknown`

Do not count a defense or unknown entity as an active player.

## Dashboard correction

Update `loadPlayerCatalogDashboard` so:

- active-player count inner-joins an active primary Sleeper/NFL mapping and filters `entity_type = player` and `active = true`
- team-defense count inner-joins an active primary Sleeper/NFL mapping and filters `entity_type = team_defense`
- canonical-entity count remains all retained canonical player rows
- preview behavior remains unchanged unless query reuse requires a small refactor

The active-primary uniqueness invariant must prevent count multiplication.

## Copy correction

Use concise truthful details:

```text
Canonical entities
→ Retained canonical identities across catalog history

Active players
→ Current active individual player entities

Team defenses
→ Current Sleeper DEF identities
```

## Required test corrections

For the current 600-record authenticated fixture:

- active individual players must exclude the active defense sentinel
- active individual players must exclude the active sparse unknown sentinel
- update the expected UI count accordingly
- explicitly prove those sentinels do not inflate Active players

For the 5,000-record load test:

- indices `0..4499` are provider-active
- every 100th record is a team defense
- active provider entities = 4,500
- active team defenses = 45
- active individual players = 4,455

Assert completion reports:

```text
active_players = 4455
team_defenses = 50
```

Assert the dashboard-style current-mapping query returns:

```text
4455 active individual players
50 current team defenses
```

Add pgTAP fixtures proving:

- an active individual player counts
- an active team defense does not count as active player
- an active unknown entity does not count as active player
- a player with a removed primary Sleeper mapping does not count as current active player
- a team defense with a removed primary mapping does not count as current team defense

---

# Correction 3 — Reject ASCII control characters before display trimming

## Problem

`normalizeDisplay` currently trims first and then tests the normalized value for ASCII control characters.

JavaScript `trim()` removes boundary tabs, newlines, and carriage returns, so a source value such as `"\tPlayer Name\n"` is silently accepted without a warning.

The Task 007A contract requires a control-character-bearing optional display value to become null plus a bounded warning.

## Required behavior

For every optional display field handled by `normalizeDisplay`:

1. If absent, null, or the exact empty string, return null without warning.
2. If non-string, return null and add the field warning.
3. If the original source string contains any ASCII control character, return null and add the field warning.
4. Otherwise trim ordinary outer whitespace using `String.prototype.trim()`.
5. If the normalized result is blank, return null.
6. If the normalized result exceeds the field limit, return null and add the field warning.
7. Preserve internal whitespace and case.

Keep canonical IDs and token fields unchanged and strict.

Do not accept a control character merely because it occurs at the beginning or end.

## Required tests

Add table-driven tests for:

- leading tab
- trailing tab
- leading newline
- trailing newline
- carriage return
- null byte
- DEL
- interior control character

Prove the affected field becomes null and its field name appears in `source_metadata.normalization_warning_fields`.

Also prove:

- ordinary spaces around a display value still trim
- Unicode outer whitespace supported by `String.prototype.trim()` remains normalizable when it is not an ASCII control character
- internal repeated ordinary spaces remain preserved
- exact Sleeper IDs, tokens, and secondary IDs remain unchanged

No schema change is required for this correction.

---

# Correction 4 — Use an exact pgTAP plan

The Task 007A test currently begins with:

```sql
select no_plan();
```

Replace it with:

```sql
select plan(<exact assertion count>);
```

After adding the new assertions:

- count every assertion exactly
- set the exact plan
- retain `finish()`
- retain transaction rollback
- make missing or extra assertions fail the suite

Do not use pg_prove's observed count as a substitute for an explicit test-file plan.

---

# Correction 5 — Documentation and agent rules

Update:

- `PLAYER_CATALOG.md`
- `DATA_MODEL.md`
- `FANTASY_DATA_ARCHITECTURE.md`
- `DECISIONS.md`
- `AGENTS.md`
- PR #9 description

Document:

1. `triggered_by_user_id` is server-only audit state and is not browser-selectable.
2. Global catalog status is browser-readable only through a safe column projection.
3. Active players means current mapped individual players, not all active entities.
4. Team defenses and unknown entities are separate entity classes.
5. Retained canonical rows may outlive an active primary mapping.
6. Optional display fields reject original ASCII control characters before whitespace normalization.
7. Database contract suites use exact pgTAP plans.

Add agent rules:

```text
Never expose provider-run triggering Auth user IDs through global browser-readable status tables.
Never label all active catalog entities as active players; entity type and active primary mapping must be explicit.
Never silently trim ASCII control characters from provider display fields.
Every pgTAP contract file must use an exact assertion plan.
```

Append decisions; do not rewrite prior history.

---

# Verification

Run:

```bash
npm run typecheck
npm run lint
npm run format:check
npm run test
npm run build
npm run e2e
npm run e2e:auth
npm run check

npm run db:reset
npm run db:test
npm run db:types
npm run db:types:check
npm run db:check
npm run db:test:league-concurrency
npm run db:test:player-catalog-load
```

When the Codex host lacks Docker:

- do not claim local database execution passed
- require the real local-Supabase GitHub Actions database job to pass
- require the 5,000-record load test to pass there

Re-run the hosted rollback-only migration audit against the amended migration:

- all Task 007A pgTAP assertions pass
- the transaction rolls back
- no Task 007A table, helper, policy, function, trigger, or grant remains deployed afterward

Static verification:

- the existing unmerged Task 007A migration is amended
- no second migration is created
- no real Sleeper data is committed
- no real Sleeper request occurs in CI
- no direct service-role CRUD is added
- no roster, draft, matchup, ranking, or market table is added
- no source behavior is broadened beyond the display-control correction
- Task 007B remains unstarted

---

# Source control

Continue on:

```text
task/007a-canonical-player-catalog
```

Prefer amending the existing Task 007A commit and force-pushing with lease.

If amendment is unsafe, add exactly one focused correction commit:

```text
fix: harden player catalog privacy and semantics
```

Update existing draft PR #9.

Do not create another PR.

Do not merge it.

---

# Acceptance criteria

This correction is complete only when:

## Run privacy

- authenticated users can read safe catalog status columns
- authenticated users cannot read `triggered_by_user_id`
- an actual authenticated query proves the denial
- lifecycle ownership checks still work
- no Auth UUID is exposed in the UI or browser API projection

## Catalog semantics

- active players exclude team defenses
- active players exclude unknown entities
- active players require an active primary Sleeper mapping
- team-defense count requires an active primary Sleeper mapping
- canonical-entity count remains retained history
- completion and dashboard counts use the same documented meanings
- 600-record and 5,000-record tests use corrected counts

## Normalization

- ASCII controls are detected in the original display string
- control-bearing optional display values become null plus warning
- ordinary outer whitespace still trims
- internal spaces and case remain intact
- canonical IDs and token fields remain strict

## Test integrity

- Task 007A pgTAP uses an exact plan
- all assertions match the plan
- all existing tests remain green
- hosted rollback audit leaves no objects deployed

## Delivery

- PR #9 remains the only Task 007A PR
- PR #9 remains draft and unmerged
- branch remains focused
- Vercel Preview remains Ready
- GitHub Actions quality passes
- GitHub Actions database passes
- 5,000-record load test passes
- Task 007B has not begun

---

# Completion report

Return:

1. Updated PR URL
2. New head SHA
3. Commit strategy
4. Safe authenticated catalog-run columns
5. Proof `triggered_by_user_id` is browser-inaccessible
6. Active-player definition
7. Team-defense definition
8. Corrected 600-record expected counts
9. Corrected 5,000-record expected counts
10. Display-control normalization change
11. New normalization tests
12. Exact Task 007A pgTAP plan count
13. Total database assertion count
14. Hosted rollback audit result
15. Unit/component test count
16. Public browser result
17. Authenticated browser result
18. League concurrency result
19. Player-catalog load result and duration
20. GitHub Actions quality result
21. GitHub Actions database result
22. Vercel Preview result
23. Confirmation no second migration was added
24. Confirmation no real Sleeper request occurred in CI
25. Confirmation no Task 007B work began
26. Every remaining limitation

Do not begin Task 007B.
