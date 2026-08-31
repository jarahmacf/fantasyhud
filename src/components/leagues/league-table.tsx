"use client"

import type { ColumnDef } from "@tanstack/react-table"

import {
  DataTable,
  type DataTableColumnMeta,
} from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"

export type LeagueTableRow = {
  id: string
  name: string
  status: string
  teamCount: number
  rosterManagementType: string
  isBestBall: boolean
  scoringFormat: string
  hasSuperflex: boolean
}

const labels: Record<string, string> = {
  pre_draft: "Pre-draft",
  drafting: "Drafting",
  in_season: "In season",
  complete: "Complete",
  redraft: "Redraft",
  keeper: "Keeper",
  dynasty: "Dynasty",
  unknown: "Unknown",
  ppr: "PPR",
  half_ppr: "Half PPR",
  standard: "Standard",
  custom: "Custom",
}

function label(value: string) {
  return labels[value] ?? value
}

const leftMeta: DataTableColumnMeta = { align: "left" }
const centerMeta: DataTableColumnMeta = { align: "center" }
const numericMeta: DataTableColumnMeta = { align: "right", numeric: true }

const columns: ColumnDef<LeagueTableRow>[] = [
  {
    accessorKey: "name",
    header: "League",
    meta: leftMeta,
    cell: ({ row }) => <span className="font-medium">{row.original.name}</span>,
  },
  {
    accessorKey: "status",
    header: "Status",
    meta: leftMeta,
    cell: ({ row }) => (
      <Badge variant="outline">{label(row.original.status)}</Badge>
    ),
  },
  {
    accessorKey: "teamCount",
    header: "Teams",
    meta: numericMeta,
  },
  {
    accessorKey: "rosterManagementType",
    header: "Management",
    meta: leftMeta,
    cell: ({ row }) => label(row.original.rosterManagementType),
  },
  {
    accessorKey: "isBestBall",
    header: "Best ball",
    meta: centerMeta,
    cell: ({ row }) => (row.original.isBestBall ? "Yes" : "No"),
  },
  {
    accessorKey: "scoringFormat",
    header: "Scoring",
    meta: leftMeta,
    cell: ({ row }) => label(row.original.scoringFormat),
  },
  {
    accessorKey: "hasSuperflex",
    header: "Superflex",
    meta: centerMeta,
    cell: ({ row }) => (row.original.hasSuperflex ? "Yes" : "No"),
  },
]

export function LeagueTable({
  leagues,
  hasSuccessfulDiscovery,
}: {
  leagues: LeagueTableRow[]
  hasSuccessfulDiscovery: boolean
}) {
  return (
    <DataTable
      ariaLabel="Current-season Sleeper leagues"
      columns={columns}
      countNoun={leagues.length === 1 ? "league" : "leagues"}
      data={leagues}
      description="Current active associations for the resolved Sleeper NFL season."
      emptyMessage={
        hasSuccessfulDiscovery
          ? "No current-season Sleeper leagues were returned for this account."
          : "Import current-season leagues to discover this account's leagues."
      }
      getRowId={(league) => league.id}
      headingId="current-season-leagues-heading"
      searchText=""
      title="Current-season leagues"
    />
  )
}
