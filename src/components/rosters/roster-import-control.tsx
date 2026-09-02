"use client"

import { LoaderCircle, RefreshCw } from "lucide-react"
import { useActionState } from "react"

import { importCurrentSleeperRostersAction } from "@/app/rosters/actions"
import { Button } from "@/components/ui/button"
import { initialRosterImportActionState } from "@/lib/sleeper/roster-types"

export function RosterImportControl({
  hasImported,
  isRunning = false,
}: {
  hasImported: boolean
  isRunning?: boolean
}) {
  const [state, action, isPending] = useActionState(
    importCurrentSleeperRostersAction,
    initialRosterImportActionState
  )
  const imported =
    hasImported || state.status === "success" || state.status === "partial"
  const busy = isPending || isRunning || state.status === "running"

  return (
    <div className="flex flex-col items-start gap-2 sm:items-end">
      <form action={action}>
        <Button type="submit" disabled={busy}>
          {busy ? (
            <LoaderCircle aria-hidden="true" className="animate-spin" />
          ) : imported ? (
            <RefreshCw aria-hidden="true" />
          ) : null}
          {busy
            ? "Importing rosters…"
            : imported
              ? "Refresh current-season rosters"
              : "Import current-season rosters"}
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
