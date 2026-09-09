# Draft domain and environment architecture

Task 008A.2 establishes the relational contract for shared drafts, normalized draft slots, explicit tracked-account participation, complete selection boards, and conservative draft-environment identity. It is architecture-only: it adds no Sleeper request, import lifecycle, Server Action, route, navigation item, metric, or product UI. PR 17 implements the subsequent draft-import lifecycle described below; it remains under verification and is not deployed.

## Official future source boundary

Task 008B may use only Sleeper's documented, read-only, token-free endpoints:

```text
GET /league/{league_id}/drafts
GET /draft/{draft_id}
GET /draft/{draft_id}/picks
GET /user/{canonical_user_id}/drafts/nfl/{season}
```

One league may return several drafts. League draft lists are complete collections, not proof that a league has one current draft. Draft detail may carry exact `draft_order` and `slot_to_roster_id` maps. Complete picks carry every selection, including exact string IDs and nullable or empty participant values. The canonical account key is the stored Sleeper user ID, never the mutable username.

`GET /draft/{draft_id}/traded_picks` is explicitly deferred. Traded-pick rights and transaction history are separate from the immutable completed selection board.

## Collection freshness

Complete-collection absence is protected at three independent scopes:

- `leagues.draft_collection_fetched_at`, `draft_collection_count`, and `draft_collection_fingerprint` describe the latest fully validated complete league draft-list collection.
- `fantasy_account_draft_collections` stores the latest complete canonical-user draft collection for one tracked fantasy account, sport, and season.
- each `drafts` row carries the accepted board collection state, watermark, counts, fingerprint version, fingerprint, and optional finalization time.

Null league collection fields mean not observed. A fully validated empty collection has count zero and a valid empty-set fingerprint. League and account collection fingerprints use the fixed version-one canonicalization defined by this contract and therefore do not need per-row fingerprint-version columns; the board fingerprint is versioned separately on each draft. A source failure is never an empty collection. Task 008B must advance each relevant collection state atomically and must not let an older inclusion or absence resurrect state superseded by a newer complete collection.

## Canonical grains

### `fantasy_account_draft_collections`

Grain: one tracked fantasy account + sport + season + latest accepted complete user-drafts collection. The provider resolves through the canonical fantasy account rather than being duplicated. Exact source evidence remains server-only; authenticated users receive only the safe collection projection for accounts they track.

### `drafts`

Grain: one shared provider draft, unique by `(provider, external_draft_id)`. A draft can be league-linked, standalone, or conservatively unknown. Shared drafts never carry app-user ownership.

A league-linked draft must match its league's provider, sport, and season. One league may have zero, one, or many drafts. Display names are not identities and are not unique. Exact settings, metadata, creators, draft order, and slot-to-roster maps remain separate from normalized children and preserve null versus explicit empty source state.

### `draft_slots`

Grain: one exact board seat or column per `(draft_id, draft_slot)`. A slot may contain several exact provider user IDs because co-managed seats are valid. The normalized user-ID array is sorted deterministically because the source draft-order map is unordered. Source participant IDs, external roster IDs, and raw evidence remain server-only.

Canonical `roster_id` resolution is optional. When present for a league-linked draft, it must identify a roster from the same league and agree with the exact external roster ID. Standalone and unresolved assignments do not require a canonical roster.

### `fantasy_account_drafts`

Grain: one tracked fantasy account's explicit participation resolution for one shared draft. Participation is tri-state:

```text
confirmed       -> exactly one real draft slot
not_participant -> no slot
unresolved      -> no slot
```

Only `confirmed` belongs to the account's portfolio draft set. League discovery, current roster ownership, player presence, draft labels, and app-user identity do not independently prove participation. A finalized confirmed relationship cannot be changed to negative or unresolved, moved to another slot, removed, or deleted without a future reviewed correction workflow.

### `draft_picks`

Grain: one selection at one exact overall `pick_no` in one draft. The table stores the complete board, not only the connected account's selections. `(draft_id, pick_no)` is canonical board identity; round plus slot is indexed but is not assumed unique across every supported draft type.

Every pick references both one canonical `players` row and the exact `player_external_ids` mapping used by the source. Names, teams, and positions never identify a pick. A valid non-placeholder ID missing from mapping history may later create one sparse reference-only canonical identity under the same reviewed rules as roster import; verified placeholders never create players.

## Exact source maps and normalized slots

`source_creators`, `source_draft_order`, and `source_slot_to_roster_id` are exact server-only source facts. Null remains distinct from an explicit empty array or object. Creator order is preserved. The draft-order helper validates exact user-to-slot mappings while permitting several users on one slot. The slot-to-roster helper accepts only canonical positive decimal slot keys and bounded integer roster IDs. Normalized slot user arrays are bounded, exact, sorted under `C` collation, and unique.

The owner-only helpers and classifier live in `app_private`, are immutable where required, use fixed `pg_catalog` search paths, and revoke execution from `PUBLIC`, `anon`, `authenticated`, and `service_role`.

## Historical format context

Scoring context, league format context, and draft environment are separate layers:

```text
scoring context
-> exact scoring rules and semantic compatibility

league format context
-> scoring context + exact lineup and league settings

draft environment
-> selected league format context
   + exact draft type and settings
   + player pool and capital type
   + team and round counts
   + historical resolution quality
```

Each league-linked draft may reference the exact accepted `league_format_observations` row for the same league, format context, and observation time.

- `exact` requires a real same-league accepted observation at or before the draft's start or creation anchor.
- `partial` requires a real same-league observation but may represent later or incomplete evidence.
- `unknown` requires null format-context and observation references.

A current league pointer observed only after a historical draft is never relabeled exact. Draft metadata `scoring_type` never replaces exact league scoring settings.

## Draft-environment identity

Every draft stores a positive environment version, exact settings fingerprint, exact environment fingerprint, conservative compatibility key, quality, draft-pool type, and capital type.

Version one recognizes only exact source draft types `snake`, `linear`, and `auction`; everything else remains `unknown`. Snake and linear drafts use `overall_pick`; auctions use `auction_value`; unknown types use `unknown`. Player pool is explicit as `all_players`, `rookies`, `veterans`, `supplemental`, or `unknown` and is never inferred from a draft name.

The exact fingerprint includes provider, sport, version, exact or null format identity, context status, exact source draft type, pool, capital type, exact settings fingerprint, team count, round count, and pick timer. The compatibility key remains conservative and includes the FANTASY HUD semantic format key or null, context status, type family, pool, capital type, team and round counts, and exact settings fingerprint. Version one intentionally does not normalize away draft-setting differences.

Environment quality is `exact`, `partial`, or `unknown`. Exact quality requires exact historical format resolution, known type and capital families, a known pool, valid dimensions, and valid exact settings. Partial and unknown environments are never silently included in exact cohorts.

## Historical player context

Each pick may preserve the draft-time display name, entity type, primary position, all fantasy positions, NFL team, status, injury status, optional selection time, nullable keeper truth, optional auction amount, and bounded exact player metadata. Present-day `players` fields never rewrite those historical facts.

Fantasy positions preserve null for not captured, an explicit empty array for captured-as-empty, and ordered unique values when present. Position grouping remains a versioned analytic method rather than a stored rank group.

`is_keeper` is tri-state source truth: true is confirmed keeper, false is confirmed non-keeper, and null means unreported. Mutable `roster_players.is_keeper` is a different current-roster fact. Auction amount is nullable architectural headroom and may be populated only from an audited numeric source field; it is never inferred and is never compared directly with overall pick.

## Board lifecycle and immutability

Board state is `not_fetched`, `mutable`, or `finalized`.

```text
pre_draft or drafting
-> newer complete picks observation
-> mutable board

source status complete
+ complete valid detail and picks
+ resolved normalized slots
-> compute canonical versioned board fingerprint
-> publish children
-> finalize atomically
```

Finalization requires complete source status, matching active slot and pick counts, active slot references for every active pick, a correct keeper summary, a finite watermark, and a valid versioned fingerprint. A finalized board cannot regress. Slot and pick insert, update, and delete are database-rejected after finalization. Core draft identity, historical context, environment, exact settings and maps, board counts, timestamps, fingerprint, and keeper summary are immutable after finalization; only explicitly documented observation bookkeeping may advance.

The version-one board fingerprint must cover exact draft identity, active normalized slots, exact participant and roster assignments, picks ordered by pick number, exact player identity, round, slot, participant and roster source state, keeper tri-state, auction source state, and a bounded historical-metadata fingerprint. Replaying the same finalized fingerprint is idempotent. A different fingerprint fails closed and requires a future reviewed correction workflow.

## Authorization and safe projections

All five public draft-domain tables have RLS enabled. `anon` cannot read. Authenticated users receive only explicit column-level `SELECT` grants. Browser roles and `service_role` have no direct insert, update, or delete; `service_role` also has no direct select. Future writes cross only reviewed fixed-search-path lifecycle RPCs.

Account collections and participation are visible through:

```text
auth user
-> user_fantasy_accounts
-> tracked fantasy account
-> account collection or participation
```

A shared draft, its slots, and its complete safe board are visible only through an active `confirmed` participation row for an account the user tracks. `unresolved`, `not_participant`, and removed participation remain account-readable evidence but do not expose the shared board. This is an intentional privacy tightening over mere relationship existence. Confirmed historical access survives later current-roster or league-state changes unless the participation relationship itself is withdrawn. Every RLS existence path has a supporting index.

Safe browser projections exclude source creators, draft-order and roster maps, slot user IDs, picked-by provider IDs, external roster IDs, raw source/player metadata, context evidence, and trigger-user UUIDs. Product surfaces use normalized league, roster, slot, account, and player labels.

## Synchronization handoff to Task 008B

Task 008A.2 adds only the `draft_sync` value and its independent one-running-run-per-account index to `sync_runs`. Existing `league_discovery` and `roster_sync` scopes remain valid. No draft lifecycle function exists yet. `triggered_by_user_id` remains browser-inaccessible, and `fantasy_accounts.last_synced_at` remains reserved for Task 009 complete portfolio reconciliation.

Task 008B must freeze one account/provider/sport/season and exact active current-season league set; fetch every league's complete draft list; fetch the canonical account's complete season user-drafts list once; then fetch, validate, and publish exact detail and complete picks for every included draft. It must preserve every league draft, validate all collections before publication, advance league and account collection state atomically, apply draft-detail and board-collection monotonicity, and reject stale inclusion or absence.

Work and locks follow exact league ID, exact draft ID, draft slot, then pick number. Canonical shared draft creation is conflict-safe. Concurrent overlapping-account imports must converge on one shared draft and one board, with deterministic hard-timeout integration coverage and a current 30-league load test. Running attempts require explicit heartbeat and bounded stale-run recovery in Task 008B.

Participation evidence is evaluated conservatively in this order: exact account ID in draft order, consistent exact picked-by attribution, exact slot-to-roster mapping to a confirmed account roster, and complete user-drafts inclusion. One consistent slot confirms participation; complete negative evidence yields not-participant; missing, contradictory, or incomplete evidence remains unresolved; more than one resolved slot fails closed.

Historical context resolves from the latest accepted same-league format observation at or before the draft anchor when structural settings agree. A later best available context is partial. No safe context is unknown. Draft pool remains unknown unless audited source fields establish it. Every selection on every included board is imported, while source maps remain separate from slots and traded picks remain deferred.

Task 008B finalizes only a source-complete board. It must reject a changed finalized fingerprint, never rewrite finalized confirmed participation, never make a player for a verified placeholder, and create a sparse exact player identity only when necessary. It must make no claim that draft import alone completes portfolio synchronization.

## Future ADP eligibility

Ordinary pick-ADP requires a finalized board, exact environment quality, snake or linear type, overall-pick capital, a known cohort-matched player pool, explicit context matching, keeper exclusion by default, and canonical draft deduplication. Auction drafts route to average auction value. Partial or unknown environments require a disclosed fallback or are excluded. ADP, average pick, rank, value, exposure, and performance remain derived, versioned results and never become mutable player or pick properties.

## Current boundary

Task 008A.2 added the architecture schema, validation, protection, indexed RLS, safe projections, database contracts, generated types, and this documentation. That task imported zero drafts and made no provider call, private draft stage, lifecycle RPC, Server Action, draft route, navigation item, card, table, portfolio count, ADP, rank, scoring result, or performance result.

The subsequent price-implied-rank feature adds pure calculation engines and an explicitly manual `/draft-value` screen, documented in `PRICE_IMPLIED_RANK.md`. It adds no SQL migration or automatic draft ingestion. PR 17 adds authenticated draft import and persisted current-season status. No-login workspace access remains read-only. Copy distinguishes an unimported, partial, successful, or unavailable draft import.

## Draft import implementation (PR 17)

The documented four-endpoint collector freezes canonical account identity, provider season, and active league IDs. It validates the entire union before private staging and atomic publication. Explicit heartbeats and a 15-minute stale-run recovery bound running attempts. Responses are bounded to 10 MB each and 40 MB per collection; publication accepts at most 1,000 boards, with bounded per-board and aggregate staging sizes.

Only accepted league collections restore league inclusion. User history outside the frozen league set cannot clear a league absence marker. Finalized identical boards replay without replacing children; changed finalized content fails pending a reviewed correction workflow. Unknown pick keeper flags stay null, auction amounts remain unknown pending source evidence, and unresolved participation or mutable boards produce a partial run. Import never updates the full-portfolio synchronization timestamp.

Verification includes isolated pgTAP contracts, mocked authenticated browser import and refresh, overlapping-account publication, stale collection rejection, and 30-league / 7,200-pick load checks. These are required gates, not an assertion that all currently pass. See `docs/verification/draft-weekly-source.md` for source coverage and weekly automation limitations.
