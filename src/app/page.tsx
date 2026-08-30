import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { FoundationStatusTable } from "@/components/data/foundation-status-table"
import { StatusCard } from "@/components/data/status-card"

const statusCards = [
  {
    label: "Application",
    value: "Ready",
    detail: "Dashboard shell is available.",
  },
  {
    label: "TypeScript",
    value: "Strict",
    detail: "Strict checks are enabled.",
  },
  {
    label: "Unit tests",
    value: "Configured",
    detail: "Vitest + Testing Library.",
  },
  {
    label: "Browser tests",
    value: "Configured",
    detail: "Chromium via Playwright.",
  },
] as const

export default function Home() {
  return (
    <AppShell>
      <div className="mx-auto flex w-full max-w-[1440px] flex-1 flex-col gap-5 px-4 py-5 sm:px-6 md:gap-6 md:py-7 lg:px-8">
        <PageHeading
          title="Repository foundation"
          description="Application, quality gates, and backend status."
        />

        <section
          aria-label="Foundation summary"
          className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
        >
          {statusCards.map((card) => (
            <StatusCard key={card.label} {...card} />
          ))}
        </section>

        <FoundationStatusTable />
      </div>
    </AppShell>
  )
}
