# Hosting foundation

Vercel hosts FANTASY HUD through the project named `fantasyhud`, connected directly to `jarahmacf/fantasyhud` through Vercel's Git integration.

## Deployment model

- `main` is the production branch.
- Pull requests and feature branches create Preview Deployments.
- Pushes or merges to `main` create Production Deployments.
- The framework is Next.js and the root directory is the repository root.

Vercel's Git integration owns deployment. GitHub Actions runs quality and local database checks only; it does not contain a deployment pipeline. No custom domain is configured.

## Public Supabase environment

Vercel Development and Preview environments receive only:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

The production environment intentionally has no backend variables during this foundation task. Database passwords, service-role keys, direct Postgres URLs, CLI access tokens, and Vercel tokens must never be added to Vercel's public environment or committed to the repository.
