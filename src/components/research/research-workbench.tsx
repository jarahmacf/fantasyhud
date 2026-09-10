"use client"
import { useCallback, useEffect, useMemo, useState } from "react"
import Link from "next/link"
import type { ColumnDef } from "@tanstack/react-table"
import { RefreshCw, ArrowUpRight } from "lucide-react"
import { DataTable } from "@/components/data/data-table"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card"
import type {
  Acquisition,
  ResearchData,
  ResearchPlayer,
} from "@/lib/research/types"
export const formatNumber = (n: number | null | undefined) =>
  n == null ? "—" : n.toLocaleString(undefined, { maximumFractionDigits: 2 })
export const signed = (n: number | null | undefined) =>
  n == null ? "—" : `${n > 0 ? "+" : ""}${formatNumber(n)}`
export const fieldLabel = (field: string) =>
  field
    .replace("adp_", "")
    .replace("dynasty_", "Dynasty · ")
    .replace("half_ppr", "Half PPR")
    .replace("2qb", "2QB / superflex")
    .replace("ppr", "PPR")
    .replace("std", "Standard")
export function useResearch<T>(path: string) {
  const [data, setData] = useState<T | null>(null),
    [error, setError] = useState<string | null>(null),
    [loading, setLoading] = useState(true)
  const refresh = useCallback(
    (signal?: AbortSignal) =>
      fetch(path, { cache: "no-store", signal })
        .then(async (response) => {
          if (!response.ok)
            throw new Error(
              "Refresh failed. Last displayed observations are retained."
            )
          return response.json() as Promise<T>
        })
        .then((next) => {
          if (!signal?.aborted) {
            setData(next)
            setError(null)
          }
        })
        .catch((error) => {
          if (!signal?.aborted)
            setError(
              error instanceof Error ? error.message : "Refresh unavailable."
            )
        })
        .finally(() => {
          if (!signal?.aborted) setLoading(false)
        }),
    [path]
  )
  useEffect(() => {
    const c = new AbortController()
    void refresh(c.signal)
    const timer = setInterval(() => {
      if (document.visibilityState === "visible") void refresh(c.signal)
    }, 120000)
    return () => {
      c.abort()
      clearInterval(timer)
    }
  }, [refresh])
  return { data, error, loading, refresh }
}
export function Metric({
  label,
  value,
  detail,
}: {
  label: string
  value: string
  detail: string
}) {
  return (
    <Card>
      <CardHeader>
        <CardDescription>{label}</CardDescription>
        <CardTitle className="text-2xl tabular-nums">{value}</CardTitle>
        <CardDescription>{detail}</CardDescription>
      </CardHeader>
    </Card>
  )
}
export function AcquisitionTable({
  rows,
  search = "",
  title = "Automatic draft valuation",
}: {
  rows: Acquisition[]
  search?: string
  title?: string
}) {
  const columns = useMemo<ColumnDef<Acquisition>[]>(
    () => [
      {
        accessorKey: "name",
        header: "Player",
        cell: ({ row }) => (
          <Link
            className="font-medium underline-offset-4 hover:underline"
            href={`/players/${row.original.playerToken}?context=${row.original.leagueToken}`}
          >
            {row.original.name}
            <ArrowUpRight className="ml-1 inline size-3" />
          </Link>
        ),
      },
      { accessorKey: "position", header: "Pos" },
      { accessorKey: "league", header: "League" },
      {
        id: "paid",
        header: "Paid",
        accessorFn: (r) => r.paid,
        cell: ({ row }) =>
          row.original.draftType === "auction"
            ? `$${formatNumber(row.original.paid)}`
            : `Pick ${formatNumber(row.original.paid)}`,
      },
      {
        accessorKey: "equivalentAdp",
        header: "Pick equivalent",
        cell: ({ row }) => (
          <span
            title={
              row.original.reason ??
              (row.original.draftType === "auction"
                ? `${row.original.peerDrafts} peer drafts · ${row.original.matchedPlayers} matched players · room-capital normalized`
                : "Actual overall selection")
            }
          >
            {row.original.draftType === "auction" &&
            row.original.equivalentAdp !== null
              ? "≈ "
              : ""}
            {row.original.adpBound
              ? `${row.original.adpBound.direction === "at_most" ? "≤" : "≥"} ${formatNumber(row.original.adpBound.value)}`
              : formatNumber(row.original.equivalentAdp)}
          </span>
        ),
      },
      {
        accessorKey: "marketAdp",
        header: "Sleeper ADP",
        cell: ({ row }) => (
          <span title={fieldLabel(row.original.adpField)}>
            {formatNumber(row.original.marketAdp)}
          </span>
        ),
      },
      {
        accessorKey: "adpGain",
        header: "ADP value",
        cell: ({ getValue }) => signed(getValue<number | null>()),
      },
      {
        accessorKey: "impliedRank",
        header: "Price-implied rank",
        cell: ({ row }) => (
          <span
            title={
              row.original.reason ??
              "Positional rank implied by the price paid on the market ADP curve"
            }
          >
            {row.original.position}{" "}
            {row.original.rankBound
              ? `${row.original.rankBound.direction === "at_most" ? "≤" : "≥"} ${formatNumber(row.original.rankBound.value)}`
              : formatNumber(row.original.impliedRank)}
          </span>
        ),
      },
      {
        accessorKey: "actualRank",
        header: "Completed-week rank",
        cell: ({ getValue }) => formatNumber(getValue<number | null>()),
      },
      {
        accessorKey: "rankGain",
        header: "Rank gain / loss",
        cell: ({ getValue }) => signed(getValue<number | null>()),
      },
      {
        accessorKey: "livePoints",
        header: "Points incl. live",
        cell: ({ getValue }) => formatNumber(getValue<number | null>()),
      },
      {
        accessorKey: "pointsAbovePrice",
        header: "Points above price",
        cell: ({ getValue }) => signed(getValue<number | null>()),
      },
      {
        accessorKey: "reason",
        header: "Coverage",
        cell: ({ row }) =>
          row.original.reason ??
          (row.original.draftType === "auction"
            ? `${row.original.peerDrafts} peer drafts${row.original.adjustedTeams ? " · team-size adjusted" : ""}`
            : "Matched"),
      },
    ],
    []
  )
  return (
    <DataTable
      ariaLabel="Automatic draft valuation"
      pageSize={50}
      title={title}
      description="Positive ADP value means acquired later/cheaper than the current market reference. Rank gain compares price-implied positional rank with completed-week performance. Open any player for the full calculation, weekly history and source details."
      columns={columns}
      data={rows}
      getRowId={(r) => r.key}
      searchText={search}
      countNoun="selections"
    />
  )
}
export function ResearchWorkbench({
  mode = "drafts",
}: {
  mode?: "drafts" | "players"
}) {
  const { data, error, loading, refresh } =
    useResearch<ResearchData>("/api/research")
  const [search, setSearch] = useState(""),
    [type, setType] = useState("all"),
    [position, setPosition] = useState("all"),
    [page, setPage] = useState(0)
  const rows = (data?.acquisitions ?? []).filter(
    (r) =>
      (type === "all" || r.draftType === type) &&
      (position === "all" || r.position === position)
  )
  const players = (data?.players ?? []).filter(
    (p) =>
      (position === "all" || p.position === position) &&
      `${p.name} ${p.team ?? ""} ${p.position}`
        .toLowerCase()
        .includes(search.toLowerCase())
  )
  const columns = useMemo<ColumnDef<ResearchPlayer>[]>(
    () => [
      {
        accessorKey: "name",
        header: "Player",
        cell: ({ row }) => (
          <Link
            className="font-medium underline-offset-4 hover:underline"
            href={`/players/${row.original.token}`}
          >
            {row.original.name}
            <ArrowUpRight className="ml-1 inline size-3" />
          </Link>
        ),
      },
      { accessorKey: "position", header: "Position" },
      { accessorKey: "team", header: "Team" },
      {
        accessorKey: "adp",
        header: "Sleeper PPR ADP",
        cell: ({ getValue }) => formatNumber(getValue<number | null>()),
      },
      { accessorKey: "held", header: "Leagues held" },
      { accessorKey: "drafted", header: "Times drafted" },
      { accessorKey: "injury", header: "Source injury status" },
    ],
    []
  )
  return (
    <section
      className="space-y-6"
      aria-label={mode === "players" ? "Player research" : "Draft research"}
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          {data
            ? `${data.season} · ${data.completedDrafts} completed drafts · Week ${data.week}`
            : "Reconciling completed drafts, ADP and weekly statistics…"}
        </p>
        <Button
          variant="outline"
          onClick={() => void refresh()}
          disabled={loading}
        >
          <RefreshCw className={loading ? "animate-spin" : ""} />
          Refresh research
        </Button>
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {data?.issues.map((issue) => (
        <p role="alert" key={issue} className="text-sm text-destructive">
          {issue}
        </p>
      ))}
      {mode === "drafts" ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Metric
            label="Completed drafts"
            value={formatNumber(data?.completedDrafts)}
            detail="Complete boards with your directly attributed selections"
          />
          <Metric
            label="Snake / linear"
            value={formatNumber(data?.snakeDrafts)}
            detail="Actual pick matched to a dated Sleeper ADP curve"
          />
          <Metric
            label="Auction"
            value={formatNumber(data?.auctionDrafts)}
            detail="Automatic dollar-to-ADP fit; subject draft excluded"
          />
          <Metric
            label="Auction prices matched"
            value={
              data
                ? `${rows.filter((r) => r.draftType === "auction" && r.equivalentAdp !== null).length} / ${rows.filter((r) => r.draftType === "auction").length}`
                : "—"
            }
            detail="Out-of-range costs display bounds; no extrapolation"
          />
        </div>
      ) : null}
      <div className="flex flex-wrap gap-3">
        <Input
          className="sm:max-w-sm"
          aria-label="Search research"
          placeholder="Search players or leagues…"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(0)
          }}
        />
        {mode === "drafts" ? (
          <label className="text-sm">
            Draft type{" "}
            <select
              className="ml-2 rounded-md border bg-background p-2"
              value={type}
              onChange={(e) => setType(e.target.value)}
            >
              <option value="all">All drafts</option>
              <option value="snake">Snake</option>
              <option value="auction">Auction</option>
            </select>
          </label>
        ) : null}
        <label className="text-sm">
          Position{" "}
          <select
            className="ml-2 rounded-md border bg-background p-2"
            value={position}
            onChange={(e) => {
              setPosition(e.target.value)
              setPage(0)
            }}
          >
            <option value="all">All positions</option>
            {["QB", "RB", "WR", "TE", "K", "DEF"].map((p) => (
              <option key={p}>{p}</option>
            ))}
          </select>
        </label>
      </div>
      {mode === "drafts" ? (
        <AcquisitionTable rows={rows} search={search} />
      ) : (
        <>
          <DataTable
            ariaLabel="Player research directory"
            title="Player research"
            description="Search the source-backed directory. Every player opens a profile with your league scoring, acquisitions, weekly results and rank trajectory. Directory ADP is PPR; profiles select the appropriate league market."
            columns={columns}
            data={players.slice(page * 100, (page + 1) * 100)}
            getRowId={(p) => p.token}
            searchText=""
            countNoun="players"
          />
          <div className="flex items-center gap-3">
            <Button
              variant="outline"
              disabled={page === 0}
              onClick={() => setPage((p) => p - 1)}
            >
              Previous
            </Button>
            <p className="text-sm">
              {players.length} matching players · Page {page + 1}
            </p>
            <Button
              variant="outline"
              disabled={(page + 1) * 100 >= players.length}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </Button>
          </div>
        </>
      )}
      <Card>
        <CardHeader>
          <CardTitle>Where these numbers come from</CardTitle>
          <CardDescription>
            {data?.completedWeek
              ? `Performance comparisons include completed weeks 1–${data.completedWeek}.`
              : "No completed week yet. Live points are shown; season rank gain/loss starts after the first week closes."}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-muted-foreground">
          <p>
            ADP is Sleeper’s explicit ADP field, selected automatically for PPR,
            half PPR, standard or superflex and dynasty. Its sample size and
            exact custom-scoring population are not supplied. Your points use
            your exact league scoring; the market reference does not claim to
            match every custom rule.
          </p>
          <p>
            Auction estimates fit other complete auctions with matching scoring
            and roster slots, paired by exact player identity to Sleeper ADP.
            Bid shares use total room budget to adjust different team counts.
            The fitted price curve is monotone and excludes the entire
            purchase’s own draft. No manual input is needed.
          </p>
          <p>
            ADP observed{" "}
            {data?.marketFetchedAt
              ? new Date(data.marketFetchedAt).toLocaleString()
              : "not yet available"}
            . This is a current reference, potentially after your draft, not a
            recovered draft-day snapshot. Stats checked{" "}
            {data?.statsFetchedAt
              ? new Date(data.statsFetchedAt).toLocaleString()
              : "not yet available"}
            . Projected points never enter actual results.
          </p>
          <details>
            <summary className="cursor-pointer font-medium text-foreground">
              Source and calculation details
            </summary>
            <div className="mt-3 space-y-3">
              <p>
                The ADP and weekly-stat feeds are verified Sleeper consumer
                endpoints, separate from its documented v1 league API. Their
                availability is not guaranteed. Missing feeds suppress
                comparisons.
              </p>
              <p>
                ADP value = pick equivalent − player market ADP. Price-implied
                rank interpolates the selected position’s ADP curve. Rank gain =
                price-implied rank − actual positional rank. Points above price
                use the interpolated completed-week points at that implied rank.
                Ties share ranks; players need a recorded game.
              </p>
              <p>
                {data?.membershipCount ?? "—"} total memberships remain
                available in the league tracker. {data?.unresolvedDrafts ?? 0}{" "}
                boards have unresolved source responses.
              </p>
              <a
                className="underline"
                href={data?.marketUrl ?? "https://docs.sleeper.com/"}
                target="_blank"
                rel="noreferrer"
              >
                Inspect the ADP source
              </a>
            </div>
          </details>
        </CardContent>
      </Card>
    </section>
  )
}
