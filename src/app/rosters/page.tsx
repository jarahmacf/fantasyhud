import { redirect } from "next/navigation"
import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { CurrentHoldingsTable } from "@/components/rosters/current-holdings-table"
import { OwnedRosterTable } from "@/components/rosters/owned-roster-table"
import { RosterDataError } from "@/components/rosters/roster-data-error"
import { RosterImportControl } from "@/components/rosters/roster-import-control"
import { RosterStatusNotice } from "@/components/rosters/roster-status-notice"
import { RosterSummaryCards } from "@/components/rosters/roster-summary-cards"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
import { loadRosterDashboardData } from "@/lib/rosters/dashboard.server"

export const maxDuration = 300
export const runtime = "nodejs"

function Heading() {
  return (
    <PageHeading
      title="Sleeper rosters"
      description="Current holdings across your tracked current-season leagues"
    />
  )
}

export default async function RostersPage() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  const { supabase, account, identity: shellIdentity, readOnly } = access
  if (!account) redirect("/onboarding")

  let dashboard
  try {
    dashboard = await loadRosterDashboardData(supabase, account.id)
  } catch {
    return (
      <AppShell identity={shellIdentity}>
        <RosterDataError />
      </AppShell>
    )
  }

  return (
    <AppShell identity={shellIdentity}>
      <div className="flex flex-col gap-4 px-4 sm:flex-row sm:items-start sm:justify-between lg:px-6">
        <Heading />
        {!readOnly && dashboard.prerequisite === "ready" ? (
          <RosterImportControl
            hasImported={dashboard.hasSuccessfulImport}
            isRunning={dashboard.latestStatus === "running"}
          />
        ) : null}
      </div>

      <div className="@container/main space-y-6 px-4 lg:px-6">
        <RosterStatusNotice
          prerequisite={dashboard.prerequisite}
          status={dashboard.latestStatus}
          unresolvedLeagueCount={dashboard.unresolvedLeagueCount}
        />
        <RosterSummaryCards dashboard={dashboard} />
        {dashboard.prerequisite === "ready" ? (
          <>
            <OwnedRosterTable rows={dashboard.ownedRosters} />
            <CurrentHoldingsTable
              rows={dashboard.holdingPreview}
              totalCount={dashboard.currentHoldingCount}
            />
          </>
        ) : null}
      </div>
    </AppShell>
  )
}
