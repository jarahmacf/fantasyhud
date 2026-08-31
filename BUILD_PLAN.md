# Build plan

Every milestone is implemented and audited separately.

1. 001 Repository foundation
2. 002 Supabase and Vercel Git-connected foundation
3. 003 Authentication and account identity foundation
4. 004 Connect canonical Sleeper account identity
5. 005 Core fantasy data architecture
6. 006 Current-season league discovery
7. 007 Rosters and canonical player catalog
8. 008 Drafts and complete boards
9. 009 First real portfolio reconciliation
10. 010 Player exposure
11. 011 NFL-team exposure
12. 012 Draft-capital analytics
13. 013 Stack and co-holding analytics
14. 014 Core Overview
15. 015 Players screen
16. 016 Player detail
17. 017 Market ADP as an independently verified data project
18. 018 In-season matchup command center

Task 002 establishes local Supabase migrations, pgTAP, generated types, typed client factories, GitHub Actions database checks, and Git-connected Supabase development and Vercel hosting. Product tables and authentication begin in Task 003.

Task 003 adds email/password SSR authentication, profiles, shared fantasy-account identity, and read-only browser access.

Task 004 resolves a submitted Sleeper username server-side, stores or reuses the canonical Sleeper user ID, atomically creates or reuses the app-user connection, and displays the connected identity. It imports no league or portfolio data.

Task 005 establishes shared provider-season state, canonical leagues, account-to-league discovery associations, sync-run observability, indexed RLS, and the long-term architecture contract. It imports no leagues. Task 006 is the first provider-data discovery milestone and remains incomplete.
