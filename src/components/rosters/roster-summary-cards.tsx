import {
  CalendarClock,
  CircleCheck,
  CircleHelp,
  LibraryBig,
  ListChecks,
  Trophy,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import type { RosterDashboard } from "@/lib/rosters/dashboard.server"

const statusLabels: Record<RosterDashboard["latestStatus"], string> = {
  not_started: "Not started",
  running: "Running",
  succeeded: "Succeeded",
  failed: "Failed",
  partial: "Partial",
}

function refreshedLabel(value: string | null): string {
  if (!value) return "Never"
  const timestamp = new Date(value)
  if (Number.isNaN(timestamp.getTime())) return "Unavailable"
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(timestamp)
}

export function RosterSummaryCards({
  dashboard,
}: {
  dashboard: RosterDashboard
}) {
  const summaries = [
    {
      label: "Roster sync",
      value: statusLabels[dashboard.latestStatus],
      detail: "Latest current-season attempt",
      Icon: CircleCheck,
    },
    {
      label: "Current-season leagues",
      value: dashboard.currentSeasonLeagueCount.toLocaleString("en-US"),
      detail:
        dashboard.currentLeagueSeason === null
          ? "Season not resolved"
          : `Sleeper NFL ${dashboard.currentLeagueSeason}`,
      Icon: Trophy,
    },
    {
      label: "Owned rosters",
      value: dashboard.ownedRosterCount.toLocaleString("en-US"),
      detail: "Explicit active account ownership",
      Icon: LibraryBig,
    },
    {
      label: "Last confirmed active memberships",
      value: dashboard.currentHoldingCount.toLocaleString("en-US"),
      detail: "Across confirmed-owned rosters",
      Icon: ListChecks,
    },
    {
      label: "Unresolved leagues",
      value: dashboard.unresolvedLeagueCount.toLocaleString("en-US"),
      detail: "No ownership has been inferred",
      Icon: CircleHelp,
    },
    {
      label: "Last refreshed",
      value: refreshedLabel(dashboard.lastRefreshedAt),
      detail: "Last succeeded or partial import",
      Icon: CalendarClock,
    },
  ] as const

  return (
    <section
      aria-label="Roster import summary"
      className="grid gap-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:shadow-xs sm:grid-cols-2 xl:grid-cols-3 dark:*:data-[slot=card]:bg-card"
    >
      {summaries.map(({ label, value, detail, Icon }) => (
        <Card key={label} className="@container/card">
          <CardHeader className="grid-cols-1">
            <div className="flex min-w-0 items-start justify-between gap-2">
              <CardDescription>{label}</CardDescription>
              <Badge variant="outline" className="shrink-0">
                <Icon aria-hidden="true" />
                Current
              </Badge>
            </div>
            <CardTitle className="truncate text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
              {value}
            </CardTitle>
          </CardHeader>
          <CardFooter className="text-sm text-muted-foreground">
            {detail}
          </CardFooter>
        </Card>
      ))}
    </section>
  )
}
