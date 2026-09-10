# Single-user kickoff tracker

The additive `/tracker` screen is scoped to the existing @jarahmacf fantasy account and reads Sleeper through a server API. All previous screens, database records, migrations, and canonical import workflows remain present. PR 17's draft importer was merged and its migration verified on the linked FantasyHUD database.

## PickWorth adaptation

The uploaded PickWorth source supplies the league-scored approach and the price-versus-finish definitions. Snake/linear draft-cost rank follows positional selection order; auction cost rank follows source-reported dollars and uses competition ties. Scored rank also uses competition ties. Rank gain/loss is cost rank minus scored rank; points above price compare observed points with the realized score occupying the cost-implied rank. These are draft-pool measures for each league, not market ADP, full-NFL ranks, forecasts, or financial returns.

Every included board is fetched in full. Nullable keeper flags remain unknown. Historical player labels come from pick metadata. All league scoring settings are retained for display; points come from Sleeper's league matchup values rather than a default-PPR rescoring shortcut. Missing player-week records are not zeroes and suppress position-pool rank comparisons. The current week remains provisional, including commissioner-adjusted team totals.

PickWorth's bundled 2024–2025 ADP snapshots are not 2026 prices. No current market feed was available during this implementation. The existing manual ADP/auction curve calculator remains available without changes.

## Runtime and persistence

- Server-controlled canonical account; an unrelated workspace cannot select another user or provider league.
- Opaque league selection tokens resolve only within complete current-season discovery.
- Bounded source responses, four-league overview concurrency, two browser workers for loading all boards, and a two-minute server cache.
- The overview refreshes while the page is visible. Full draft portfolio refresh is an explicit action. This is not a background scheduler.
- No database writes or admin client in this live view. Canonical imports remain separate. Sleeper is the historical matchup source; JSON export gives a dated snapshot. Next's response cache is not an archival database.
- The public temporary workspace remains read-only. This is the already-authorized single-user prototype, not private multi-user hosting.
- Source errors keep prior displayed observations with a refresh-failure label. A fully accepted collection alone determines the current list.

## Verification

The initial live read returned 66 current-season leagues, 66 owned/co-owned rosters, 250 unique held players, and no league refresh failures. One complete snake board returned 264 picks, 22 owned selections, and week-one matchup history. A live auction board returned 260 picks and 26 owned selections, including source-reported dollar amounts and tied positional cost ranks. Zero scores correctly left performance ranks pending. A transient draft read failed and succeeded on retry, exercising conservative error handling.

The initial checkpoint passed both GitHub Actions jobs, including 41 Vitest files / 361 tests, database contracts, authenticated and temporary-access browser tests, and concurrency/load checks. The final refresh-retention regression adds one unit test. Local TypeScript, ESLint, and all 19 tracker tests passed for that correction. The browser fixture verifies whole-portfolio loading, current player exposure, draft ranks and gains/losses, and unknown keeper state. Its 1440 × 1000 desktop and 390 × 844 mobile screenshots were visually inspected; the tables scroll horizontally within the narrow viewport. No real Sleeper requests run in CI. Final release checks run on the PR head before merge.

Sources: [Sleeper documented matchups and drafts](https://docs.sleeper.com/); user-provided PickWorth source archive. Live `players_points` and `metadata.amount` fields are explicitly source-reported extensions; they are not presented as a documented full-NFL statistics service.
