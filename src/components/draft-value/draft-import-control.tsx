"use client"
import { useActionState } from "react"
import { LoaderCircle } from "lucide-react"
import { importCurrentSleeperDraftsAction } from "@/app/draft-value/actions"
import { Button } from "@/components/ui/button"
import type { DraftImportActionState } from "@/lib/drafts/types"
const initialState: DraftImportActionState = { status: "idle", message: null }
export function DraftImportControl({ hasImported }: { hasImported: boolean }) {
  const [state, action, pending] = useActionState(
    importCurrentSleeperDraftsAction,
    initialState
  )
  const busy = pending
  return (
    <div className="flex flex-col items-start gap-2">
      <form action={action}>
        <Button type="submit" disabled={busy}>
          {busy ? (
            <LoaderCircle aria-hidden="true" className="animate-spin" />
          ) : null}
          {busy
            ? "Importing drafts…"
            : hasImported
              ? "Refresh current-season drafts"
              : "Import current-season drafts"}
        </Button>
      </form>
      {state.message ? (
        <p
          role={state.status === "error" ? "alert" : "status"}
          aria-live="polite"
          className={
            state.status === "error"
              ? "text-sm text-destructive"
              : "text-sm text-muted-foreground"
          }
        >
          {state.message}
        </p>
      ) : null}
    </div>
  )
}
