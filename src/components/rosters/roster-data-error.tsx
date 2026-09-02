import { AlertTriangle } from "lucide-react"
import Link from "next/link"

import { Button } from "@/components/ui/button"

export function RosterDataError() {
  return (
    <section
      role="alert"
      className="mx-4 grid max-w-xl gap-4 rounded-lg border bg-card p-6 shadow-sm lg:mx-6"
    >
      <div className="flex items-start gap-3">
        <AlertTriangle
          aria-hidden="true"
          className="mt-0.5 size-5 shrink-0 text-destructive"
        />
        <div className="grid gap-1">
          <h1 className="font-semibold">Roster data could not load</h1>
          <p className="text-sm text-muted-foreground">
            The database did not return a complete roster view. No empty-roster
            result has been assumed.
          </p>
        </div>
      </div>
      <Button asChild className="w-fit">
        <Link href="/rosters">Try again</Link>
      </Button>
    </section>
  )
}
