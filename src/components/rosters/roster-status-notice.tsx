import { AlertTriangle, CircleHelp } from "lucide-react"
import Link from "next/link"

import { Button } from "@/components/ui/button"
import type {
  RosterPrerequisite,
  RosterRunStatus,
} from "@/lib/rosters/dashboard.server"
import { cn } from "@/lib/utils"

type Notice = {
  title: string
  description: string
  href?: string
  action?: string
  warning?: boolean
}

function noticeFor(
  prerequisite: RosterPrerequisite | "account",
  status: RosterRunStatus,
  unresolvedLeagueCount: number
): Notice | null {
  if (prerequisite === "account") {
    return {
      title: "Connect a Sleeper account",
      description:
        "A connected canonical Sleeper account is required before roster import.",
      href: "/onboarding",
      action: "Connect Sleeper",
    }
  }
  if (prerequisite === "league_discovery") {
    return {
      title: "League discovery not complete",
      description: "Import current-season leagues first.",
      href: "/",
      action: "Open Leagues",
    }
  }
  if (prerequisite === "player_catalog") {
    return {
      title: "Player catalog not imported",
      description: "Import the player catalog first.",
      href: "/players",
      action: "Open Players",
    }
  }
  if (status === "not_started") {
    return {
      title: "Roster import not started",
      description:
        "Import current-season rosters to resolve explicit ownership and current holdings.",
    }
  }
  if (status === "running") {
    return {
      title: "Roster import running",
      description:
        "The current roster import is still in progress. Starting another import will reuse this run.",
    }
  }
  if (status === "failed") {
    return {
      title: "Latest roster import failed",
      description:
        "Previously published roster data is unchanged. Try the import again when ready.",
      warning: true,
    }
  }
  if (status === "partial") {
    return {
      title: "Roster source import completed with unresolved ownership",
      description: `${unresolvedLeagueCount.toLocaleString("en-US")} ${unresolvedLeagueCount === 1 ? "league has" : "leagues have"} unresolved ownership. No roster ownership was invented.`,
      warning: true,
    }
  }
  return null
}

export function RosterStatusNotice({
  prerequisite,
  status,
  unresolvedLeagueCount,
}: {
  prerequisite: RosterPrerequisite | "account"
  status: RosterRunStatus
  unresolvedLeagueCount: number
}) {
  const notice = noticeFor(prerequisite, status, unresolvedLeagueCount)
  if (!notice) return null

  const Icon = notice.warning ? AlertTriangle : CircleHelp
  return (
    <section
      role={notice.warning ? "alert" : "status"}
      className={cn(
        "flex flex-col gap-4 rounded-lg border bg-card p-5 shadow-xs sm:flex-row sm:items-center sm:justify-between",
        notice.warning && "border-amber-500/30 bg-amber-500/5"
      )}
    >
      <div className="flex items-start gap-3">
        <Icon
          aria-hidden="true"
          className={cn(
            "mt-0.5 size-5 shrink-0 text-muted-foreground",
            notice.warning && "text-amber-700 dark:text-amber-400"
          )}
        />
        <div className="grid gap-1">
          <h2 className="font-semibold">{notice.title}</h2>
          <p className="text-sm text-muted-foreground">{notice.description}</p>
        </div>
      </div>
      {notice.href && notice.action ? (
        <Button asChild variant="outline" className="w-fit shrink-0">
          <Link href={notice.href}>{notice.action}</Link>
        </Button>
      ) : null}
    </section>
  )
}
