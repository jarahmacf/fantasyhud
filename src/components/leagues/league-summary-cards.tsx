import { CalendarDays, CircleCheck, Radio, UserRound } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

export type LatestDiscoveryStatus =
  "not_started" | "running" | "succeeded" | "failed" | "partial"

const statusLabels: Record<LatestDiscoveryStatus, string> = {
  not_started: "Not started",
  running: "Running",
  succeeded: "Succeeded",
  failed: "Failed",
  partial: "Partial",
}

export function LeagueSummaryCards({
  username,
  displayName,
  leagueSeason,
  activeLeagueCount,
  latestStatus,
  latestSeason,
}: {
  username: string
  displayName: string | null
  leagueSeason: number | null
  activeLeagueCount: number
  latestStatus: LatestDiscoveryStatus
  latestSeason: number | null
}) {
  const summaries = [
    {
      label: "Sleeper account",
      value: `@${username}`,
      badge: "Primary",
      Icon: UserRound,
      detail: displayName ?? "Canonical connected identity",
    },
    {
      label: "NFL league season",
      value: leagueSeason?.toString() ?? "Not fetched",
      badge: "Provider state",
      Icon: CalendarDays,
      detail: "Resolved from Sleeper state",
    },
    {
      label: "Active leagues",
      value: activeLeagueCount.toString(),
      badge: "Current collection",
      Icon: Radio,
      detail: "Removed associations are excluded",
    },
    {
      label: "Latest attempt (all seasons)",
      value: statusLabels[latestStatus],
      badge: "League discovery",
      Icon: CircleCheck,
      detail:
        latestSeason === null
          ? "Season not recorded"
          : `Run season ${latestSeason}`,
    },
  ] as const

  return (
    <section
      aria-label="League discovery summary"
      className="grid gap-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:shadow-xs sm:grid-cols-2 xl:grid-cols-4 dark:*:data-[slot=card]:bg-card"
    >
      {summaries.map(({ label, value, badge, Icon, detail }) => (
        <Card key={label} className="@container/card">
          <CardHeader className="grid-cols-1">
            <div className="flex min-w-0 items-start justify-between gap-2">
              <CardDescription>{label}</CardDescription>
              <Badge variant="outline" className="shrink-0">
                <Icon aria-hidden="true" />
                {badge}
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
