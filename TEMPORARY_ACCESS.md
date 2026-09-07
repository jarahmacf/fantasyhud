# Temporary workspace access

The owner explicitly requested removal of login on September 7, 2026 after repeated password-reset failures. FantasyHUD temporarily opens the existing `@jarahmacf` workspace without authentication. The same live league, roster, and player dashboard readers remain in use; this is not a static export or a fabricated signed-in identity.

## Access boundary

`app_private.temporary_workspace_access` is a private, RLS-enabled single-row configuration. Its migration enables only the previously approved canonical Sleeper account if that exact account already exists. Fresh databases remain private. `get_temporary_workspace()` returns only the selected account ID, provider, username, and display name; it accepts no client-supplied selector and has a fixed search path.

Anonymous access has explicit column grants and SELECT-only policies for the selected account's active league associations, reachable league display fields, confirmed owned rosters and memberships, and sanitized import status. The shared NFL player catalog remains available while the switch is enabled. Unresolved or removed ownership never becomes confirmed ownership. Private account links, Auth profiles, triggering Auth UUIDs, raw league/roster metadata, drafts, all mutation RPCs, and other accounts remain protected. Existing authenticated policies and direct service-role restrictions are unchanged.

The server uses the publishable key with session persistence, automatic refresh, and URL session detection disabled. It never supplies an Auth user ID or service secret for temporary reads. Existing cookies cannot select another workspace. The app hides account/import/sign-out controls, rejects import/account mutations before reading a user session, and redirects old Auth and onboarding destinations to the dashboard. The redirect explicitly removes inherited email-link fragments. Responses are not cached and are marked `noindex, nofollow`.

## Restore authentication

Disable the database switch using the authorized administrator interface:

```sql
update app_private.temporary_workspace_access set enabled = false;
```

This immediately removes anonymous row visibility and the public workspace context, restoring the existing authentication flow on subsequent requests. No schema reset, data rebuild, Auth account deletion, or roster reimport is needed. `FANTASYHUD_TEMPORARY_ACCESS=off` additionally opts an application environment out; it does **not** substitute for disabling the database switch and does not itself revoke direct anonymous Data API reads.

The email-link/reset defect is not represented as repaired. Before restoring required login, verify the actual hosted email callback and password update flow, including browser-fragment callbacks from the current Supabase email templates.

## Verification

The existing authenticated and public suites run with temporary access opted out. The new 40-assertion pgTAP contract verifies selected-account scope, excluded ownership, private columns, denied writes, and immediate revocation. The new isolated browser suite runs without a server secret or a login, using the same SQL fixture as that contract. It checks live leagues, rosters, player catalog, foundation navigation, hidden mutations, and every old Auth destination. Its runner accepts only local Supabase and disables the test switch afterward. GitHub integrations remain responsible for Vercel and Supabase deployment.
