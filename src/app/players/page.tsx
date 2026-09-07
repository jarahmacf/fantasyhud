import { redirect } from "next/navigation"
import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { PlayerCatalogControl } from "@/components/players/player-catalog-control"
import { PlayerCatalogError } from "@/components/players/player-catalog-error"
import { PlayerCatalogSummary } from "@/components/players/player-catalog-summary"
import { PlayerCatalogTable } from "@/components/players/player-catalog-table"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
import { loadPlayerCatalogDashboard } from "@/lib/players/dashboard.server"

export default async function PlayersPage() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  const { supabase, account, identity: identityLabel, readOnly } = access
  if (!account) redirect("/onboarding")

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
        {!readOnly ? <PlayerCatalogControl hasSucceeded={hasImported} /> : null}
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
