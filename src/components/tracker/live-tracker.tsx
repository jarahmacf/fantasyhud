"use client"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import Link from "next/link"
import type { ColumnDef } from "@tanstack/react-table"
import { RefreshCw, Download, ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card"
import { DataTable } from "@/components/data/data-table"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"
import {
  evaluateTrackerDraft,
  mergeTrackerOverview,
  mergeTrackerDetail,
  type TrackerOverview,
  type TrackerDetail,
  type TrackerLeague,
  type TrackerPlayer,
} from "@/lib/tracker/model"
const number = (n: number | null | undefined) =>
  n == null ? "—" : n.toLocaleString(undefined, { maximumFractionDigits: 2 })
const delta = (n: number | null | undefined) =>
  n == null ? "—" : `${n > 0 ? "+" : ""}${number(n)}`
function download(data: unknown, name: string) {
  const url = URL.createObjectURL(
    new Blob([JSON.stringify(data, null, 2)], { type: "application/json" })
  )
  const a = document.createElement("a")
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}
async function request<T>(path: string, signal?: AbortSignal): Promise<T> {
  const r = await fetch(path, { cache: "no-store", signal })
  if (!r.ok)
    throw new Error(
      "Sleeper could not refresh right now. The last displayed data is retained."
    )
  return r.json() as Promise<T>
}
export function LiveTracker() {
  const [data, setData] = useState<TrackerOverview | null>(null),
    [error, setError] = useState<string | null>(null),
    [loading, setLoading] = useState(true)
  const [search, setSearch] = useState(""),
    [tab, setTab] = useState<"leagues" | "players" | "drafts">("leagues")
  const [portfolio, setPortfolio] = useState<Record<string, TrackerDetail>>({})
  const [bulk, setBulk] = useState<{
    done: number
    total: number
    failed: number
    running: boolean
  }>({ done: 0, total: 0, failed: 0, running: false })
  const bulkAbort = useRef<AbortController | null>(null)
  useEffect(() => () => bulkAbort.current?.abort(), [])
  async function loadAllDrafts() {
    if (!data || bulk.running) return
    const controller = new AbortController()
    bulkAbort.current = controller
    const queue = data.leagues.filter((l) => !l.error)
    let next = 0
    setBulk({ done: 0, total: queue.length, failed: 0, running: true })
    setTab("drafts")
    const worker = async () => {
      while (next < queue.length && !controller.signal.aborted) {
        const league = queue[next++]!
        let failed = false
        try {
          const detail = await request<TrackerDetail>(
            `/api/tracker?league=${league.token}`,
            controller.signal
          )
          failed =
            Boolean(detail.league.error) ||
            detail.drafts.some((d) => Boolean(d.error)) ||
            detail.weeks.some((w) => Boolean(w.error))
          setPortfolio((p) => ({
            ...p,
            [league.token]: mergeTrackerDetail(p[league.token], detail),
          }))
        } catch {
          failed = true
          setPortfolio((p) => {
            const old = p[league.token]
            if (!old) return p
            const error = "The latest refresh failed. Previous data retained."
            return {
              ...p,
              [league.token]: {
                ...old,
                league: { ...old.league, error },
                weeks: old.weeks.map((w) => ({ ...w, error })),
              },
            }
          })
        }
        if (!controller.signal.aborted)
          setBulk((p) => ({
            ...p,
            done: p.done + 1,
            failed: p.failed + (failed ? 1 : 0),
          }))
      }
    }
    await Promise.all([worker(), worker()])
    if (!controller.signal.aborted) setBulk((p) => ({ ...p, running: false }))
  }
  const [selection, setSelection] = useState<string | null>(null),
    [detail, setDetail] = useState<TrackerDetail | null>(null),
    [detailError, setDetailError] = useState<string | null>(null)
  const refresh = useCallback(
    (signal?: AbortSignal) =>
      request<TrackerOverview>("/api/tracker", signal)
        .then((result) => {
          setData((previous) =>
            previous && previous.fetchedAt > result.fetchedAt
              ? previous
              : mergeTrackerOverview(previous, result)
          )
          setError(null)
        })
        .catch((e) => {
          if (!signal?.aborted) setError((e as Error).message)
        })
        .finally(() => {
          if (!signal?.aborted) setLoading(false)
        }),
    []
  )
  useEffect(() => {
    const controller = new AbortController()
    void refresh(controller.signal)
    const timer = setInterval(() => {
      if (document.visibilityState === "visible")
        void refresh(controller.signal)
    }, 120_000)
    return () => {
      controller.abort()
      clearInterval(timer)
    }
  }, [refresh])
  useEffect(() => {
    if (!selection) return
    const controller = new AbortController()
    void request<TrackerDetail>(
      `/api/tracker?league=${encodeURIComponent(selection)}`,
      controller.signal
    )
      .then((value) => {
        setDetail((previous) => mergeTrackerDetail(previous, value))
        setDetailError(null)
      })
      .catch((e) => {
        if (!controller.signal.aborted) setDetailError((e as Error).message)
      })
    return () => controller.abort()
  }, [selection, data?.fetchedAt])
  const openLeague = useCallback((league: TrackerLeague) => {
    setDetail(null)
    setDetailError(null)
    setSelection(league.token)
  }, [])
  const leagues = data?.leagues ?? []
  const columns = useMemo<ColumnDef<TrackerLeague>[]>(
    () => [
      {
        accessorKey: "name",
        header: "League",
        cell: ({ row }) => (
          <button
            className="text-left font-medium underline-offset-4 hover:underline"
            onClick={() => openLeague(row.original)}
          >
            {row.original.name}
          </button>
        ),
      },
      {
        id: "format",
        header: "Format",
        accessorFn: (l) =>
          `${l.bestBall ? "Best ball · " : ""}${l.management} · ${l.format}`,
      },
      {
        id: "record",
        header: "Record",
        accessorFn: (l) => {
          const r = l.rosters.find((r) => r.owned)
          return r
            ? `${number(r.wins)}–${number(r.losses)}–${number(r.ties)}`
            : "Ownership unresolved"
        },
      },
      {
        id: "points",
        header: "Your score",
        accessorFn: (l) => {
          const r = l.rosters.find((r) => r.owned),
            m = l.matchups.find((m) => m.rosterId === r?.id)
          return m?.customPoints ?? m?.points ?? null
        },
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        id: "opponent",
        header: "Opponent score",
        accessorFn: (l) => {
          const r = l.rosters.find((r) => r.owned),
            m = l.matchups.find((m) => m.rosterId === r?.id)
          const opponents =
            m?.matchupId == null
              ? []
              : l.matchups.filter(
                  (x) =>
                    x.matchupId === m.matchupId && x.rosterId !== m.rosterId
                )
          return opponents.length === 1
            ? (opponents[0]!.customPoints ?? opponents[0]!.points)
            : null
        },
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        id: "status",
        header: "Source",
        accessorFn: (l) =>
          l.error
            ? "Refresh failed"
            : l.matchups.length
              ? "Current week · provisional"
              : "Matchups pending",
      },
    ],
    [openLeague]
  )
  const holdings = useMemo(() => {
    const profiles = new Map(data?.players.map((p) => [p.id, p]) ?? []),
      map = new Map<
        string,
        TrackerPlayer & { leagues: number; names: string }
      >()
    for (const league of data?.leagues ?? [])
      for (const id of new Set(
        league.rosters.filter((r) => r.owned).flatMap((r) => r.players ?? [])
      )) {
        const p = map.get(id) ?? {
          ...(profiles.get(id) ?? { id, name: id, position: "?", team: null }),
          leagues: 0,
          names: "",
        }
        p.leagues++
        p.names += " " + league.name
        map.set(id, p)
      }
    return [...map.values()].sort((a, b) => b.leagues - a.leagues)
  }, [data])
  const draftRows = useMemo(
    () =>
      Object.values(portfolio)
        .filter((detail) =>
          data?.leagues.some((l) => l.token === detail.league.token)
        )
        .flatMap((detail) =>
          detail.drafts.flatMap((draft) => {
            try {
              return evaluateTrackerDraft(draft, detail.weeks, data!.week)
                .filter((p) => p.own)
                .map((p) => ({
                  ...p,
                  key: `${detail.league.token}:${draft.id}:${p.id}`,
                  league: detail.league.name,
                  type: draft.type,
                  sourceStatus: detail.league.error
                    ? "Refresh failed"
                    : draft.error
                      ? "Board refresh failed"
                      : detail.weeks.some((w) => w.error)
                        ? "Weekly refresh failed"
                        : "Source recorded",
                }))
            } catch {
              return []
            }
          })
        ),
    [portfolio, data]
  )
  const draftColumns = useMemo<ColumnDef<(typeof draftRows)[number]>[]>(
    () => [
      { accessorKey: "name", header: "Player" },
      { accessorKey: "position", header: "Position" },
      { accessorKey: "league", header: "League" },
      { accessorKey: "type", header: "Draft type" },
      { accessorKey: "sourceStatus", header: "Source" },
      {
        id: "cost",
        header: "Cost",
        accessorFn: (p) =>
          p.type === "auction"
            ? p.amount === null
              ? "Unknown"
              : `$${number(p.amount)}`
            : `Pick ${p.pick}`,
      },
      {
        accessorKey: "priceRank",
        header: "Draft-cost rank",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "actualRank",
        header: "Scored rank",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "rankDelta",
        header: "Rank gain/loss",
        cell: ({ getValue }) => delta(getValue<number | null>()),
      },
      {
        accessorKey: "points",
        header: "Observed points",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "pointsAbovePrice",
        header: "Points above price",
        cell: ({ getValue }) => delta(getValue<number | null>()),
      },
    ],
    []
  )
  const playerColumns = useMemo<ColumnDef<(typeof holdings)[number]>[]>(
    () => [
      { accessorKey: "name", header: "Player" },
      { accessorKey: "position", header: "Position" },
      { accessorKey: "team", header: "Catalog team" },
      { accessorKey: "leagues", header: "Leagues held" },
      {
        id: "exposure",
        header: "Exposure",
        accessorFn: (p) =>
          leagues.length
            ? `${Math.round((p.leagues / leagues.length) * 100)}%`
            : "—",
      },
    ],
    [leagues.length]
  )
  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          {data
            ? `${data.season} · Week ${data.week} · ${data.seasonType} · Checked ${new Date(data.fetchedAt).toLocaleTimeString()}`
            : "Loading your live Sleeper portfolio…"}
        </p>
        <div className="flex flex-wrap gap-2">
          <Button
            variant="outline"
            disabled={loading}
            onClick={() => {
              setLoading(true)
              void refresh()
            }}
          >
            <RefreshCw className={loading ? "animate-spin" : ""} />
            {loading ? "Refreshing…" : "Refresh"}
          </Button>
          <Button
            variant="outline"
            disabled={!data}
            onClick={() =>
              download(
                {
                  overview: data,
                  selectedLeague: detail,
                  draftPortfolio: portfolio,
                },
                `fantasyhud-week-${data?.week}.json`
              )
            }
          >
            <Download />
            Export snapshot
          </Button>
        </div>
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          {
            label: "Current leagues",
            value: data ? leagues.length : null,
            detail: "Complete current-season discovery",
          },
          {
            label: "Confirmed rosters",
            value: data
              ? leagues.reduce(
                  (n, l) => n + l.rosters.filter((r) => r.owned).length,
                  0
                )
              : null,
            detail: "Owner or source-confirmed co-owner",
          },
          {
            label: "Unique players held",
            value: data ? holdings.length : null,
            detail: "Current holdings, separate from draft picks",
          },
          {
            label: "League refresh issues",
            value: data ? leagues.filter((l) => l.error).length : null,
            detail: "Missing responses never become zero scores",
          },
        ].map((m) => (
          <Card key={m.label}>
            <CardHeader>
              <CardDescription>{m.label}</CardDescription>
              <CardTitle className="text-2xl tabular-nums">
                {number(m.value)}
              </CardTitle>
              <CardDescription>{m.detail}</CardDescription>
            </CardHeader>
          </Card>
        ))}
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Button
          variant={tab === "leagues" ? "default" : "outline"}
          onClick={() => setTab("leagues")}
        >
          Leagues & matchups
        </Button>
        <Button
          variant={tab === "players" ? "default" : "outline"}
          onClick={() => setTab("players")}
        >
          Player exposure
        </Button>
        <Button
          variant={tab === "drafts" ? "default" : "outline"}
          onClick={() => setTab("drafts")}
        >
          Draft portfolio
        </Button>
        <Button
          variant="outline"
          disabled={!data || bulk.running}
          onClick={() => void loadAllDrafts()}
        >
          {bulk.running
            ? `Loading ${bulk.done}/${bulk.total}…`
            : Object.keys(portfolio).length
              ? "Refresh all draft boards"
              : "Load all draft boards"}
        </Button>
        <Input
          className="sm:ml-auto sm:w-72"
          aria-label="Search live tracker"
          placeholder="Search your portfolio…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      {bulk.total > 0 ? (
        <p role="status" className="text-sm text-muted-foreground">
          Draft boards checked: {bulk.done}/{bulk.total}.{" "}
          {bulk.failed
            ? `${bulk.failed} refreshes failed; prior results are retained.`
            : ""}
        </p>
      ) : null}
      {tab === "drafts" ? (
        <DataTable
          ariaLabel="Whole draft portfolio"
          title="All your draft selections"
          columns={draftColumns}
          data={draftRows}
          getRowId={(p) => p.key}
          searchText={search}
          countNoun="selections"
          description="Costs and rank comparisons stay within each league, draft and position. No rank deltas are averaged across positions. Load all boards to populate this view."
        />
      ) : tab === "leagues" ? (
        <DataTable
          ariaLabel="Live league matchups"
          title="All your leagues"
          columns={columns}
          data={leagues}
          getRowId={(l) => l.token}
          searchText={search}
          countNoun="leagues"
          description="Open a league for every draft, current rosters, matchup history and price-versus-score tracking."
          emptyMessage={
            loading
              ? "Fetching current-season leagues…"
              : "No league results available."
          }
        />
      ) : (
        <DataTable
          ariaLabel="Live player exposure"
          title="Current player exposure"
          columns={playerColumns}
          data={holdings}
          getRowId={(p) => p.id}
          searchText={search}
          countNoun="players"
          description="Exposure counts current confirmed holdings. Catalog team and position are current labels, not historical draft facts."
        />
      )}
      <Card>
        <CardHeader>
          <CardTitle>Draft price and performance</CardTitle>
          <CardDescription>
            Open a league to compare its draft-cost position rank with
            Sleeper-scored results. These are league draft-pool ranks, not
            full-NFL ranks or market ADP. Current-week scores are provisional;
            missing player-weeks suppress rank comparisons.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button variant="outline" asChild>
            <Link href="/draft-value">
              Open market ADP / auction price calculator
              <ArrowRight />
            </Link>
          </Button>
          <p className="mt-3 text-sm text-muted-foreground">
            The league overview refreshes every two minutes while this page is
            visible. Use Refresh all draft boards to update portfolio values.
            Sleeper retains matchup history; export a snapshot for a dated copy.
            This view reads live source data and does not overwrite your saved
            imports.
          </p>
        </CardContent>
      </Card>
      <Sheet
        open={selection !== null}
        onOpenChange={(open) => {
          if (!open) setSelection(null)
        }}
      >
        <SheetContent className="w-full overflow-y-auto sm:max-w-5xl">
          <SheetHeader>
            <SheetTitle>{detail?.league.name ?? "Loading league…"}</SheetTitle>
            <SheetDescription>
              Exact league scoring · all draft boards · weekly source history
            </SheetDescription>
          </SheetHeader>
          <div className="space-y-6 p-4">
            {detailError ? (
              <p role="alert">{detailError}</p>
            ) : detail ? (
              <LeagueDetail detail={detail} players={data?.players ?? []} />
            ) : (
              <p className="text-sm text-muted-foreground">
                Fetching full boards and weekly matchups…
              </p>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </>
  )
}
function LeagueDetail({
  detail,
  players,
}: {
  detail: TrackerDetail
  players: TrackerPlayer[]
}) {
  const [draftId, setDraftId] = useState(detail.drafts[0]?.id ?? ""),
    [onlyOwn, setOnlyOwn] = useState(true),
    [search, setSearch] = useState("")
  const draft = detail.drafts.find((d) => d.id === draftId) ?? detail.drafts[0]
  const rows = useMemo(() => {
    if (!draft) return []
    try {
      return evaluateTrackerDraft(draft, detail.weeks, detail.weeks.length)
    } catch {
      return []
    }
  }, [draft, detail.weeks])
  const columns = useMemo<ColumnDef<(typeof rows)[number]>[]>(
    () => [
      { accessorKey: "name", header: "Drafted player" },
      { accessorKey: "position", header: "Draft position" },
      {
        id: "cost",
        header: "Paid",
        accessorFn: (p) => (draft?.type === "auction" ? p.amount : p.pick),
        cell: ({ row }) =>
          draft?.type === "auction"
            ? row.original.amount === null
              ? "Unknown"
              : `$${number(row.original.amount)}`
            : draft?.teams
              ? `${Math.floor((row.original.pick - 1) / draft.teams) + 1}.${String(((row.original.pick - 1) % draft.teams) + 1).padStart(2, "0")}`
              : number(row.original.pick),
      },
      {
        accessorKey: "priceRank",
        header: "Draft-cost rank",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "actualRank",
        header: "Scored rank",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "rankDelta",
        header: "Rank gain/loss",
        cell: ({ getValue }) => delta(getValue<number | null>()),
      },
      {
        accessorKey: "points",
        header: "Observed points",
        cell: ({ getValue }) => number(getValue<number | null>()),
      },
      {
        accessorKey: "pointsAbovePrice",
        header: "Points above price",
        cell: ({ getValue }) => delta(getValue<number | null>()),
      },
      { accessorKey: "observedWeeks", header: "Scored weeks" },
      {
        id: "keeper",
        header: "Keeper",
        accessorFn: (p) =>
          p.keeper === null ? "Unknown" : p.keeper ? "Yes" : "No",
      },
    ],
    [draft]
  )
  const profiles = new Map(players.map((p) => [p.id, p]))
  const ownedIds = new Set(
    detail.league.rosters.filter((r) => r.owned).map((r) => r.id)
  )
  const weekly = detail.weeks.flatMap((w) =>
    [...ownedIds].map((id) => {
      const m = w.matchups?.find((m) => m.rosterId === id)
      const other =
        m?.matchupId == null
          ? []
          : (w.matchups?.filter(
              (x) => x.matchupId === m.matchupId && x.rosterId !== id
            ) ?? [])
      return {
        id: `${w.week}:${id}`,
        week: w.week,
        points: m?.customPoints ?? m?.points ?? null,
        opponent:
          other.length === 1
            ? (other[0]!.customPoints ?? other[0]!.points)
            : null,
        status: w.error
          ? "Unavailable"
          : w.week === detail.weeks.length
            ? "Provisional"
            : "Source recorded",
      }
    })
  )
  const weekColumns: ColumnDef<(typeof weekly)[number]>[] = [
    { accessorKey: "week", header: "Week" },
    {
      accessorKey: "points",
      header: "Your score",
      cell: ({ getValue }) => number(getValue<number | null>()),
    },
    {
      accessorKey: "opponent",
      header: "Opponent score",
      cell: ({ getValue }) => number(getValue<number | null>()),
    },
    { accessorKey: "status", header: "Status" },
  ]
  return (
    <>
      <div className="flex flex-wrap gap-2">
        <Button
          variant="outline"
          onClick={() =>
            download(detail, `fantasyhud-${detail.league.token}.json`)
          }
        >
          <Download />
          Export this league
        </Button>
      </div>
      <DataTable
        ariaLabel="League weekly matchups"
        title="Weekly matchups"
        columns={weekColumns}
        data={weekly}
        getRowId={(w) => w.id}
        searchText=""
        countNoun="weeks"
      />
      <Card>
        <CardHeader>
          <CardTitle>Your current roster</CardTitle>
          <CardDescription>
            {detail.league.rosters
              .filter((r) => r.owned)
              .flatMap((r) => r.players ?? [])
              .map((id) => profiles.get(id)?.name ?? id)
              .join(" · ") || "Ownership unresolved or roster not supplied."}
          </CardDescription>
        </CardHeader>
      </Card>
      <div className="flex flex-wrap items-center gap-3">
        <label className="text-sm">
          Draft{" "}
          <select
            className="ml-2 rounded-md border bg-background p-2"
            value={draft?.id ?? ""}
            onChange={(e) => setDraftId(e.target.value)}
          >
            {detail.drafts.map((d, i) => (
              <option key={d.id} value={d.id}>
                Board {i + 1} · {d.type} · {d.picks.length} picks
              </option>
            ))}
          </select>
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={onlyOwn}
            onChange={(e) => setOnlyOwn(e.target.checked)}
          />
          My selections
        </label>
        <Input
          aria-label="Search drafted players"
          placeholder="Search draft board…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      {draft?.error ? <p role="alert">{draft.error}</p> : null}
      <DataTable
        ariaLabel="Draft price and league performance"
        title="Draft value tracker"
        columns={columns}
        data={rows.filter((r) => !onlyOwn || r.own)}
        getRowId={(r) => r.id}
        searchText={search}
        countNoun="selections"
        description={`${draft?.complete ? "Complete board" : "Unfinished board"}. Draft-cost rank ${draft?.type === "auction" ? "uses dollars paid" : "follows selection order"} within each position. Scored rank uses this draft pool only. Missing player-weeks leave rank/gain/loss blank; a zero before any scoring activity is not a finish.`}
      />
      <Card>
        <CardHeader>
          <CardTitle>Exact scoring rules</CardTitle>
          <CardDescription>
            {detail.league.positions.join(" · ")}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <dl className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
            {Object.entries(detail.league.scoring)
              .filter(([, value]) => value !== 0)
              .map(([key, value]) => (
                <div key={key} className="flex justify-between gap-3">
                  <dt>{key}</dt>
                  <dd className="tabular-nums">{String(value)}</dd>
                </div>
              ))}
          </dl>
        </CardContent>
      </Card>
    </>
  )
}
