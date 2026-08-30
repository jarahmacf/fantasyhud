"use client"

import * as React from "react"
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { cn } from "@/lib/utils"

type Alignment = "left" | "center" | "right"
type SortDirection = "ascending" | "descending"

export type DataTableColumn<Row> = {
  id: string
  header: string
  accessor?: keyof Row
  align?: Alignment
  sortable?: boolean
  cell?: (row: Row) => React.ReactNode
}

type DataTableProps<Row> = {
  ariaLabel: string
  columns: readonly DataTableColumn<Row>[]
  rows: readonly Row[]
  getRowKey: (row: Row) => React.Key
  emptyMessage?: string
}

type SortState<Row> = {
  accessor: keyof Row
  direction: SortDirection
}

const alignmentClassNames: Record<Alignment, string> = {
  left: "text-left",
  center: "text-center",
  right: "text-right",
}

function compareValues(left: unknown, right: unknown) {
  return String(left ?? "").localeCompare(String(right ?? ""), undefined, {
    numeric: true,
    sensitivity: "base",
  })
}

export function DataTable<Row>({
  ariaLabel,
  columns,
  rows,
  getRowKey,
  emptyMessage = "No results.",
}: DataTableProps<Row>) {
  const [sort, setSort] = React.useState<SortState<Row> | null>(null)

  const sortedRows = React.useMemo(() => {
    if (!sort) {
      return rows
    }

    return [...rows].sort((left, right) => {
      const result = compareValues(left[sort.accessor], right[sort.accessor])
      return sort.direction === "ascending" ? result : -result
    })
  }, [rows, sort])

  function toggleSort(accessor: keyof Row) {
    setSort((current) => {
      if (current?.accessor !== accessor) {
        return { accessor, direction: "ascending" }
      }

      return {
        accessor,
        direction:
          current.direction === "ascending" ? "descending" : "ascending",
      }
    })
  }

  function sortIcon(column: DataTableColumn<Row>) {
    if (!column.accessor || sort?.accessor !== column.accessor) {
      return <ArrowUpDown aria-hidden="true" className="size-3" />
    }

    return sort.direction === "ascending" ? (
      <ArrowUp aria-hidden="true" className="size-3" />
    ) : (
      <ArrowDown aria-hidden="true" className="size-3" />
    )
  }

  return (
    <div className="overflow-hidden rounded-md border bg-card">
      <Table aria-label={ariaLabel} className="min-w-[620px]">
        <TableHeader className="sticky top-0 z-10 bg-muted">
          <TableRow className="hover:bg-muted">
            {columns.map((column) => {
              const align = column.align ?? "left"
              const sortableAccessor = column.sortable
                ? column.accessor
                : undefined
              const isSorted =
                column.accessor !== undefined &&
                sort?.accessor === column.accessor

              return (
                <TableHead
                  key={column.id}
                  aria-sort={isSorted ? sort.direction : undefined}
                  className={cn(
                    "h-9 px-4 font-mono text-[10px] uppercase tracking-[0.12em] text-muted-foreground",
                    alignmentClassNames[align]
                  )}
                >
                  {sortableAccessor ? (
                    <button
                      type="button"
                      onClick={() => toggleSort(sortableAccessor)}
                      className={cn(
                        "inline-flex items-center gap-1.5 rounded-sm outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring",
                        align === "right" && "ml-auto",
                        align === "center" && "mx-auto"
                      )}
                    >
                      {column.header}
                      {sortIcon(column)}
                    </button>
                  ) : (
                    column.header
                  )}
                </TableHead>
              )
            })}
          </TableRow>
        </TableHeader>
        <TableBody>
          {sortedRows.length > 0 ? (
            sortedRows.map((row) => (
              <TableRow key={getRowKey(row)} className="hover:bg-white/[0.025]">
                {columns.map((column) => {
                  const align = column.align ?? "left"
                  const value = column.accessor
                    ? String(row[column.accessor] ?? "")
                    : null

                  return (
                    <TableCell
                      key={column.id}
                      className={cn(
                        "h-11 px-4 py-2.5 text-[13px]",
                        alignmentClassNames[align]
                      )}
                    >
                      {column.cell ? column.cell(row) : value}
                    </TableCell>
                  )
                })}
              </TableRow>
            ))
          ) : (
            <TableRow>
              <TableCell
                colSpan={columns.length}
                className="h-24 text-center text-sm text-muted-foreground"
              >
                {emptyMessage}
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  )
}
