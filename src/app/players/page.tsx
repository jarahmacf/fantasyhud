import { redirect } from "next/navigation"
import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { PlayerCatalogControl } from "@/components/players/player-catalog-control"
import { PlayerCatalogError } from "@/components/players/player-catalog-error"
import { PlayerCatalogSummary } from "@/components/players/player-catalog-summary"
import { PlayerCatalogTable } from "@/components/players/player-catalog-table"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { loadPlayerCatalogDashboard } from "@/lib/players/dashboard.server"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export default async function PlayersPage() {
  await connection()
  const identity = await getCurrentAuthIdentity()
  if (!identity) redirect("/auth/sign-in")

  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select("fantasy_accounts!inner(provider, username)")
    .eq("user_id", identity.id)
    .eq("fantasy_accounts.provider", "sleeper")
    .order("is_primary", { ascending: false })
    .limit(1)
    .maybeSingle()

  if (accountResult.error) {
    throw new Error("Unable to load the connected fantasy account.")
  }
  if (!accountResult.data) redirect("/onboarding")

  const identityLabel = {
    email: identity.email,
    accountLabel: `@${accountResult.data.fantasy_accounts.username}`,
  }

  let dashboard
  try {
    dashboard = await loadPlayerCatalogDashboard(supabase)
  } catch {
    return (
      <AppShell identity={identityLabel}>
        <PlayerCatalogError />
      </AppShell>
    )
  }

  const hasImported = dashboard.lastRefreshedAt !== null

  return (
    <AppShell identity={identityLabel}>
      <div className="flex flex-col gap-4 px-4 sm:flex-row sm:items-start sm:justify-between lg:px-6">
        <PageHeading
          title="Player catalog"
          description="Shared Sleeper NFL player identities and current profiles"
        />
        <PlayerCatalogControl hasSucceeded={hasImported} />
      </div>

      <div className="@container/main space-y-6 px-4 lg:px-6">
        <PlayerCatalogSummary dashboard={dashboard} />
        <PlayerCatalogTable
          players={dashboard.preview}
          hasImported={hasImported}
        />
      </div>
    </AppShell>
  )
}
