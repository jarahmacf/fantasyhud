"use client"

import { useActionState } from "react"
import { LoaderCircle, RefreshCw } from "lucide-react"

import { importCurrentSleeperLeaguesAction } from "@/app/leagues/actions"
import { Button } from "@/components/ui/button"
import { initialLeagueDiscoveryActionState } from "@/lib/sleeper/types"

export function LeagueDiscoveryControl({
  hasSucceeded,
}: {
  hasSucceeded: boolean
}) {
  const [state, action, isPending] = useActionState(
    importCurrentSleeperLeaguesAction,
    initialLeagueDiscoveryActionState
  )
  const imported = hasSucceeded || state.status === "success"

  return (
    <div className="flex flex-col items-start gap-2 sm:items-end">
      <form action={action}>
        <Button type="submit" disabled={isPending}>
          {isPending ? (
            <LoaderCircle aria-hidden="true" className="animate-spin" />
          ) : imported ? (
            <RefreshCw aria-hidden="true" />
          ) : null}
          {isPending
            ? "Importing leagues…"
            : imported
              ? "Refresh current-season leagues"
              : "Import current-season leagues"}
        </Button>
      </form>
      {state.message ? (
        <p
          role={state.status === "error" ? "alert" : "status"}
          aria-live="polite"
          className={
            state.status === "error"
              ? "max-w-sm text-sm text-destructive"
              : "max-w-sm text-sm text-muted-foreground"
          }
        >
          {state.message}
        </p>
      ) : null}
    </div>
  )
}
