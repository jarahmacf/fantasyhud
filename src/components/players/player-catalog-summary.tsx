import {
  Activity,
  BadgeCheck,
  Clock3,
  Database,
  Link2,
  Shield,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import type { PlayerCatalogDashboard } from "@/lib/players/dashboard.server"

const statusLabels = {
  not_imported: "Not imported",
  running: "Refresh running",
  succeeded: "Succeeded",
  failed: "Refresh failed",
  partial: "Partial",
} as const

function formatTimestamp(value: string | null): string {
  if (!value) return "Never"
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(new Date(value))
}

export function PlayerCatalogSummary({
  dashboard,
}: {
  dashboard: PlayerCatalogDashboard
}) {
  const summaries = [
    {
      label: "Catalog status",
      value: statusLabels[dashboard.latestStatus],
      badge: "Sleeper NFL",
      detail: "Latest sanitized catalog attempt",
      Icon: BadgeCheck,
    },
    {
      label: "Last refreshed",
      value: formatTimestamp(dashboard.lastRefreshedAt),
      badge: "Source fetch",
      detail: "Successful global catalog observation",
      Icon: Clock3,
    },
    {
      label: "Canonical entities",
      value: dashboard.canonicalEntities.toLocaleString("en-US"),
      badge: "Shared",
      detail: "Players, defenses, and sparse entities",
      Icon: Database,
    },
    {
      label: "Active players",
      value: dashboard.activePlayers.toLocaleString("en-US"),
      badge: "Current profile",
      detail: "Provider-reported active entities",
      Icon: Activity,
    },
    {
      label: "Team defenses",
      value: dashboard.teamDefenses.toLocaleString("en-US"),
      badge: "Canonical",
      detail: "DEF entities remain distinct",
      Icon: Shield,
    },
    {
      label: "External ID mappings",
      value: dashboard.externalIdMappings.toLocaleString("en-US"),
      badge: "Active",
      detail: "Primary and conservative secondary IDs",
      Icon: Link2,
    },
  ] as const

  return (
    <section
      aria-label="Player catalog summary"
      className="grid gap-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:shadow-xs sm:grid-cols-2 xl:grid-cols-3 dark:*:data-[slot=card]:bg-card"
    >
      {summaries.map(({ label, value, badge, detail, Icon }) => (
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
