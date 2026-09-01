import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { FoundationStatusTable } from "@/components/data/foundation-status-table"
import { FoundationSummaryCards } from "@/components/data/foundation-summary-cards"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export default async function FoundationPage() {
  await connection()
  const authIdentity = await getCurrentAuthIdentity()
  let identity

  if (authIdentity) {
    const supabase = await createServerSupabaseClient()
    const accountResult = await supabase
      .from("user_fantasy_accounts")
      .select("fantasy_accounts!inner(provider, username)")
      .eq("user_id", authIdentity.id)
      .eq("fantasy_accounts.provider", "sleeper")
      .order("is_primary", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (accountResult.error) {
      throw new Error("Unable to load the signed-in foundation shell.")
    }

    identity = {
      email: authIdentity.email,
      accountLabel: accountResult.data
        ? `@${accountResult.data.fantasy_accounts.username}`
        : "Sleeper not connected",
    }
  }

  return (
    <AppShell identity={identity} showFoundationSearch>
      <div className="px-4 lg:px-6">
        <PageHeading
          title="Repository foundation"
          description="Application, quality gates, identity, and backend infrastructure status."
        />
      </div>

      <div className="@container/main space-y-6 px-4 lg:px-6">
        <FoundationSummaryCards />
        <FoundationStatusTable />
      </div>
    </AppShell>
  )
}
