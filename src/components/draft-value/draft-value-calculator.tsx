"use client"

import { useState, type FormEvent } from "react"
import type { ColumnDef } from "@tanstack/react-table"
import { DataTable } from "@/components/data/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  calculateManualBenchmark,
  compareManualOutcome,
  comparisonKey,
  EMPTY_CALCULATOR,
  formatRank,
  formatSurplus,
  restoreManualCalculation,
  saveManualCalculation,
  type CalculatorInput,
  type ManualBenchmark,
  type ManualComparison,
  type ManualOutcomeInput,
} from "@/lib/draft-value/calculator"

const selectClass =
  "h-9 w-full rounded-md border border-input bg-background px-3 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:opacity-50"
const columns: ColumnDef<ManualComparison>[] = [
  { accessorKey: "week", header: "Through week", meta: { numeric: true } },
  {
    id: "metric",
    accessorFn: (row) =>
      row.rankingType === "season_total_points_rank"
        ? "Total points"
        : `PPG · ${row.minimumGames}+ games`,
    header: "Rank measure",
  },
  {
    accessorKey: "actualRank",
    header: "Actual positional rank",
    meta: { numeric: true },
  },
  {
    accessorKey: "surplus",
    header: "Rank surplus",
    meta: { numeric: true },
    cell: ({ row }) => formatSurplus(row.original.surplus),
  },
]

function TextField({
  label,
  id,
  value,
  onChange,
  ...props
}: {
  label: string
  id: string
  value: string
  onChange: (value: string) => void
} & Omit<React.ComponentProps<typeof Input>, "onChange" | "value" | "id">) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        {...props}
      />
    </div>
  )
}

export function DraftValueCalculator({ accountId }: { accountId: string }) {
  const [input, setInput] = useState<CalculatorInput>({ ...EMPTY_CALCULATOR })
  const [benchmark, setBenchmark] = useState<ManualBenchmark | null>(null)
  const [outcome, setOutcome] = useState<ManualOutcomeInput>({
    week: "1",
    rankingType: "season_total_points_rank",
    actualRank: "",
    minimumGames: "1",
    gamesPlayed: "1",
  })
  const [history, setHistory] = useState<ManualComparison[]>([])
  const [message, setMessage] = useState("")
  const [error, setError] = useState("")
  const [latest, setLatest] = useState<ManualComparison | null>(null)
  const storageKey = `fantasyhud:manual-draft-value:v1:${accountId}`

  function perform(action: () => void) {
    setError("")
    setMessage("")
    try {
      action()
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "The calculation could not be completed."
      )
    }
  }
  function update(key: keyof CalculatorInput, value: string) {
    setInput((current) => ({ ...current, [key]: value }))
  }
  function freeze(event: FormEvent) {
    event.preventDefault()
    perform(() => {
      setBenchmark(calculateManualBenchmark(input))
      setHistory([])
      setLatest(null)
      setMessage(
        "Benchmark fixed for this calculation. Add weekly ranks using the same scoring rules."
      )
    })
  }
  function compare(event: FormEvent) {
    event.preventDefault()
    perform(() => {
      if (!benchmark) return
      const row = compareManualOutcome(benchmark, outcome)
      setHistory((current) =>
        [
          ...current.filter(
            (entry) => comparisonKey(entry) !== comparisonKey(row)
          ),
          row,
        ].sort(
          (a, b) =>
            a.week - b.week || comparisonKey(a).localeCompare(comparisonKey(b))
        )
      )
      setLatest(row)
      setMessage(
        `Week ${row.week}: ${formatSurplus(row.surplus)} positions versus the price paid. Save on this device to keep your changes.`
      )
    })
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Price-to-rank calculator</CardTitle>
          <CardDescription>
            Enter a positional ADP or average auction value curve for one league
            format. These are manual calculations, separate from your portfolio
            records.
          </CardDescription>
          <CardAction>
            <Badge variant="outline">Manual inputs</Badge>
          </CardAction>
        </CardHeader>
        <CardContent>
          <form onSubmit={freeze} className="space-y-4">
            <fieldset disabled={benchmark !== null} className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                <div className="space-y-2">
                  <Label htmlFor="price-kind">Draft price</Label>
                  <select
                    id="price-kind"
                    value={input.kind}
                    onChange={(event) => update("kind", event.target.value)}
                    className={selectClass}
                  >
                    <option value="pick">Pick / ADP</option>
                    <option value="auction">Auction / AAV</option>
                  </select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="price-position">Position</Label>
                  <select
                    id="price-position"
                    value={input.position}
                    onChange={(event) => update("position", event.target.value)}
                    className={selectClass}
                  >
                    {["QB", "RB", "WR", "TE", "K", "DEF", "DL", "LB", "DB"].map(
                      (position) => (
                        <option key={position}>{position}</option>
                      )
                    )}
                  </select>
                </div>
                <TextField
                  id="price-teams"
                  label="Teams"
                  value={input.teams}
                  onChange={(value) => update("teams", value)}
                  inputMode="numeric"
                />
                <TextField
                  id="player-market-rank"
                  label="Player’s own market rank (optional)"
                  value={input.playerMarketRank}
                  onChange={(value) => update("playerMarketRank", value)}
                  inputMode="decimal"
                  placeholder="For example, 14"
                />
              </div>
              <TextField
                id="price-context"
                label="Scoring and league format"
                value={input.contextLabel}
                onChange={(value) => update("contextLabel", value)}
                maxLength={200}
                placeholder="League name, scoring, lineup, player pool and market source/date"
              />
              {input.kind === "pick" ? (
                <TextField
                  id="price-pick"
                  label="Round.selection paid"
                  value={input.roundPick}
                  onChange={(value) => update("roundPick", value)}
                  inputMode="decimal"
                  placeholder="3.10"
                />
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  <TextField
                    id="price-amount"
                    label="Auction amount paid"
                    value={input.auctionAmount}
                    onChange={(value) => update("auctionAmount", value)}
                    inputMode="decimal"
                  />
                  <TextField
                    id="price-budget"
                    label="Starting auction budget per team"
                    value={input.auctionBudget}
                    onChange={(value) => update("auctionBudget", value)}
                    inputMode="decimal"
                  />
                </div>
              )}
              <div className="space-y-2">
                <Label htmlFor="price-curve">Positional market curve</Label>
                <textarea
                  id="price-curve"
                  value={input.curve}
                  onChange={(event) => update("curve", event.target.value)}
                  rows={5}
                  maxLength={32768}
                  aria-describedby="price-curve-help"
                  placeholder={
                    input.kind === "pick"
                      ? "10, 30\n11, 34\n12, 39"
                      : "10, 40\n11, 30\n12, 20"
                  }
                  className="w-full rounded-md border border-input bg-transparent px-3 py-2 font-mono text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:opacity-50"
                />
                <p
                  id="price-curve-help"
                  className="text-xs text-muted-foreground"
                >
                  One rank, price per line. Include consecutive ranks around
                  your price.{" "}
                  {input.kind === "pick"
                    ? "ADP uses overall pick numbers, not round notation."
                    : "Enter average amounts using the same starting budget, minimum bid and roster rules as your purchase."}{" "}
                  Tied prices share a midpoint rank; prices outside the curve
                  have no estimate.
                </p>
              </div>
            </fieldset>
            <div className="flex flex-wrap gap-2">
              {!benchmark ? (
                <>
                  <Button type="submit">Freeze benchmark</Button>
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() =>
                      perform(() => {
                        setInput({
                          ...EMPTY_CALCULATOR,
                          contextLabel:
                            "Illustrative 12-team PPR example · invented market prices",
                          curve: "10, 30\n11, 34\n12, 39",
                          playerMarketRank: "14",
                        })
                        setMessage(
                          "Example loaded. These invented prices are not your league data."
                        )
                      })
                    }
                  >
                    Load example
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() =>
                      perform(() => {
                        const saved = localStorage.getItem(storageKey)
                        if (!saved)
                          throw new Error(
                            "No calculation is saved on this device."
                          )
                        const restored = restoreManualCalculation(saved)
                        setBenchmark(restored.benchmark)
                        setInput({ ...restored.benchmark.input })
                        setHistory(restored.history)
                        setLatest(null)
                        setMessage("Saved manual calculation restored.")
                      })
                    }
                  >
                    Restore saved calculation
                  </Button>
                </>
              ) : (
                <>
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() =>
                      perform(() => {
                        setBenchmark(null)
                        setHistory([])
                        setLatest(null)
                        setMessage(
                          "You can now change the inputs. The saved calculation stays on this device until you save again."
                        )
                      })
                    }
                  >
                    Start a new calculation
                  </Button>
                  <Button
                    type="button"
                    onClick={() =>
                      perform(() => {
                        localStorage.setItem(
                          storageKey,
                          saveManualCalculation(benchmark, history)
                        )
                        setMessage(
                          "Saved on this device. This is not stored in your FantasyHUD portfolio."
                        )
                      })
                    }
                  >
                    Save on this device
                  </Button>
                </>
              )}
            </div>
          </form>
        </CardContent>
        <CardFooter className="text-xs text-muted-foreground">
          One calculation can be saved in this browser. It is not synced between
          devices. A priced rank measures market cost; it is not a forecast of a
          player’s finishing rank.
        </CardFooter>
      </Card>
      {error ? (
        <p
          role="alert"
          className="rounded-lg border border-destructive/50 p-4 text-sm text-destructive"
        >
          {error}
        </p>
      ) : null}
      {message ? (
        <p role="status" className="text-sm text-muted-foreground">
          {message}
        </p>
      ) : null}
      {benchmark ? (
        <>
          <div
            aria-label="Frozen price benchmark"
            className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4 *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:shadow-xs dark:*:data-[slot=card]:bg-card"
          >
            <Card>
              <CardHeader>
                <CardDescription>Price paid</CardDescription>
                <CardTitle className="text-2xl tabular-nums">
                  {benchmark.priceLabel}
                </CardTitle>
              </CardHeader>
              <CardFooter className="text-sm text-muted-foreground">
                {benchmark.input.position} · {benchmark.input.contextLabel}
              </CardFooter>
            </Card>
            <Card>
              <CardHeader>
                <CardDescription>Price implies</CardDescription>
                <CardTitle className="text-2xl tabular-nums">
                  {benchmark.input.position}
                  {formatRank(benchmark.pricedRank)}
                </CardTitle>
                <CardAction>
                  <Badge variant="outline">Fixed</Badge>
                </CardAction>
              </CardHeader>
              <CardFooter className="text-sm text-muted-foreground">
                {benchmark.interpolation === "interpolated"
                  ? "Interpolated between observed prices"
                  : benchmark.interpolation === "tied"
                    ? "Midpoint of tied market prices"
                    : "Matched to an observed market price"}
              </CardFooter>
            </Card>
            <Card>
              <CardHeader>
                <CardDescription>Player’s market rank</CardDescription>
                <CardTitle className="text-2xl tabular-nums">
                  {benchmark.playerMarketRank === null
                    ? "Not entered"
                    : `${benchmark.input.position}${formatRank(benchmark.playerMarketRank)}`}
                </CardTitle>
              </CardHeader>
              <CardFooter className="text-sm text-muted-foreground">
                Shown separately from the price you paid
              </CardFooter>
            </Card>
            <Card>
              <CardHeader>
                <CardDescription>
                  {latest
                    ? `Rank surplus · Week ${latest.week}`
                    : "Rank surplus"}
                </CardDescription>
                <CardTitle className="text-2xl tabular-nums">
                  {latest ? formatSurplus(latest.surplus) : "Not compared"}
                </CardTitle>
              </CardHeader>
              <CardFooter className="text-sm text-muted-foreground">
                {latest
                  ? `${latest.rankingType === "season_total_points_rank" ? "Total points" : `PPG · ${latest.minimumGames}+ games`} · actual ${benchmark.input.position}${latest.actualRank}`
                  : "Positive means performance ranks better than the price paid"}
              </CardFooter>
            </Card>
          </div>
          <Card>
            <CardHeader>
              <CardTitle>Compare season performance</CardTitle>
              <CardDescription>
                Enter the season-to-date positional rank under the same scoring
                rules and position group. Include all eligible players, not just
                your roster. Custom scoring is not calculated on this screen.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={compare} className="space-y-4">
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                  <TextField
                    id="outcome-week"
                    label="Through week"
                    value={outcome.week}
                    onChange={(week) =>
                      setOutcome((value) => ({ ...value, week }))
                    }
                    inputMode="numeric"
                  />
                  <div className="space-y-2">
                    <Label htmlFor="outcome-kind">Rank measure</Label>
                    <select
                      id="outcome-kind"
                      className={selectClass}
                      value={outcome.rankingType}
                      onChange={(event) =>
                        setOutcome((value) => ({
                          ...value,
                          rankingType: event.target
                            .value as ManualOutcomeInput["rankingType"],
                        }))
                      }
                    >
                      <option value="season_total_points_rank">
                        Season total points
                      </option>
                      <option value="season_points_per_game_rank">
                        Season points per game
                      </option>
                    </select>
                  </div>
                  <TextField
                    id="outcome-rank"
                    label="Actual positional rank"
                    value={outcome.actualRank}
                    onChange={(actualRank) =>
                      setOutcome((value) => ({ ...value, actualRank }))
                    }
                    inputMode="numeric"
                  />
                  {outcome.rankingType === "season_points_per_game_rank" ? (
                    <>
                      <TextField
                        id="outcome-minimum"
                        label="Minimum games for PPG rank"
                        value={outcome.minimumGames}
                        onChange={(minimumGames) =>
                          setOutcome((value) => ({ ...value, minimumGames }))
                        }
                        inputMode="numeric"
                      />
                      <TextField
                        id="outcome-games"
                        label="Player’s games played"
                        value={outcome.gamesPlayed}
                        onChange={(gamesPlayed) =>
                          setOutcome((value) => ({ ...value, gamesPlayed }))
                        }
                        inputMode="numeric"
                      />
                    </>
                  ) : null}
                </div>
                <Button type="submit">Add or update week</Button>
                <p className="text-xs text-muted-foreground">
                  Updating the same week and rank measure replaces its manual
                  entry. The priced rank stays fixed.
                </p>
              </form>
            </CardContent>
          </Card>
          <DataTable
            ariaLabel="Manual weekly rank comparisons"
            columns={columns}
            data={history}
            getRowId={comparisonKey}
            countNoun="comparisons"
            searchText=""
            title="Weekly comparisons"
            description={`Fixed benchmark: ${benchmark.input.position}${formatRank(benchmark.pricedRank)}. Surplus = priced rank − actual rank. Raw rank differences are not additive across positions.`}
            emptyMessage="No weekly ranks entered for this calculation."
          />
        </>
      ) : null}
    </div>
  )
}
