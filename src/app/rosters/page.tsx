import { redirect } from "next/navigation"
import { connection } from "next/server"

import { AppShell, type AppShellIdentity } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { CurrentHoldingsTable } from "@/components/rosters/current-holdings-table"
import { OwnedRosterTable } from "@/components/rosters/owned-roster-table"
import { RosterDataError } from "@/components/rosters/roster-data-error"
import { RosterImportControl } from "@/components/rosters/roster-import-control"
import { RosterStatusNotice } from "@/components/rosters/roster-status-notice"
import { RosterSummaryCards } from "@/components/rosters/roster-summary-cards"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { loadRosterDashboardData } from "@/lib/rosters/dashboard.server"
import { createServerSupabaseClient } from "@/lib/supabase/server"

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
  const authIdentity = await getCurrentAuthIdentity()
  if (!authIdentity) redirect("/auth/sign-in")

  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select(
      "fantasy_account_id, fantasy_accounts!inner(id, provider, username)"
    )
    .eq("user_id", authIdentity.id)
    .eq("is_primary", true)
    .maybeSingle()

  const unavailableIdentity: AppShellIdentity = {
    email: authIdentity.email,
    accountLabel: "Sleeper unavailable",
  }
  if (accountResult.error) {
    return (
      <AppShell identity={unavailableIdentity}>
        <RosterDataError />
      </AppShell>
    )
  }

  const account = accountResult.data?.fantasy_accounts
  if (!account || account.provider !== "sleeper") {
    return (
      <AppShell
        identity={{
          email: authIdentity.email,
          accountLabel: "No Sleeper account",
        }}
      >
        <div className="px-4 lg:px-6">
          <Heading />
        </div>
        <div className="px-4 lg:px-6">
          <RosterStatusNotice
            prerequisite="account"
            status="not_started"
            unresolvedLeagueCount={0}
          />
        </div>
      </AppShell>
    )
  }

  const shellIdentity: AppShellIdentity = {
    email: authIdentity.email,
    accountLabel: `@${account.username}`,
  }

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
        {dashboard.prerequisite === "ready" ? (
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
