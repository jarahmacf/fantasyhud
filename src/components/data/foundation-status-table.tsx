"use client"

import { CircleCheck, Minus } from "lucide-react"

import { DataTable, type DataTableColumn } from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"

type FoundationStatus = "Ready" | "Configured" | "Not modeled"

type FoundationRow = {
  system: string
  status: FoundationStatus
  detail: string
}

const rows: readonly FoundationRow[] = [
  { system: "Application", status: "Ready", detail: "Next.js App Router" },
  { system: "TypeScript", status: "Ready", detail: "Strict mode" },
  {
    system: "Unit tests",
    status: "Ready",
    detail: "Vitest + Testing Library",
  },
  {
    system: "Browser tests",
    status: "Ready",
    detail: "Playwright Chromium",
  },
  { system: "CI", status: "Ready", detail: "GitHub Actions" },
  {
    system: "Backend tooling",
    status: "Ready",
    detail: "Supabase CLI + local stack",
  },
  {
    system: "Database tests",
    status: "Ready",
    detail: "pgTAP",
  },
  {
    system: "Hosted development",
    status: "Configured",
    detail: "Supabase GitHub integration",
  },
  {
    system: "Hosting",
    status: "Configured",
    detail: "Vercel Git integration",
  },
  {
    system: "Product database",
    status: "Not modeled",
    detail: "Deferred to Task 003",
  },
]

function StatusBadge({ status }: { status: FoundationStatus }) {
  const isPositive = status === "Ready" || status === "Configured"

  return (
    <Badge
      variant="outline"
      className={
        isPositive
          ? "rounded-[0.3rem] border-emerald-500/20 bg-emerald-500/5 px-1.5 font-mono text-[10px] font-medium text-emerald-400"
          : "rounded-[0.3rem] border-zinc-700 bg-zinc-900 px-1.5 font-mono text-[10px] font-medium text-zinc-400"
      }
    >
      {isPositive ? (
        <CircleCheck aria-hidden="true" />
      ) : (
        <Minus aria-hidden="true" />
      )}
      {status}
    </Badge>
  )
}

const columns: readonly DataTableColumn<FoundationRow>[] = [
  {
    id: "system",
    header: "System",
    accessor: "system",
    sortable: true,
    cell: (row) => <span className="font-medium text-white">{row.system}</span>,
  },
  {
    id: "status",
    header: "Status",
    accessor: "status",
    cell: (row) => <StatusBadge status={row.status} />,
  },
  {
    id: "detail",
    header: "Detail",
    accessor: "detail",
    cell: (row) => (
      <span className="font-mono text-[12px] text-muted-foreground">
        {row.detail}
      </span>
    ),
  },
]

export function FoundationStatusTable() {
  return (
    <section aria-labelledby="foundation-status-heading" className="min-w-0">
      <div className="mb-3 flex flex-col gap-0.5">
        <h2
          id="foundation-status-heading"
          className="text-sm font-semibold text-white"
        >
          Foundation status
        </h2>
        <p className="text-xs text-muted-foreground">
          Quality gates represented in this repository.
        </p>
      </div>
      <DataTable
        ariaLabel="Foundation status"
        columns={columns}
        rows={rows}
        getRowKey={(row) => row.system}
      />
    </section>
  )
}
