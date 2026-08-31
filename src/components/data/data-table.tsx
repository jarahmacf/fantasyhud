"use client"

import * as React from "react"
import {
  type ColumnDef,
  type SortingState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table"
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { cn } from "@/lib/utils"

export type DataTableColumnMeta = {
  align?: "left" | "center" | "right"
  numeric?: boolean
}

type DataTableProps<Row> = {
  ariaLabel: string
  caption?: string
  columns: ColumnDef<Row>[]
  countNoun?: string
  data: Row[]
  description?: string
  emptyMessage?: string
  getRowId: (row: Row) => string
  headingId?: string
  searchText: string
  title: string
}

const alignmentClassNames = {
  left: "text-left",
  center: "text-center",
  right: "text-right",
} as const

function SortIcon({ direction }: { direction: false | "asc" | "desc" }) {
  if (direction === "asc") {
    return <ArrowUp aria-hidden="true" className="size-3.5" />
  }

  if (direction === "desc") {
    return <ArrowDown aria-hidden="true" className="size-3.5" />
  }

  return <ArrowUpDown aria-hidden="true" className="size-3.5" />
}

export function DataTable<Row>({
  ariaLabel,
  caption,
  columns,
  countNoun = "systems",
  data,
  description,
  emptyMessage = "No results.",
  getRowId,
  headingId = "data-table-heading",
  searchText,
  title,
}: DataTableProps<Row>) {
  const [sorting, setSorting] = React.useState<SortingState>([])
  // TanStack Table returns stable stateful helpers that React Compiler intentionally skips.
  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    columns,
    data,
    getRowId,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
    globalFilterFn: "includesString",
    onSortingChange: setSorting,
    state: {
      globalFilter: searchText,
      sorting,
    },
  })

  const filteredCount = table.getFilteredRowModel().rows.length
  const countLabel = searchText
    ? `${filteredCount} of ${data.length} ${countNoun} matching “${searchText}”`
    : `${data.length} ${countNoun}`

  return (
    <section aria-labelledby={headingId} className="min-w-0">
      <div className="mb-3 flex items-end justify-between gap-4">
        <div className="flex flex-col gap-0.5">
          <h2 id={headingId} className="text-sm font-semibold">
            {title}
          </h2>
          {description ? (
            <p className="text-xs text-muted-foreground">{description}</p>
          ) : null}
        </div>
        <p
          role="status"
          aria-live="polite"
          className="shrink-0 text-xs text-muted-foreground"
        >
          {countLabel}
        </p>
      </div>

      <div className="overflow-x-auto rounded-lg border bg-card">
        <Table aria-label={ariaLabel} className="min-w-[640px]">
          {caption ? <TableCaption>{caption}</TableCaption> : null}
          <TableHeader className="sticky top-0 z-10 bg-muted">
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id} className="hover:bg-muted">
                {headerGroup.headers.map((header) => {
                  const meta = header.column.columnDef.meta as
                    DataTableColumnMeta | undefined
                  const alignment = meta?.align ?? "left"
                  const direction = header.column.getIsSorted()

                  return (
                    <TableHead
                      key={header.id}
                      aria-sort={
                        direction === "asc"
                          ? "ascending"
                          : direction === "desc"
                            ? "descending"
                            : header.column.getCanSort()
                              ? "none"
                              : undefined
                      }
                      className={cn(
                        "h-10 px-2",
                        alignmentClassNames[alignment],
                        meta?.numeric && "tabular-nums"
                      )}
                    >
                      {header.isPlaceholder ? null : header.column.getCanSort() ? (
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onClick={header.column.getToggleSortingHandler()}
                          aria-label={`Sort by ${String(header.column.columnDef.header)}`}
                          className={cn(
                            "-ml-3 h-8",
                            alignment === "right" && "ml-auto -mr-3",
                            alignment === "center" && "mx-auto"
                          )}
                        >
                          {flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                          <SortIcon direction={direction} />
                        </Button>
                      ) : (
                        flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )
                      )}
                    </TableHead>
                  )
                })}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {filteredCount ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id}>
                  {row.getVisibleCells().map((cell) => {
                    const meta = cell.column.columnDef.meta as
                      DataTableColumnMeta | undefined
                    const alignment = meta?.align ?? "left"

                    return (
                      <TableCell
                        key={cell.id}
                        className={cn(
                          "h-11 p-2",
                          alignmentClassNames[alignment],
                          meta?.numeric && "tabular-nums"
                        )}
                      >
                        {flexRender(
                          cell.column.columnDef.cell,
                          cell.getContext()
                        )}
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
    </section>
  )
}
