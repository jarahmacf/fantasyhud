# Build plan

Every milestone is implemented and audited separately.

1. 001 Repository foundation
2. 002 Supabase and Vercel Git-connected foundation
3. 003 Authentication and account identity foundation
4. 004 Connect canonical Sleeper account identity
5. 005 Core fantasy data architecture
6. 006 Current-season league discovery
7. 007A Canonical Sleeper NFL player catalog
8. 007B.1 Roster domain architecture
9. 007B.2 Current-season Sleeper roster import
10. 008A.1 Scoring, format, and performance context architecture
11. 008A.2 Draft domain architecture
12. 008B Current-season drafts and complete boards
13. 009 First real portfolio reconciliation
14. 010 Context-aware player exposure
15. 011 Context-aware NFL-team exposure
16. 012 Draft-capital analytics
17. 013A Player-statistics source and scoring-engine architecture
18. 013B Weekly statistics, context-specific fantasy scoring, and season rankings
19. 014 Draft-capital versus season-performance analytics
20. 015 Stack and co-holding analytics
21. 016 Core Overview
22. 017 Players screen
23. 018 Player detail with dynamic context metrics
24. 019 Independently licensed market ADP
25. 020 In-season matchup command center

Task 002 establishes local Supabase migrations, pgTAP, generated types, typed client factories, GitHub Actions database checks, and Git-connected Supabase development and Vercel hosting. Product tables and authentication begin in Task 003.

Task 003 adds email/password SSR authentication, profiles, shared fantasy-account identity, and read-only browser access.

Task 004 resolves a submitted Sleeper username server-side, stores or reuses the canonical Sleeper user ID, atomically creates or reuses the app-user connection, and displays the connected identity. It imports no league or portfolio data.

Task 005 establishes shared provider-season state, canonical leagues, account-to-league discovery associations, sync-run observability, indexed RLS, and the long-term architecture contract. It imports no leagues.

Task 005.1 corrects the deployed discovery-removal timestamp invariant, removes direct service-role CRUD from provider-data tables, and hardens the future architecture contracts.

Task 006 and its display-name normalization correction are deployed. They add current-season Sleeper state and league discovery, full-collection validation, atomic reconciliation, sync-run lifecycle functions, a real connected dashboard, and deterministic unit/browser/database coverage.

Task 007A and its response-headroom correction are deployed and production-verified.

Task 007B.1 establishes the empty relational roster domain, exact source-array preservation, account-to-roster ownership, canonical-player membership integrity, indexed RLS, safe sync-run status grants, and the `roster_sync` scope. It makes no provider request and adds no product UI.

Task 007B.2 is deployed and production-verified. It adds complete current-season Sleeper league-user and roster import, ownership and membership reconciliation, and the first roster product surface.

Task 008A.1 is the current focused, undeployed draft-branch work. Its in-scope correction hardens the same unmerged migration with material-rule-preserving semantic scoring compatibility, exact league-settings identity, count-sensitive lineup compatibility, independent quarterback and IDP dimensions, fully recomputed immutable inserts, and one accepted format context per league observation time. It also defines future context-aware ADP and performance-versus-draft-capital contracts. It implements no draft import, statistics source, scoring engine, ranking, performance metric, or product UI. It is not complete until correction review, merge, and hosted verification pass. Task 008A.2 and Task 008B have not begun.
