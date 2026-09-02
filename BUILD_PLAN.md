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
10. 008 Drafts and complete boards
11. 009 First real portfolio reconciliation
12. 010 Player exposure
13. 011 NFL-team exposure
14. 012 Draft-capital analytics
15. 013 Stack and co-holding analytics
16. 014 Core Overview
17. 015 Players screen
18. 016 Player detail
19. 017 Market ADP as an independently verified data project
20. 018 In-season matchup command center

Task 002 establishes local Supabase migrations, pgTAP, generated types, typed client factories, GitHub Actions database checks, and Git-connected Supabase development and Vercel hosting. Product tables and authentication begin in Task 003.

Task 003 adds email/password SSR authentication, profiles, shared fantasy-account identity, and read-only browser access.

Task 004 resolves a submitted Sleeper username server-side, stores or reuses the canonical Sleeper user ID, atomically creates or reuses the app-user connection, and displays the connected identity. It imports no league or portfolio data.

Task 005 establishes shared provider-season state, canonical leagues, account-to-league discovery associations, sync-run observability, indexed RLS, and the long-term architecture contract. It imports no leagues.

Task 005.1 corrects the deployed discovery-removal timestamp invariant, removes direct service-role CRUD from provider-data tables, and hardens the future architecture contracts.

Task 006 and its display-name normalization correction are deployed. They add current-season Sleeper state and league discovery, full-collection validation, atomic reconciliation, sync-run lifecycle functions, a real connected dashboard, and deterministic unit/browser/database coverage.

Task 007A and its response-headroom correction are deployed and production-verified.

Task 007B.1 establishes the empty relational roster domain, exact source-array preservation, account-to-roster ownership, canonical-player membership integrity, indexed RLS, safe sync-run status grants, and the `roster_sync` scope. It makes no provider request and adds no product UI.

Task 007B.2 is implemented on a focused draft branch. It adds complete current-season Sleeper league-user and roster import, ownership and membership reconciliation, and the first roster product surface. It is not marked complete until its pull request is audited and merged and the controlled Production canary passes. Task 008 has not begun.
