# Hosting foundation

Vercel hosts FANTASY HUD through the project named `fantasyhud`, connected directly to `jarahmacf/fantasyhud` through Vercel's Git integration.

## Deployment model

- `main` is the production branch.
- Pull requests and feature branches create Preview Deployments.
- Pushes or merges to `main` create Production Deployments.
- The framework is Next.js and the root directory is the repository root.

Vercel's Git integration owns deployment. GitHub Actions runs quality and local database checks only; it does not contain a deployment pipeline. No custom domain is configured.

## Public Supabase environment

Vercel Development, Preview, and Production environments receive only:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
NEXT_PUBLIC_SITE_URL
```

`NEXT_PUBLIC_SITE_URL` is `https://fantasyhud.vercel.app` in Production; Preview may use the validated Vercel hostname fallback. The directly owned `fantasyhud-development` Supabase project temporarily serves all three environments for internal alpha. A separate production project is required before external users.

Database passwords, service-role or secret keys, direct Postgres URLs, CLI access tokens, and Vercel tokens must never be added to Vercel's public environment or committed to the repository.
