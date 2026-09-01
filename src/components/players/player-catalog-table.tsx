"use client"

import type { ColumnDef } from "@tanstack/react-table"

import {
  DataTable,
  type DataTableColumnMeta,
} from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"
import type { PlayerCatalogPreviewRow } from "@/lib/players/dashboard.server"

const leftMeta: DataTableColumnMeta = { align: "left" }
const centerMeta: DataTableColumnMeta = { align: "center" }

const columns: ColumnDef<PlayerCatalogPreviewRow>[] = [
  {
    accessorKey: "displayName",
    header: "Player",
    meta: leftMeta,
    cell: ({ row }) => (
      <span className="font-medium">
        {row.original.displayName ?? row.original.sleeperExternalId}
      </span>
    ),
  },
  {
    accessorKey: "primaryPosition",
    header: "Position",
    meta: leftMeta,
    cell: ({ row }) =>
      row.original.primaryPosition ||
      row.original.fantasyPositions.join(" / ") ||
      "—",
  },
  {
    accessorKey: "nflTeam",
    header: "Team",
    meta: leftMeta,
    cell: ({ row }) => row.original.nflTeam ?? "—",
  },
  {
    accessorKey: "active",
    header: "Active",
    meta: centerMeta,
    cell: ({ row }) => (row.original.active ? "Yes" : "No"),
  },
  {
    accessorKey: "status",
    header: "Status",
    meta: leftMeta,
    cell: ({ row }) =>
      row.original.status ? (
        <Badge variant="outline">{row.original.status}</Badge>
      ) : (
        "—"
      ),
  },
  {
    accessorKey: "injuryStatus",
    header: "Injury",
    meta: leftMeta,
    cell: ({ row }) =>
      [row.original.injuryStatus, row.original.injuryBodyPart]
        .filter(Boolean)
        .join(" · ") || "—",
  },
]

export function PlayerCatalogTable({
  players,
  hasImported,
}: {
  players: PlayerCatalogPreviewRow[]
  hasImported: boolean
}) {
  return (
    <DataTable
      ariaLabel="Canonical player catalog preview"
      columns={columns}
      countNoun={players.length === 1 ? "entity" : "entities"}
      data={players}
      description="Up to 50 active current entities, ordered by display name and exact Sleeper ID."
      emptyMessage={
        hasImported
          ? "Catalog imported with zero preview-eligible active entities."
          : "Import the Sleeper NFL player catalog to populate this preview."
      }
      getRowId={(player) => player.id}
      headingId="player-catalog-preview-heading"
      searchText=""
      title="Catalog preview"
    />
  )
}
