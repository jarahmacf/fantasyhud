"use client"

import type { ColumnDef } from "@tanstack/react-table"
import { CircleCheck, Minus } from "lucide-react"

import { useFoundationSearch } from "@/components/app/foundation-search"
import {
  DataTable,
  type DataTableColumnMeta,
} from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"

type FoundationStatus = "Ready" | "Configured" | "Not implemented"

type FoundationRow = {
  system: string
  status: FoundationStatus
  detail: string
}

const rows: FoundationRow[] = [
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
  { system: "Database tests", status: "Ready", detail: "pgTAP" },
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
    system: "Authentication model",
    status: "Ready",
    detail: "Email/password + SSR cookies",
  },
  {
    system: "Auth browser tests",
    status: "Ready",
    detail: "Local Supabase + Playwright",
  },
  {
    system: "Account identity model",
    status: "Ready",
    detail: "Shared provider identity + strict RLS",
  },
  {
    system: "Sleeper connection",
    status: "Not implemented",
    detail: "Connection is intentionally unavailable",
  },
]

function StatusBadge({ status }: { status: FoundationStatus }) {
  const isPositive = status === "Ready" || status === "Configured"

  return (
    <Badge
      variant="outline"
      className={
        isPositive
          ? "border-emerald-500/20 bg-emerald-500/5 text-emerald-400"
          : "text-muted-foreground"
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

const leftMeta: DataTableColumnMeta = { align: "left" }

const columns: ColumnDef<FoundationRow>[] = [
  {
    accessorKey: "system",
    header: "System",
    sortingFn: "alphanumeric",
    meta: leftMeta,
    cell: ({ row }) => (
      <span className="font-medium">{row.original.system}</span>
    ),
  },
  {
    accessorKey: "status",
    header: "Status",
    sortingFn: "alphanumeric",
    meta: leftMeta,
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
  },
  {
    accessorKey: "detail",
    header: "Detail",
    sortingFn: "alphanumeric",
    meta: leftMeta,
    cell: ({ row }) => (
      <span className="text-muted-foreground">{row.original.detail}</span>
    ),
  },
]

export function FoundationStatusTable() {
  const { searchText } = useFoundationSearch()

  return (
    <DataTable
      ariaLabel="Foundation status"
      columns={columns}
      data={rows}
      description="Quality gates represented in this repository."
      emptyMessage="No foundation systems match this search."
      getRowId={(row) => row.system}
      headingId="foundation-status-heading"
      searchText={searchText}
      title="Foundation status"
    />
  )
}
