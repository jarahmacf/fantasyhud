import { redirect } from "next/navigation"
import { connection } from "next/server"

import { signOutAction } from "@/app/auth/actions"
import { AuthShell } from "@/components/auth/auth-shell"
import { ConnectSleeperForm } from "@/components/onboarding/connect-sleeper-form"
import { Button } from "@/components/ui/button"
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export default async function OnboardingPage() {
  await connection()
  const identity = await requireAuthIdentity("/onboarding")
  const supabase = await createServerSupabaseClient()
  const linksResult = await supabase
    .from("user_fantasy_accounts")
    .select("id")
    .limit(1)

  if (linksResult.error) {
    throw new Error("Unable to load account connection.")
  }

  const links = linksResult.data
  if (links?.length) {
    redirect("/")
  }

  const profileResult = await supabase
    .from("profiles")
    .select("display_name")
    .eq("id", identity.id)
    .maybeSingle()

  if (profileResult.error) {
    throw new Error("Unable to load account profile.")
  }

  const profile = profileResult.data

  return (
    <AuthShell
      title="Connect a Sleeper account"
      description="Choose the public Sleeper identity you want FANTASY HUD to track."
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
        <ConnectSleeperForm />
        <form action={signOutAction}>
          <Button type="submit" variant="outline" className="w-full">
            Sign out
          </Button>
        </form>
      </div>
    </AuthShell>
  )
}
