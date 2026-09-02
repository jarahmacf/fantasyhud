"use client"

import type { ColumnDef } from "@tanstack/react-table"

import {
  DataTable,
  type DataTableColumnMeta,
} from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"
import type { OwnedRosterRow } from "@/lib/rosters/dashboard-types"

const leftMeta: DataTableColumnMeta = { align: "left" }
const numericMeta: DataTableColumnMeta = { align: "right", numeric: true }

function sourceCount(value: number | null) {
  return value === null ? (
    <span className="text-muted-foreground">Not reported</span>
  ) : (
    value
  )
}

const columns: ColumnDef<OwnedRosterRow>[] = [
  {
    accessorKey: "leagueName",
    header: "League",
    meta: leftMeta,
    cell: ({ row }) => (
      <span className="font-medium">{row.original.leagueName}</span>
    ),
  },
  { accessorKey: "teamName", header: "Team", meta: leftMeta },
  {
    accessorKey: "ownershipRole",
    header: "Role",
    meta: leftMeta,
    cell: ({ row }) => (
      <Badge variant="outline">
        {row.original.ownershipRole === "owner" ? "Owner" : "Co-owner"}
      </Badge>
    ),
  },
  {
    accessorKey: "playerCount",
    header: "Players",
    meta: numericMeta,
    cell: ({ row }) => sourceCount(row.original.playerCount),
  },
  {
    accessorKey: "starterCount",
    header: "Starters",
    meta: numericMeta,
    cell: ({ row }) => sourceCount(row.original.starterCount),
  },
  {
    accessorKey: "reserveCount",
    header: "Reserve",
    meta: numericMeta,
    cell: ({ row }) => sourceCount(row.original.reserveCount),
  },
  {
    accessorKey: "taxiCount",
    header: "Taxi",
    meta: numericMeta,
    cell: ({ row }) => sourceCount(row.original.taxiCount),
  },
  {
    accessorKey: "keeperCount",
    header: "Keepers",
    meta: numericMeta,
    cell: ({ row }) => sourceCount(row.original.keeperCount),
  },
]

export function OwnedRosterTable({ rows }: { rows: OwnedRosterRow[] }) {
  return (
    <DataTable
      ariaLabel="Owned current-season Sleeper rosters"
      columns={columns}
      countNoun={rows.length === 1 ? "roster" : "rosters"}
      data={rows}
      description="Current confirmed ownership for the connected Sleeper account."
      emptyMessage="No owned roster was resolved for this account."
      getRowId={(row) => row.id}
      headingId="owned-rosters-heading"
      searchText=""
      title="Owned rosters"
    />
  )
}
