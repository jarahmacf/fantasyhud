import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { FoundationSummaryCards } from "@/components/data/foundation-summary-cards"
import { FoundationStatusTable } from "@/components/data/foundation-status-table"

export default function Home() {
  return (
    <AppShell>
      <div className="px-4 lg:px-6">
        <PageHeading
          title="Repository foundation"
          description="Application, quality gates, and backend infrastructure status."
        />
      </div>

      <div className="@container/main space-y-6 px-4 lg:px-6">
        <FoundationSummaryCards />
        <FoundationStatusTable />
      </div>
    </AppShell>
  )
}
