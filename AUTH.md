# Authentication

FANTASY HUD uses Supabase email/password authentication with cookie-based SSR sessions. Google OAuth and other identity providers are intentionally deferred.

## Application flow

- `/auth/sign-up` validates display name, email, and matching passwords before calling Supabase Auth.
- Hosted sign-up requires email confirmation. Local Supabase keeps confirmation disabled so the authenticated browser suite needs no external email service.
- `/auth/confirm` accepts either a valid email `token_hash` and type or a PKCE code, exchanges it once, stores the resulting session in cookies, and redirects without retaining secret query parameters.
- `/auth/sign-in` uses `signInWithPassword` and accepts only a validated internal `next` path.
- `/auth/forgot-password` returns a generic response regardless of whether the email exists.
- A valid confirmation or recovery session is required before `/auth/update-password` can call `updateUser`.
- Sign-out is a Server Action POST mutation. It validates claims when practical, clears the Supabase session, and redirects to sign in.

Auth forms use React 19 Server Actions and `useActionState`. They expose pending states, accessible labels and errors, and password-manager-compatible autocomplete values. Supabase calls remain outside visual components.

## SSR session boundary

`src/proxy.ts` delegates to `src/lib/supabase/proxy.ts`. The Proxy creates an `@supabase/ssr` server client, calls `getClaims()`, and writes refreshed request and response cookies together with Supabase's no-cache headers. Static assets and image optimization are excluded by the matcher.

Proxy refresh is not authorization. Protected Server Components and Server Actions validate signed claims again through `getCurrentAuthIdentity()` or `requireAuthIdentity()`. Server code never trusts `getSession()` for authorization and never returns access or refresh tokens.

There is no service-role or secret-key application client. Browser and SSR reads use the public project URL, publishable key, current user session, and RLS.

## Site and redirect URLs

The site origin resolver uses this priority:

1. `NEXT_PUBLIC_SITE_URL`
2. `NEXT_PUBLIC_VERCEL_URL` with `https://` added when needed
3. `http://localhost:3000`

Only HTTP(S) origins are accepted. Request Host headers are not redirect authorities. Auth callbacks are built only for allow-listed internal routes, and `next` parameters reject absolute, protocol-relative, backslash, control-character, malformed, and encoded external redirects.

## Hosted internal-alpha configuration

The `fantasyhud-development` Supabase project temporarily serves Vercel Development, Preview, and Production for internal alpha only. A separate production Supabase project is required before external users are invited.

Supabase Auth URL Configuration:

```text
Site URL: https://fantasyhud.vercel.app

Redirect URLs:
http://localhost:3000/**
http://127.0.0.1:3000/**
https://*-jdm17.vercel.app/**
```

Vercel environments use public values only:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
NEXT_PUBLIC_SITE_URL
```

Production sets `NEXT_PUBLIC_SITE_URL=https://fantasyhud.vercel.app`. No database password, service-role key, secret key, CLI token, or direct Postgres URL belongs in Vercel public environment.

Hosted email confirmation remains enabled. On 2026-08-30 the hosted Confirm sign up and Reset password templates were verified to use Supabase's active default `{{ .ConfirmationURL }}` links. The Free-plan dashboard requires custom SMTP before those templates can be edited, so no SMTP credentials or template secrets were added for this task.

For sign-up, the application passes `/auth/confirm` as the redirect target. For password recovery it passes `/auth/confirm?next=/auth/update-password`. Supabase verifies the default confirmation link and returns a one-time PKCE code to that endpoint. The route exchanges the code once, stores the cookie session, and sends confirmed sign-ups to onboarding or recovery sessions to the password-update form. The route also accepts the documented `token_hash` flow if custom templates are enabled later.

## Local verification

With Docker running:

```bash
npm run db:start
npm run db:reset
npm run db:test
npm run db:types:check
npm run e2e:auth
npm run db:stop
```

The auth runner reads local public values from `supabase status -o json`; it does not hardcode or print secrets. Mailpit captures local email if a manual confirmation flow is enabled.

## Post-merge hosted verification

Task 003 cannot be fully verified against hosted Auth until its migration reaches `main`. After merge:

1. Confirm migration `20260831030756_auth_account_identity.sql` appears in the `fantasyhud-development` migration history.
2. Confirm `profiles`, `fantasy_accounts`, and `user_fantasy_accounts` exist and RLS is enabled.
3. Confirm the Vercel Production deployment uses the merged commit and all three public environment variables.
4. Create one internal-alpha user through Production using a non-sensitive test identity.
5. Open the confirmation email and verify `/auth/confirm` ends at `/onboarding` without token or code parameters in the URL.
6. Confirm exactly one profile exists and no fantasy-account or link row was created.
7. Sign out, verify onboarding redirects to sign in, and sign in again.
8. Request a password reset, follow the recovery link, update the password, and confirm stale sessions are signed out.
9. Confirm no service secret is present in the deployment or browser bundle.

Until those steps pass after merge, hosted sign-up and recovery remain unverified.
