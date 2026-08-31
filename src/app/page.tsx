import { CircleCheck } from "lucide-react"
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
  const { data: links } = await supabase
    .from("user_fantasy_accounts")
    .select("id")
    .limit(1)

  if (!links?.length) {
    redirect("/onboarding")
  }

  return (
    <AuthShell
      title="Fantasy account connected"
      description="Your tracked account is available to FANTASY HUD."
    >
      <div className="grid gap-5">
        <div className="flex items-start gap-3 rounded-lg border bg-muted/30 p-4 text-sm text-muted-foreground">
          <CircleCheck
            aria-hidden="true"
            className="mt-0.5 size-4 shrink-0 text-emerald-400"
          />
          <p>Portfolio import is not available yet.</p>
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
