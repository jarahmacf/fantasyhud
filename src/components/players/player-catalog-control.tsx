"use client"

import { LoaderCircle, RefreshCw } from "lucide-react"
import { useActionState } from "react"

import { refreshSleeperPlayerCatalogAction } from "@/app/players/actions"
import { Button } from "@/components/ui/button"
import type { PlayerCatalogActionState } from "@/lib/sleeper/player-types"

const initialState: PlayerCatalogActionState = { status: "idle", message: null }

export function PlayerCatalogControl({
  hasSucceeded,
}: {
  hasSucceeded: boolean
}) {
  const [state, action, isPending] = useActionState(
    refreshSleeperPlayerCatalogAction,
    initialState
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
            ? "Refreshing player catalog…"
            : imported
              ? "Check catalog freshness"
              : "Import player catalog"}
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
