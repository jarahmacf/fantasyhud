# Price-implied positional rank

The domain engine in `src/lib/draft-value` converts draft price into a positional market benchmark and compares that fixed benchmark with an outcome rank. `/draft-value` provides an explicitly manual calculator with optional device-local saving. This release creates no database tables, draft import, ADP/AAV feed, raw-stat import, scoring engine, scheduled tracking, or server-persisted benchmarks. Task 008B remains unstarted.

## What the benchmark means

The benchmark answers: **what positional rank did the price paid buy in this market?** It is distinct from the selected player's own market rank and is not a calibrated prediction of finishing rank.

For a 12-team draft, `3.10` is overall pick 34. An illustrative RB curve with RB10 at pick 30, RB11 at pick 34, and RB12 at pick 39 gives:

| Fact                                  | Value                  |
| ------------------------------------- | ---------------------- |
| Actual purchase                       | 3.10 / overall pick 34 |
| Fixed price-implied rank              | RB11                   |
| Player's own market rank, if supplied | RB14                   |
| Through Week 6 outcome                | RB7                    |
| Week 6 surplus                        | +4                     |
| Through Week 7 outcome                | RB18                   |
| Week 7 surplus                        | -7                     |

`price_rank_surplus = price_implied_position_rank - outcome_position_rank`. Positive values mean better positional performance than the price benchmark. Raw rank differences cannot be summed across positions or scoring contexts as portfolio alpha.

## Price curve

- Round and selection are parsed from text, never a decimal. Overall pick is `(round - 1) * teams + selection`. Selection means chronological selection in that round, including snake drafts; it is not an owner's original draft slot.
- Pick prices increase as positional rank worsens. Auction prices decrease as positional rank worsens.
- Equal market prices use the midpoint of their positional ordinal ranks. Between distinct prices, interpolate linearly: `rankA + (paid - priceA) / (priceB - priceA) * (rankB - rankA)`.
- Preserve full calculation precision; round only display values. A price outside the observed range produces an unavailable result, never extrapolation or endpoint clamping.
- Curves require finite prices and consecutive positive positional ranks. Partial slices are supported without renumbering. Canonical market players are unique and ties are deterministic.

## Frozen acquisition contract

`freezePriceBenchmark` accepts a purchase and a positional market snapshot from a trusted adapter. It validates exact scoring, league format, draft environment, season/type, player pool, historical position and position-group version, team count, and price kind. Partial or unknown context is unavailable rather than silently broadened. The purchase requires an explicit non-keeper state; null is not equivalent to false.

Market provenance includes source, snapshot and revision identities, availability time, observation window, sample size, eligibility policy version, and minimum sample rules. Both availability and the window end must precede or equal acquisition time. Portfolio and FantasyHUD samples require unique canonical draft IDs consistent with sample size; the subject draft must be excluded. External markets require an explicit subject-exclusion assertion from their adapter. Caller assertions are not evidence of provider authorization or independent source verification.

The minimum of two drafts is only a technical floor. It does not approve any network privacy/publication threshold. Per-player observation requirements apply to every supplied player; the engine refuses a thin curve rather than dropping players and silently renumbering it. A player's own market row may be absent without invalidating the price benchmark.

The returned purchase, market and result are copied and deeply frozen, including methodology version `price-implied-position-rank/v1`. In-memory freezing is not durable historical persistence. A future storage adapter must preserve canonical acquisition identity, context identity, eligible market revision/cutoff and calculation version as an append-only snapshot. Corrections need explicit new versions; refreshing today's ADP must not rewrite the acquisition benchmark.

## Auction capital

Auction inputs use paid amount divided by the known initial team budget. AAV curve values use the same normalization. Budget, scoring, roster structure, keeper treatment, minimum bid and other material environment rules must match through the exact context identities. Nomination number is not purchase capital. Unknown budgets do not yield an inferred percentage.

For example, a $200 budget with AAV values RB10=$40, RB11=$30 and RB12=$20 values a $25 purchase at RB11.5. AAV and pick-ADP curves never share units or a calculation cohort.

## Outcome ranking contract

`rankPositionPerformance` accepts a complete, already-scored eligible universe. It does not turn raw football statistics into custom-scoring points. Every snapshot preserves source/revision/as-of, exact scoring context, scoring-engine version, position-group version, season/type, through-week and finality. An incomplete universe or any unscored rule blocks ranking. Player identity is unique, points are finite (negative points are valid), and games played must be consistent with the period.

Total points and points per game are distinct ranking types. PPG requires an explicit minimum-games rule and excludes players who do not qualify. Outcome ties use competition ranking (`1, 1, 3`), separate from price-curve tie midpoints. A universe with no games played produces no outcome rank.

Comparison requires the same exact scoring context, season/type and position-group version, and rejects an outcome snapshot that predates purchase. Changed position and missing PPG qualification yield explicit unavailable outcomes. Each comparison remains through a particular week or explicitly final; an in-season result is never presented as a final finish.

## Manual product boundary

The screen starts empty. **Load example** explicitly inserts invented inputs to explain the calculation. A manually entered scoring/format label is not proof that a market or outcome matches an exact league context. The UI does not claim to derive ranks from imported rosters or verify an external source.

Freezing locks price, curve and context inputs. Weekly entries retain separate total-points and PPG comparisons, including PPG thresholds; updating the same week/type/threshold replaces only that manual entry. A new calculation is an explicit action.

**Save on this device** writes one calculation to browser storage under the current account's key. It requires an explicit click, does not sync across devices, and is not a server draft record. Restore validates a bounded, versioned payload and recomputes every derived result from saved inputs. Unsaved edits are lost on reload; a new calculation does not silently overwrite an earlier saved one. Existing workspace-access rules apply to the page, including temporary read-only access.

## Verification and next integration

Unit and component tests cover pick conversion, interpolation, ties, out-of-range handling, auction units, strict context/time/provenance gates, frozen inputs, ranking qualification, manual validation, serialization, and account-scoped save/restore. Browser tests exercise no-login access, fixed weekly benchmarks, auction/PPG behavior, and desktop/mobile layouts; normal mode also verifies the route redirects unauthenticated visitors.

Automatic portfolio tracking still requires the reviewed Task 008B draft import, an authorized contextual ADP/AAV source, an authorized raw-stat source with canonical mapping and exact custom-scoring coverage, server benchmark persistence, and scheduled outcome snapshots. The pure engines are reusable boundaries for those adapters, not a claim that ingestion already exists.
