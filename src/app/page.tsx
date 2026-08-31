import { CircleCheck, Link2 } from "lucide-react"
import { redirect } from "next/navigation"
import { connection } from "next/server"

import { signOutAction } from "@/app/auth/actions"
import { AuthShell } from "@/components/auth/auth-shell"
import { Button } from "@/components/ui/button"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export default async function Home() {
  await connection()
  const identity = await getCurrentAuthIdentity()
  if (!identity) {
    redirect("/auth/sign-in")
  }

  const supabase = await createServerSupabaseClient()
  const { data: link, error } = await supabase
    .from("user_fantasy_accounts")
    .select(
      "is_primary, fantasy_accounts!inner(provider, username, display_name)"
    )
    .limit(1)
    .maybeSingle()

  if (error) {
    throw new Error("Unable to load the connected fantasy account.")
  }

  if (!link) {
    redirect("/onboarding")
  }

  const account = link.fantasy_accounts

  return (
    <AuthShell
      title="Fantasy account connected"
      description="This public Sleeper identity is connected to your FANTASY HUD account."
    >
      <div className="grid gap-5">
        <div className="flex items-start gap-3 rounded-lg border bg-muted/30 p-4">
          <Link2
            aria-hidden="true"
            className="mt-0.5 size-4 shrink-0 text-muted-foreground"
          />
          <dl className="grid min-w-0 flex-1 gap-3 text-sm">
            <div className="grid gap-1">
              <dt className="text-xs text-muted-foreground">
                Sleeper identity
              </dt>
              <dd className="font-medium">
                {account.display_name ?? account.username}
              </dd>
              <dd className="break-all font-mono text-xs text-muted-foreground">
                @{account.username}
              </dd>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1">
                <dt className="text-xs text-muted-foreground">Provider</dt>
                <dd>Sleeper</dd>
              </div>
              <div className="grid gap-1">
                <dt className="text-xs text-muted-foreground">Connection</dt>
                <dd>{link.is_primary ? "Primary" : "Connected"}</dd>
              </div>
            </div>
          </dl>
        </div>
        <div className="flex items-start gap-3 rounded-lg border bg-muted/30 p-4 text-sm text-muted-foreground">
          <CircleCheck
            aria-hidden="true"
            className="mt-0.5 size-4 shrink-0 text-emerald-400"
          />
          <div className="grid gap-1">
            <p className="font-medium text-foreground">Portfolio import</p>
            <p>Not started</p>
          </div>
        </div>
        <form action={signOutAction}>
          <Button type="submit" variant="outline" className="w-full">
            Sign out
          </Button>
        </form>
      </div>
    </AuthShell>
  )
}
