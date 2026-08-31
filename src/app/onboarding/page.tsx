import { Link2Off } from "lucide-react"
import { redirect } from "next/navigation"
import { connection } from "next/server"

import { signOutAction } from "@/app/auth/actions"
import { AuthShell } from "@/components/auth/auth-shell"
import { Button } from "@/components/ui/button"
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export default async function OnboardingPage() {
  await connection()
  const identity = await requireAuthIdentity("/onboarding")
  const supabase = await createServerSupabaseClient()
  const [{ data: links }, { data: profile }] = await Promise.all([
    supabase.from("user_fantasy_accounts").select("id").limit(1),
    supabase
      .from("profiles")
      .select("display_name")
      .eq("id", identity.id)
      .maybeSingle(),
  ])

  if (links?.length) {
    redirect("/")
  }

  return (
    <AuthShell
      title="No Sleeper account connected"
      description="Your FANTASY HUD account is ready."
    >
      <div className="grid gap-5">
        <dl className="grid gap-3 rounded-lg border bg-muted/30 p-4 text-sm">
          {profile?.display_name ? (
            <div className="grid gap-1">
              <dt className="text-xs text-muted-foreground">Display name</dt>
              <dd>{profile.display_name}</dd>
            </div>
          ) : null}
          <div className="grid gap-1">
            <dt className="text-xs text-muted-foreground">Signed-in email</dt>
            <dd className="break-all font-mono text-xs">
              {identity.email ?? "Email unavailable"}
            </dd>
          </div>
        </dl>
        <div className="flex items-start gap-3 rounded-lg border p-4 text-sm text-muted-foreground">
          <Link2Off aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
          <p>Sleeper account connection is not enabled in this build.</p>
        </div>
        <Button type="button" disabled className="w-full">
          Connect Sleeper account
        </Button>
        <form action={signOutAction}>
          <Button type="submit" variant="outline" className="w-full">
            Sign out
          </Button>
        </form>
      </div>
    </AuthShell>
  )
}
