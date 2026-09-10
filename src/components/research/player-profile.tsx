"use client"
import { useEffect, useState } from "react"
import Link from "next/link"
import type { ColumnDef } from "@tanstack/react-table"
import { DataTable } from "@/components/data/data-table"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card"
import type { PlayerProfile as Profile } from "@/lib/research/types"
import {
  AcquisitionTable,
  fieldLabel,
  formatNumber as n,
  Metric,
  useResearch,
} from "./research-workbench"

function Trajectory({
  profile,
  baseline,
  baselineLabel,
}: {
  profile: Profile
  baseline: number | null
  baselineLabel: string
}) {
  const rows = profile.weekly,
    known = rows.filter((r) => r.rank !== null),
    max = Math.max(10, baseline ?? 0, ...known.map((r) => r.rank!)) * 1.1
  const x = (week: number) =>
      55 + ((week - 1) * 650) / Math.max(rows.length - 1, 1),
    y = (rank: number) => 30 + ((rank - 1) / max) * 220
  return (
    <Card>
      <CardHeader>
        <CardTitle>Price and rank trajectory</CardTitle>
        <CardDescription>
          Lower rank is better. The dashed line shows the labelled purchase
          benchmark or market reference. Open circles mark unfinished weeks.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {!known.length ? (
          <p className="py-10 text-center text-sm text-muted-foreground">
            No recorded game yet. The trajectory begins with actual weekly
            results.
          </p>
        ) : (
          <svg
            viewBox="0 0 760 300"
            role="img"
            aria-label="Weekly cumulative positional rank compared with price-implied rank"
            className="w-full text-foreground"
          >
            {[1, Math.round(max / 2), Math.round(max)].map((rank) => (
              <g key={rank}>
                <line
                  x1="50"
                  x2="720"
                  y1={y(rank)}
                  y2={y(rank)}
                  stroke="currentColor"
                  opacity="0.12"
                />
                <text
                  x="40"
                  y={y(rank) + 4}
                  textAnchor="end"
                  fill="currentColor"
                  fontSize="12"
                >
                  {rank}
                </text>
              </g>
            ))}
            {baseline !== null ? (
              <g>
                <line
                  x1="50"
                  x2="720"
                  y1={y(baseline)}
                  y2={y(baseline)}
                  stroke="currentColor"
                  opacity="0.6"
                  strokeDasharray="6 5"
                />
                <text
                  x="720"
                  y={Math.max(14, y(baseline) - 8)}
                  textAnchor="end"
                  fill="currentColor"
                  fontSize="12"
                >
                  {baselineLabel} {n(baseline)}
                </text>
              </g>
            ) : null}
            {rows.map((r, i) => {
              const before = rows[i - 1]
              return r.rank === null ? null : (
                <g key={r.week}>
                  {before?.rank !== null && before?.rank !== undefined ? (
                    <line
                      x1={x(before.week)}
                      y1={y(before.rank)}
                      x2={x(r.week)}
                      y2={y(r.rank)}
                      stroke="currentColor"
                      strokeWidth="2"
                    />
                  ) : null}
                  <circle
                    cx={x(r.week)}
                    cy={y(r.rank)}
                    r="5"
                    fill={r.provisional ? "var(--background)" : "currentColor"}
                    stroke="currentColor"
                    strokeWidth="2"
                  >
                    <title>
                      Week {r.week}: rank {r.rank}
                      {r.provisional ? " · provisional" : ""}
                    </title>
                  </circle>
                  <text
                    x={x(r.week)}
                    y="284"
                    textAnchor="middle"
                    fontSize="12"
                    fill="currentColor"
                  >
                    W{r.week}
                  </text>
                </g>
              )
            })}
          </svg>
        )}
      </CardContent>
    </Card>
  )
}
function ResearchNotes({ token }: { token: string }) {
  const [note, setNote] = useState(""),
    [saved, setSaved] = useState(""),
    [watched, setWatched] = useState(false)
  useEffect(() => {
    let active = true
    void Promise.resolve().then(() => {
      try {
        if (active) {
          setNote(localStorage.getItem(`fantasyhud:notes:${token}`) ?? "")
          setWatched(localStorage.getItem(`fantasyhud:watch:${token}`) === "1")
        }
      } catch {}
    })
    return () => {
      active = false
    }
  }, [token])
  function save() {
    try {
      localStorage.setItem(`fantasyhud:notes:${token}`, note)
      setSaved("Saved in this browser.")
    } catch {
      setSaved("This browser could not save the note.")
    }
  }
  return (
    <Card>
      <CardHeader>
        <CardTitle>Research notes</CardTitle>
        <CardDescription>
          Personal notes and watch status stay in this browser. They do not
          alter your league data.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <Button
          variant="outline"
          aria-pressed={watched}
          onClick={() => {
            try {
              localStorage.setItem(
                `fantasyhud:watch:${token}`,
                watched ? "0" : "1"
              )
              setWatched(!watched)
            } catch {
              setSaved("Watch status could not be saved.")
            }
          }}
        >
          {watched ? "Watching this player" : "Watch this player"}
        </Button>
        <label className="block text-sm" htmlFor="research-notes">
          Your notes
        </label>
        <textarea
          id="research-notes"
          className="min-h-32 w-full rounded-md border bg-background p-3 text-sm"
          value={note}
          maxLength={3000}
          onChange={(e) => {
            setNote(e.target.value)
            setSaved("")
          }}
        />
        <div className="flex items-center gap-3">
          <Button onClick={save}>Save notes</Button>
          <p role="status" className="text-sm text-muted-foreground">
            {saved}
          </p>
        </div>
      </CardContent>
    </Card>
  )
}
export function PlayerProfile({
  token,
  initialContext,
}: {
  token: string
  initialContext: string | null
}) {
  const [context, setContext] = useState(initialContext),
    [tab, setTab] = useState<"performance" | "purchases" | "notes">(
      "performance"
    )
  const { data, error, loading, refresh } = useResearch<Profile>(
    `/api/research?player=${token}${context ? `&context=${context}` : ""}`
  )
  const acquisition = data?.acquisitions.find(
    (a) => a.leagueToken === data.context.token
  )
  const weeklyColumns: ColumnDef<Profile["weekly"][number]>[] = [
    { accessorKey: "week", header: "Week" },
    { accessorKey: "opponent", header: "Opponent" },
    {
      accessorKey: "points",
      header: "League points",
      cell: ({ getValue }) => n(getValue<number | null>()),
    },
    {
      accessorKey: "cumulative",
      header: "Cumulative points",
      cell: ({ getValue }) => n(getValue<number | null>()),
    },
    {
      accessorKey: "rank",
      header: "Cumulative position rank",
      cell: ({ getValue }) => n(getValue<number | null>()),
    },
    { accessorKey: "status", header: "Status" },
  ]
  return (
    <div className="space-y-6">
      <Link href="/players" className="text-sm underline underline-offset-4">
        Back to players
      </Link>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {!data ? (
        <Card>
          <CardHeader>
            <CardTitle>
              {loading
                ? "Loading player profile…"
                : "Player profile unavailable"}
            </CardTitle>
            <CardDescription>
              Resolving source identity, your draft purchases and league-scored
              weekly results.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button onClick={() => void refresh()}>Retry</Button>
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-semibold tracking-tight">
                {data.player.name}
              </h1>
              <p className="mt-1 text-sm text-muted-foreground">
                {data.player.position} ·{" "}
                {data.player.team ?? "Team unavailable"} · {data.season}
                {data.player.injury ? ` · ${data.player.injury}` : ""}
              </p>
              <p className="mt-2 text-sm">
                Held in {data.player.held} leagues · Drafted{" "}
                {data.player.drafted} times
              </p>
            </div>
            <Button variant="outline" onClick={() => void refresh()}>
              Refresh profile
            </Button>
          </div>
          <label className="block text-sm">
            League scoring context{" "}
            <select
              className="mt-2 block w-full max-w-lg rounded-md border bg-background p-2"
              value={context ?? data.context.token}
              onChange={(e) => setContext(e.target.value)}
            >
              {data.contexts.map((c) => (
                <option key={c.token} value={c.token}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <p className="text-sm text-muted-foreground">
            Showing {data.context.name} · {fieldLabel(data.adpField)} market
            reference. Points use the exact scoring rules below.
          </p>
          {data.issues.map((issue) => (
            <p role="alert" className="text-sm text-destructive" key={issue}>
              {issue}
            </p>
          ))}
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <Metric
              label="Sleeper market ADP"
              value={n(data.marketAdp)}
              detail={`${fieldLabel(data.adpField)} · ${data.player.position} ${n(data.marketRank)}`}
            />
            <Metric
              label="Price-implied position rank"
              value={
                acquisition
                  ? `${data.player.position} ${acquisition.rankBound ? `${acquisition.rankBound.direction === "at_most" ? "≤" : "≥"} ${n(acquisition.rankBound.value)}` : n(acquisition.impliedRank)}`
                  : "No purchase"
              }
              detail={
                acquisition
                  ? `${acquisition.draftType === "auction" ? "$" : "Pick "}${n(acquisition.paid)}${acquisition.draftType === "auction" ? ` ${acquisition.adpBound ? `${acquisition.adpBound.direction === "at_most" ? "≤" : "≥"} pick ${n(acquisition.adpBound.value)}` : `≈ pick ${n(acquisition.equivalentAdp)}`}` : ""}`
                  : "Choose a league where you drafted this player"
              }
            />
            <Metric
              label="Points including live week"
              value={n(data.livePoints)}
              detail={`${data.games} recorded ${data.games === 1 ? "game" : "games"} · ${n(data.ppg)} points per game`}
            />
            <Metric
              label="Completed-week position rank"
              value={
                data.actualRank === null
                  ? "Pending"
                  : `${data.player.position} ${data.actualRank}`
              }
              detail={
                data.completedWeek
                  ? `Through week ${data.completedWeek}`
                  : "Available after the first week closes"
              }
            />
          </div>
          <Card>
            <CardHeader>
              <CardTitle>Your price → season return</CardTitle>
              <CardDescription>
                {acquisition
                  ? `You paid ${acquisition.draftType === "auction" ? `$${n(acquisition.paid)} from a $${n(acquisition.budget)} budget` : `overall pick ${n(acquisition.paid)}`}. ${acquisition.impliedRank === null ? (acquisition.reason ?? "A price rank is unavailable.") : `That price implies ${data.player.position} ${n(acquisition.impliedRank)} on the current market curve.`} ${data.actualRank === null ? "A completed-week return is not available yet." : `The recorded completed-week result is ${data.player.position} ${data.actualRank}.`}`
                  : "This player has no acquisition in the selected league. Market and performance research are still available."}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-2 text-sm text-muted-foreground">
              <p>
                {data.liveRank !== null
                  ? `Live rank: ${data.player.position} ${data.liveRank} among ${data.eligiblePlayers} players at this position with recorded games. The current week is unfinished, so this partial rank does not generate season gain/loss.`
                  : "No qualifying recorded game yet; an absent score is not treated as a zero-point finish."}
              </p>
              {acquisition?.draftType === "auction" ? (
                <p>
                  Auction bridge: {acquisition.peerDrafts} other drafts ·{" "}
                  {acquisition.matchedPlayers} players paired to ADP. Exact
                  scoring and roster-slot match
                  {acquisition.adjustedTeams
                    ? ", with team-count adjustment using total room capital"
                    : ""}
                  . This is an estimated pick equivalent; your own draft
                  contributes no benchmark bids.
                </p>
              ) : null}
            </CardContent>
          </Card>
          <div className="flex flex-wrap gap-2">
            <Button
              variant={tab === "performance" ? "default" : "outline"}
              onClick={() => setTab("performance")}
            >
              Weekly performance
            </Button>
            <Button
              variant={tab === "purchases" ? "default" : "outline"}
              onClick={() => setTab("purchases")}
            >
              All acquisitions ({data.acquisitions.length})
            </Button>
            <Button
              variant={tab === "notes" ? "default" : "outline"}
              onClick={() => setTab("notes")}
            >
              Research notes
            </Button>
          </div>
          {tab === "performance" ? (
            <>
              <Trajectory
                profile={data}
                baseline={
                  acquisition
                    ? (acquisition.impliedRank ??
                      acquisition.rankBound?.value ??
                      null)
                    : data.marketRank
                }
                baselineLabel={
                  acquisition
                    ? acquisition.rankBound
                      ? `Price bound ${acquisition.rankBound.direction === "at_most" ? "≤" : "≥"}`
                      : "Price"
                    : "Market"
                }
              />
              <DataTable
                ariaLabel="Player weekly results"
                title="Weekly results"
                description="Points are recomputed from actual event statistics using this league’s scoring. Ranks include all source players at this position with recorded games, not just drafted players. No-game and missing-source weeks are explicit."
                columns={weeklyColumns}
                data={data.weekly}
                getRowId={(r) => String(r.week)}
                searchText=""
                countNoun="weeks"
              />
              <Card>
                <CardHeader>
                  <CardTitle>Recorded football statistics</CardTitle>
                  <CardDescription>
                    Actual event counts used in this league’s scoring. Projected
                    points and provider generic ranks are excluded.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  {data.weekly.map((w) => (
                    <details key={w.week}>
                      <summary className="cursor-pointer text-sm">
                        Week {w.week} · {w.status}
                      </summary>
                      <dl className="mt-3 grid gap-2 sm:grid-cols-2">
                        {Object.entries(w.stats ?? {})
                          .filter(
                            ([key]) =>
                              data.context.scoring[key] !== undefined ||
                              [
                                "gp",
                                "pass_yd",
                                "rush_yd",
                                "rec_yd",
                                "rec",
                              ].includes(key)
                          )
                          .map(([key, value]) => (
                            <div
                              className="flex justify-between gap-3 text-sm"
                              key={key}
                            >
                              <dt>{key}</dt>
                              <dd>{n(value)}</dd>
                            </div>
                          ))}
                      </dl>
                    </details>
                  ))}
                </CardContent>
              </Card>
            </>
          ) : tab === "purchases" ? (
            <AcquisitionTable
              rows={data.acquisitions}
              title="Every draft acquisition"
            />
          ) : (
            <ResearchNotes key={token} token={token} />
          )}
          <Card>
            <CardHeader>
              <CardTitle>Scoring and provenance</CardTitle>
              <CardDescription>
                Current-reference ADP observed{" "}
                {data.marketFetchedAt
                  ? new Date(data.marketFetchedAt).toLocaleString()
                  : "unavailable"}
                . Actual stats checked{" "}
                {data.statsFetchedAt
                  ? new Date(data.statsFetchedAt).toLocaleString()
                  : "unavailable"}
                .
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4 text-sm text-muted-foreground">
              <p>
                The ADP observation may postdate your draft. Its exact
                custom-scoring cohort and sample size are not supplied by
                Sleeper. These are verified consumer feeds, distinct from the
                documented league API. Weekly results use actual statistics, and
                supported scoring is cross-checked against league matchup player
                scores.
              </p>
              <details>
                <summary className="cursor-pointer text-foreground">
                  Exact league rules and lineup
                </summary>
                <p className="my-3">{data.context.positions.join(" · ")}</p>
                <dl className="grid gap-2 sm:grid-cols-2">
                  {Object.entries(data.context.scoring)
                    .filter(([, v]) => v !== 0)
                    .map(([key, value]) => (
                      <div className="flex justify-between gap-3" key={key}>
                        <dt>{key}</dt>
                        <dd>{String(value)}</dd>
                      </div>
                    ))}
                </dl>
              </details>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  )
}
