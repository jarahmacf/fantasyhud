import { redirect } from "next/navigation"
import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { LeagueDiscoveryControl } from "@/components/leagues/league-discovery-control"
import { LeagueDataError } from "@/components/leagues/league-data-error"
import {
  LeagueSummaryCards,
  type LatestDiscoveryStatus,
} from "@/components/leagues/league-summary-cards"
import { LeagueTable } from "@/components/leagues/league-table"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
import { loadLeagueDashboardData } from "@/lib/leagues/dashboard.server"

const syncStatuses = new Set(["running", "succeeded", "failed", "partial"])

function getLatestStatus(status: string | undefined): LatestDiscoveryStatus {
  if (!status) return "not_started"
  if (!syncStatuses.has(status)) {
    throw new Error("The latest league discovery has an invalid status.")
  }
  return status as LatestDiscoveryStatus
}

export default async function Home() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  const { supabase, account, identity, readOnly } = access
  if (!account) redirect("/onboarding")

  let dashboard
  try {
    dashboard = await loadLeagueDashboardData(supabase, account.id)
  } catch {
    return (
      <AppShell identity={identity}>
        <LeagueDataError />
      </AppShell>
    )
  }

  const latestStatus = getLatestStatus(dashboard.latestAttempt?.status)

  return (
    <AppShell identity={identity}>
      <div className="flex flex-col gap-4 px-4 sm:flex-row sm:items-start sm:justify-between lg:px-6">
        <PageHeading
          title="Sleeper leagues"
          description={`Current-season league discovery for @${account.username}`}
        />
        {!readOnly ? (
          <LeagueDiscoveryControl
            hasSucceeded={dashboard.hasSuccessfulDiscovery}
          />
        ) : null}
      </div>

      <div className="@container/main space-y-6 px-4 lg:px-6">
        <LeagueSummaryCards
          username={account.username}
          displayName={account.display_name}
          leagueSeason={dashboard.currentLeagueSeason}
          activeLeagueCount={dashboard.leagues.length}
          latestStatus={latestStatus}
          latestSeason={dashboard.latestAttempt?.season ?? null}
        />
        <LeagueTable
          leagues={dashboard.leagues}
          hasSuccessfulDiscovery={dashboard.hasSuccessfulDiscovery}
        />
        <p className="text-sm text-muted-foreground">
          {dashboard.hasCurrentSeasonRosterImport
            ? "Rosters imported. Drafts not imported."
            : "Rosters and drafts not imported."}
        </p>
      </div>
    </AppShell>
  )
}
