# Build plan

Every milestone is implemented and audited separately.

1. 001 Repository foundation
2. 002 Supabase and Vercel Git-connected foundation
3. 003 Authentication and account identity foundation
4. 004 Connect canonical Sleeper account identity
5. 005 Import leagues
6. 006 Import owned rosters and roster players
7. 007 Import drafts and complete boards
8. 008 Validate the first real Sleeper portfolio
9. 009 Player exposure
10. 010 NFL-team exposure
11. 011 Draft-capital analytics
12. 012 Stack analytics
13. 013 Core Overview
14. 014 Players screen
15. 015 Player detail
16. 016 Market ADP as an independently verified data project
17. 017 In-season matchup command center

Task 002 establishes local Supabase migrations, pgTAP, generated types, typed client factories, GitHub Actions database checks, and Git-connected Supabase development and Vercel hosting. Product tables and authentication begin in Task 003.

Task 003 adds email/password SSR authentication, profiles, shared fantasy-account identity, and read-only browser access.

Task 004 resolves a submitted Sleeper username server-side, stores or reuses the canonical Sleeper user ID, atomically creates or reuses the app-user connection, and displays the connected identity. It imports no league or portfolio data. Task 005 remains the first league-import milestone.
