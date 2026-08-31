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
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { loadLeagueDashboardData } from "@/lib/leagues/dashboard.server"
import { createServerSupabaseClient } from "@/lib/supabase/server"

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
  const identity = await getCurrentAuthIdentity()
  if (!identity) redirect("/auth/sign-in")

  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select(
      "fantasy_account_id, is_primary, fantasy_accounts!inner(id, provider, username, display_name)"
    )
    .eq("user_id", identity.id)
    .eq("is_primary", true)
    .maybeSingle()

  if (accountResult.error) {
    throw new Error("Unable to load the connected fantasy account.")
  }
  if (!accountResult.data) redirect("/onboarding")

  const account = accountResult.data.fantasy_accounts
  if (account.provider !== "sleeper") {
    throw new Error("The primary fantasy account is not a Sleeper account.")
  }

  let dashboard
  try {
    dashboard = await loadLeagueDashboardData(supabase, account.id)
  } catch {
    return (
      <AppShell
        identity={{
          email: identity.email,
          accountLabel: `@${account.username}`,
        }}
      >
        <LeagueDataError />
      </AppShell>
    )
  }

  const latestStatus = getLatestStatus(dashboard.latestAttempt?.status)

  return (
    <AppShell
      identity={{
        email: identity.email,
        accountLabel: `@${account.username}`,
      }}
    >
      <div className="flex flex-col gap-4 px-4 sm:flex-row sm:items-start sm:justify-between lg:px-6">
        <PageHeading
          title="Sleeper leagues"
          description={`Current-season league discovery for @${account.username}`}
        />
        <LeagueDiscoveryControl
          hasSucceeded={dashboard.hasSuccessfulDiscovery}
        />
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
          Rosters and drafts not imported.
        </p>
      </div>
    </AppShell>
  )
}
