import "server-only"

import type { AppShellIdentity } from "@/components/app/app-shell"
import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"

import { getTemporaryWorkspace } from "./temporary-workspace.server"

export async function getWorkspaceAccess() {
  const temporary = await getTemporaryWorkspace()
  if (temporary) {
    return {
      ...temporary,
      readOnly: true,
      identity: {
        email: null,
        accountLabel: `@${temporary.account.username}`,
        accessMode: "temporary",
      } satisfies AppShellIdentity,
    }
  }

  const user = await getCurrentAuthIdentity()
  if (!user) return null
  const supabase = await createServerSupabaseClient()
  const result = await supabase
    .from("user_fantasy_accounts")
    .select("fantasy_accounts!inner(id, provider, username, display_name)")
    .eq("user_id", user.id)
    .eq("is_primary", true)
    .maybeSingle()
  if (result.error)
    throw new Error("Unable to load the connected fantasy account.")
  const account = result.data?.fantasy_accounts ?? null
  if (account && account.provider !== "sleeper") {
    throw new Error("The primary fantasy account is not a Sleeper account.")
  }
  return {
    supabase,
    account,
    readOnly: false,
    identity: {
      email: user.email,
      accountLabel: account ? `@${account.username}` : "Sleeper not connected",
    } satisfies AppShellIdentity,
  }
}
