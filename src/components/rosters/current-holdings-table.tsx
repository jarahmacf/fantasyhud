"use client"

import type { ColumnDef } from "@tanstack/react-table"

import {
  DataTable,
  type DataTableColumnMeta,
} from "@/components/data/data-table"
import type { CurrentHoldingPreviewRow } from "@/lib/rosters/dashboard-types"

const leftMeta: DataTableColumnMeta = { align: "left" }
const centerMeta: DataTableColumnMeta = { align: "center" }

const annotationLabels = {
  yes: "Yes",
  no: "No",
  not_reported: "Not reported",
} as const

const columns: ColumnDef<CurrentHoldingPreviewRow>[] = [
  {
    accessorKey: "playerLabel",
    header: "Player",
    meta: leftMeta,
    cell: ({ row }) => (
      <span className="font-medium">{row.original.playerLabel}</span>
    ),
  },
  { accessorKey: "leagueName", header: "League", meta: leftMeta },
  {
    accessorKey: "primaryPosition",
    header: "Position",
    meta: leftMeta,
    cell: ({ row }) => row.original.primaryPosition ?? "—",
  },
  {
    accessorKey: "nflTeam",
    header: "NFL team",
    meta: leftMeta,
    cell: ({ row }) => row.original.nflTeam ?? "—",
  },
  {
    accessorKey: "starterState",
    header: "Starter",
    meta: centerMeta,
    cell: ({ row }) => annotationLabels[row.original.starterState],
  },
  {
    accessorKey: "reserveState",
    header: "Reserve",
    meta: centerMeta,
    cell: ({ row }) => annotationLabels[row.original.reserveState],
  },
  {
    accessorKey: "taxiState",
    header: "Taxi",
    meta: centerMeta,
    cell: ({ row }) => annotationLabels[row.original.taxiState],
  },
  {
    accessorKey: "keeperState",
    header: "Keeper",
    meta: centerMeta,
    cell: ({ row }) => annotationLabels[row.original.keeperState],
  },
]

export function CurrentHoldingsTable({
  rows,
  totalCount,
}: {
  rows: CurrentHoldingPreviewRow[]
  totalCount: number
}) {
  return (
    <DataTable
      ariaLabel="Current holdings preview"
      caption={
        totalCount > rows.length
          ? `Showing the first ${rows.length.toLocaleString("en-US")} of ${totalCount.toLocaleString("en-US")} current holdings.`
          : undefined
      }
      columns={columns}
      countNoun={rows.length === 1 ? "holding shown" : "holdings shown"}
      data={rows}
      description="Up to 100 last-confirmed active memberships across confirmed-owned rosters."
      emptyMessage="No last-confirmed active memberships were resolved for confirmed-owned rosters."
      getRowId={(row) => row.id}
      headingId="current-holdings-heading"
      searchText=""
      title="Current holdings preview"
    />
  )
}
