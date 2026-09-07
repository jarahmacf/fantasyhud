import { connection } from "next/server"

import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { FoundationStatusTable } from "@/components/data/foundation-status-table"
import { FoundationSummaryCards } from "@/components/data/foundation-summary-cards"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"

export default async function FoundationPage() {
  await connection()
  const access = await getWorkspaceAccess()
  const identity = access?.identity

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
