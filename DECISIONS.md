# Decision log

This log is append-only. New decisions are added as new rows; prior entries are not rewritten.

| Date       | Decision                                             | Reason                                                                                                   | Status   |
| ---------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------- |
| 2026-08-30 | Clean rebuild; legacy repository not copied          | Prevent legacy code and assumptions from entering the new foundation                                     | Accepted |
| 2026-08-30 | Next.js App Router                                   | Use the current file-system application model                                                            | Accepted |
| 2026-08-30 | TypeScript strict mode                               | Make unsafe states visible during development                                                            | Accepted |
| 2026-08-30 | Tailwind CSS and shadcn/ui                           | Establish a small, composable UI baseline                                                                | Accepted |
| 2026-08-30 | Use the ShadcnStore reference selectively under MIT  | Adopt useful visual patterns without importing template scope                                            | Accepted |
| 2026-08-30 | Dark-only initial shell                              | Match the intended product language while keeping Task 001 focused                                       | Accepted |
| 2026-08-30 | Exclude the theme customizer                         | Keep appearance intentional and avoid unnecessary state                                                  | Accepted |
| 2026-08-30 | Vitest for unit tests                                | Provide fast component-level verification                                                                | Accepted |
| 2026-08-30 | Playwright for browser tests                         | Verify the rendered application in Chromium                                                              | Accepted |
| 2026-08-30 | GitHub is the source of truth                        | Keep code, history, and automated checks together                                                        | Accepted |
| 2026-08-30 | Defer the backend                                    | Task 001 is limited to the frontend and engineering baseline                                             | Accepted |
| 2026-08-30 | Use small independently audited tasks                | Keep changes directly reviewable                                                                         | Accepted |
| 2026-08-30 | Compilation alone never proves completion            | Completion requires all specified quality gates                                                          | Accepted |
| 2026-08-30 | Supabase for backend infrastructure                  | Support local-first Postgres migrations, pgTAP, and typed clients                                        | Accepted |
| 2026-08-30 | Direct Supabase project ownership                    | Keep project control outside the Vercel Marketplace                                                      | Accepted |
| 2026-08-30 | Migrations are the database source of truth          | Make schema history reviewable and reproducible                                                          | Accepted |
| 2026-08-30 | Platform Git integrations deploy                     | Let Vercel and Supabase deploy from GitHub without duplicate CI paths                                    | Accepted |
| 2026-08-30 | GitHub Actions verifies but does not deploy          | Keep CI credential-free and separate validation from deployment                                          | Accepted |
| 2026-08-30 | Defer database preview branches                      | The active Supabase free plan does not support them                                                      | Accepted |
| 2026-08-30 | ShadcnStore dashboard is canonical visual base       | Keep implementation details anchored to the supplied reference                                           | Accepted |
| 2026-08-30 | Direct MIT-licensed adaptation is preferred          | Preserve exact structure and spacing instead of approximating them                                       | Accepted |
| 2026-08-30 | Neutral dark tokens replace custom blue theme        | Match the reference and reserve chromatic color for semantic meaning                                     | Accepted |
| 2026-08-30 | Visual regression screenshots are required           | Make fidelity changes reviewable and detect unintentional layout drift                                   | Accepted |
| 2026-08-30 | Email/password authentication first                  | Establish the smallest production-shaped authentication boundary                                         | Accepted |
| 2026-08-30 | Google OAuth deferred                                | Keep provider setup outside the initial authentication foundation                                        | Accepted |
| 2026-08-30 | SSR cookie sessions with Next.js Proxy               | Keep Supabase identity available and refreshed on client and server                                      | Accepted |
| 2026-08-30 | Claims protect server routes                         | Validate signed identity rather than trusting cookie session payloads                                    | Accepted |
| 2026-08-30 | Hosted email confirmation enabled                    | Require ownership of email addresses in the internal-alpha environment                                   | Accepted |
| 2026-08-30 | Development Supabase serves internal-alpha hosting   | Avoid premature production infrastructure before external users                                          | Accepted |
| 2026-08-30 | Fantasy accounts are shared external identities      | Store each provider identity once across app users                                                       | Accepted |
| 2026-08-30 | Browser cannot create account links                  | Reserve identity mutation for a later validated server-only operation                                    | Accepted |
| 2026-08-30 | No placeholder fantasy-account records               | Persist only provider identities that have actually been resolved                                        | Accepted |
| 2026-08-30 | Sleeper user ID is canonical                         | Usernames can change and cannot safely identify a shared account                                         | Accepted |
| 2026-08-30 | Sleeper lookup is server-only                        | Keep the provider request and canonical response outside browser code                                    | Accepted |
| 2026-08-30 | One atomic service-only connection RPC               | Preserve shared identity, idempotency, and primary-link invariants                                       | Accepted |
| 2026-08-30 | Connection is not ownership proof or synchronization | Sleeper's public read-only API authenticates neither ownership nor sync                                  | Accepted |
| 2026-08-30 | Shared league resources are stored once              | Multiple tracked accounts can reach one provider league without duplicating source state                 | Accepted |
| 2026-08-30 | League discovery is separate from roster ownership   | A user-leagues response reports visibility but does not identify the owned roster                        | Accepted |
| 2026-08-30 | Best ball and dynasty are independent dimensions     | A league may use both contexts simultaneously                                                            | Accepted |
| 2026-08-30 | Exact provider configuration is preserved            | Derived filters must not discard source settings, scoring, roster positions, or metadata                 | Accepted |
| 2026-08-30 | Mutable state and historical facts are separate      | Current profiles and status may change while picks, matchups, transactions, and snapshots retain history | Accepted |
| 2026-08-30 | Sync observability precedes queue orchestration      | Run lifecycle and sanitized outcomes are needed before item queues or schedulers are justified           | Accepted |
| 2026-08-30 | Player rankings require source and scoring context   | A rank without source, period, type, and scoring context is ambiguous                                    | Accepted |
| 2026-08-30 | Scoreboards use roster-week and player-week grains   | Detailed historical scoreboards require both entry totals and per-player score lines                     | Accepted |
| 2026-08-30 | No generic entity or document store                  | Reviewed relational grains preserve keys, authorization, and history semantics                           | Accepted |
| 2026-08-31 | Provider-data mutation uses reviewed RPCs            | Service credentials should execute narrow validated operations rather than receive direct table CRUD     | Accepted |
| 2026-08-31 | Discovery removal follows last observation           | A removal timestamp before the final positive observation is internally inconsistent                     | Accepted |
| 2026-08-31 | Roster membership has an explicit future grain       | Current holdings require a relational membership distinct from drafts, lineups, and transactions         | Accepted |
| 2026-08-31 | Historical standings have an explicit future grain   | Provider rules and commissioner adjustments may not be reproducible from current state alone             | Accepted |
| 2026-08-31 | Historical player context is period-specific         | Present-day team and position cannot rewrite draft, scoring, transaction, statistic, or rank facts       | Accepted |
| 2026-08-31 | Protected running operations require stale recovery  | A uniqueness guard without bounded recovery can permanently block later work                             | Accepted |
| 2026-08-31 | Cross-provider associations are invalid              | Account, league, and synchronization identity must remain within one provider boundary                   | Accepted |
| 2026-08-31 | Provider state selects the active league season      | Calendar time cannot safely substitute for Sleeper's current league-season context                       | Accepted |
| 2026-08-31 | League collections validate before reconciliation    | One malformed or incomplete response must not remove previously observed leagues                         | Accepted |
| 2026-08-31 | Fetch time and provider update time stay distinct    | Sleeper publishes no reliable league-level update time                                                   | Accepted |
| 2026-08-31 | Current-season discovery is one atomic RPC lifecycle | State, shared leagues, associations, removals, and run outcome must agree transactionally                | Accepted |
| 2026-08-31 | Current-season reads use provider season scope       | Historical associations and attempts must not be presented as the resolved current season                | Accepted |
| 2026-08-31 | Shared current state is monotonic by fetch time      | A slower older response cannot regress a newer provider or league representation                         | Accepted |
| 2026-08-31 | Shared creation and locking are concurrency-safe     | Conflict-safe insert-or-load and canonical key order prevent identity races and inconsistent lock order  | Accepted |
| 2026-08-31 | Provider display labels may trim outer whitespace    | Human-readable labels may contain insignificant padding; canonical IDs and enum-like values remain exact | Accepted |
| 2026-08-31 | Canonical players use Sleeper primary IDs            | Exact Sleeper map keys provide stable source identity without relying on mutable profile fields          | Accepted |
| 2026-08-31 | Team defenses are canonical catalog entities         | Sleeper publishes DEF identities in the same full NFL player resource                                    | Accepted |
| 2026-08-31 | Sparse valid source entities remain explicit         | Missing optional profile data must not erase a valid exact Sleeper identity                              | Accepted |
| 2026-08-31 | Player profiles are monotonic by fetch time          | An older catalog completion cannot regress newer mutable current data                                    | Accepted |
| 2026-08-31 | Player catalog freshness is global for 24 hours      | The full shared map should be requested no more than once per rolling successful day                     | Accepted |
| 2026-08-31 | Catalog publication uses private bounded staging     | Partial batches must never become public domain truth                                                    | Accepted |
| 2026-08-31 | Catalog size guards fail closed                      | Initial and relative floors prevent malformed or truncated maps from wiping identity state               | Accepted |
| 2026-08-31 | Secondary player IDs never auto-merge                | Ambiguity and historical corrections require explicit review rather than silent identity reassignment    | Accepted |
| 2026-08-31 | Sleeper search rank is not fantasy rank              | Source search metadata lacks scoring, period, and ranking-type context                                   | Accepted |
| 2026-08-31 | Player catalog refresh is not portfolio sync         | A global prerequisite does not prove account rosters, drafts, matchups, or complete reconciliation       | Accepted |
| 2026-08-31 | Catalog-run ownership state is server-only           | Triggering Auth user IDs are audit context, not globally browser-readable product status                 | Accepted |
| 2026-08-31 | Active player counts require primary identity        | Player type, active state, and an active primary Sleeper mapping define current players                  | Accepted |
| 2026-08-31 | Display controls fail optional-field normalization   | Original ASCII control characters must produce null plus warning instead of being silently trimmed       | Accepted |
| 2026-08-31 | Database contracts use exact pgTAP plans             | Missing or extra assertions must fail each database contract file                                        | Accepted |
| 2026-08-31 | Player catalog responses have measured headroom      | The measured response left 2.33% under the old cap; 25 MB streaming preserves fail-closed behavior       | Accepted |
| 2026-09-01 | Roster ownership uses an explicit association        | League discovery cannot prove which league-local roster belongs to a tracked fantasy account             | Accepted |
| 2026-09-01 | Exact roster arrays and memberships coexist          | Source fidelity and current queryability require atomic exact and normalized representations             | Accepted |
| 2026-09-01 | Roster membership proves both player identities      | Canonical player and exact source mapping must agree for every current holding                           | Accepted |
| 2026-09-01 | Shared league roster context is league-readable      | Future standings need reachable-league rosters while tracked-account ownership stays private             | Accepted |
| 2026-09-01 | Sync trigger UUIDs are server-only                   | Shared tracked accounts must not reveal another app user's Auth identifier                               | Accepted |
| 2026-09-01 | Source null and explicit empty remain distinct       | Filling absent roster arrays with empty arrays destroys exact provider semantics                         | Accepted |
| 2026-09-01 | Keeper meanings remain time-scoped                   | Mutable current roster keeper state cannot replace immutable completed-draft keeper history              | Accepted |
| 2026-09-01 | Current shared roster reads require active discovery | Removed discovery history must not keep authorizing shared current league context                        | Accepted |
| 2026-09-01 | Roster current state is collection-monotonic         | An older overlapping account import cannot regress newer shared users, rosters, or memberships           | Accepted |
| 2026-09-01 | Active membership order is roster-unique             | Exact source and starter positions need unambiguous normalized ordering with reuse after removal         | Accepted |
| 2026-09-01 | Overlapping roster imports are a database gate       | Conflict-safe creation, deterministic locks, freshness, and ownership isolation require simultaneous SQL | Accepted |
| 2026-09-01 | Roster runs freeze the current league scope          | League additions or removals during a run must not silently change the source collection                 | Accepted |
| 2026-09-01 | Complete roster collections publish atomically       | One missing, malformed, or failed league must preserve all prior public roster state                     | Accepted |
| 2026-09-01 | Null annotations preserve and empty arrays clear     | Source-null is unknown while an explicit empty array confirms the absence of current annotation state    | Accepted |
| 2026-09-01 | Players arrays alone define current membership       | Starter, reserve, taxi, and keeper arrays annotate holdings but cannot create them                       | Accepted |
| 2026-09-01 | Exact zero starter values are placeholders           | Controlled source evidence found repeated `"0"` sentinels and no other unexplained starter value         | Accepted |
| 2026-09-01 | Valid unmapped holdings create sparse identities     | Catalog lag must not discard an exact current holding or invent profile data                             | Accepted |
| 2026-09-01 | Active holdings protect exact player mappings        | Catalog absence cannot retire a mapping while current roster membership still depends on it              | Accepted |
| 2026-09-01 | Ambiguous co-owner absence yields partial state      | A null co-owner collection cannot safely prove that prior account-specific ownership ended               | Accepted |
| 2026-09-01 | Roster import is not portfolio synchronization       | Roster state alone proves no draft, transaction, matchup, or complete-account reconciliation             | Accepted |
| 2026-09-01 | Roster bundles use a per-league watermark            | Per-row freshness cannot protect resources that a newer complete collection proves absent                | Accepted |
| 2026-09-01 | Account-league ownership resolution is explicit      | Current canonical rosters must distinguish owned, confirmed not-owned, unresolved, and never evaluated   | Accepted |
| 2026-09-01 | Unresolved ownership history is not current          | Preserving an association for history must not present it as a confirmed owned roster or current holding | Accepted |
| 2026-09-01 | Current ownership analytics require owned status     | Active ownership rows alone cannot communicate the certainty of the latest account-league observation    | Accepted |
| 2026-09-01 | Roster source certainty remains visible              | Null source arrays mean not reported, while explicit empty arrays confirm zero                           | Accepted |
| 2026-09-01 | Membership annotations are tri-state                 | Validated source-state metadata separates yes, no, and not reported from retained last-confirmed flags   | Accepted |
| 2026-09-01 | League-user source identity is exact                 | Each source league ID must match the requested canonical league before normalized publication            | Accepted |
| 2026-09-01 | Provider avatar IDs are not display labels           | Exact identifier padding and controls must fail instead of being normalized away                         | Accepted |
| 2026-09-01 | Exact scoring settings are immutable identity        | Derived labels cannot replace or mutate the authoritative exact provider scoring object                  | Accepted |
| 2026-09-01 | League format is separate from scoring identity      | Lineup and other draft-relevant dimensions must not change scoring-rule identity                         | Accepted |
| 2026-09-01 | Context classification is versioned                  | Classification changes create new identities rather than silently reinterpreting existing context rows   | Accepted |
| 2026-09-01 | ADP is a contextual metric, not a player field       | Average pick depends on cohort, context, time, eligibility, methodology, and sample size                 | Accepted |
| 2026-09-01 | Context fallback is never silent                     | A broader cohort must be explicitly requested or displayed with its match level                          | Accepted |
| 2026-09-01 | Internal network samples are not platform-wide       | Imported canonical drafts across FANTASY HUD users do not represent all Sleeper drafts                   | Accepted |
| 2026-09-01 | Draft records are deduplicated before aggregation    | One canonical provider draft must contribute at most one observation across app users                    | Accepted |
| 2026-09-01 | At-time comparisons prohibit future information      | A pick-value result must use only information available at or before that draft or pick                  | Accepted |
| 2026-09-01 | Pick-level comparators are leave-one-out             | The subject draft must not determine the benchmark used to score its own pick                            | Accepted |
| 2026-09-01 | Auctions use AAV rather than pick ADP                | Auction amounts and snake or linear pick positions are different measurement domains                     | Accepted |
| 2026-09-01 | Keeper and player-pool eligibility are explicit      | Keeper, rookie, startup, redraft, supplemental, and unknown cohorts cannot be blended implicitly         | Accepted |
| 2026-09-04 | Positional ADP rank is context-derived               | Rank cohort-specific ADP within one versioned position group instead of requiring provider labels        | Accepted |
| 2026-09-04 | Raw statistics and fantasy scoring stay separate     | Reuse source facts across exact scoring contexts instead of duplicating one stat line per league         | Accepted |
| 2026-09-04 | Season rankings are typed and context-specific       | A rank requires scoring context, period, ranking type, position method, source, and engine version       | Accepted |
| 2026-09-04 | Rank delta is not a cross-position aggregate         | RB, WR, QB, TE, and IDP rank differences are not one additive portfolio unit                             | Accepted |
| 2026-09-04 | Cross-position performance methods are versioned     | Comparable capital, percentile, and expected-points methods must disclose their version and sample       | Accepted |
| 2026-09-04 | Team draft performance uses team at draft            | Immutable NFL-team-at-draft context preserves original capital allocation when current teams change      | Accepted |
| 2026-09-04 | Consumer ranking surfaces are not API contracts      | Consumer UI and undocumented endpoints do not establish an authorized player-statistics source           | Accepted |
| 2026-09-04 | Material scoring rules stay compatibility-distinct   | Semantic routing may normalize only reviewed no-ops and must retain every material rule                  | Accepted |
| 2026-09-04 | Exact league settings define exact format identity   | Reusable immutable rows cannot retain whichever differing source settings happened to arrive first       | Accepted |
| 2026-09-04 | Lineup compatibility uses complete slot counts       | Equal roster size cannot substitute for WR, TE, FLEX, bench, reserve, QB, IDP, or unknown-token demand   | Accepted |
| 2026-09-04 | Quarterback topology and IDP are independent         | One-QB, Superflex, and two-QB structures remain meaningful whether defensive slots are also present      | Accepted |
| 2026-09-04 | One league time accepts one format context           | A contradictory same-time observation must fail and roll back instead of creating ambiguous history      | Accepted |
| 2026-09-04 | Immutable context inserts fully recompute            | Every exact identity and derived routing field must agree with the authoritative source before insertion | Accepted |
| 2026-09-04 | Unknown context keys narrow compatibility            | Conservative exact fallback prevents unreviewed scoring or league settings from creating false matches   | Accepted |
