import { redirect } from "next/navigation"

import { getTemporaryWorkspace } from "@/lib/access/temporary-workspace.server"
import { createServerSupabaseClient } from "@/lib/supabase/server"

import { getSafeInternalNextPath } from "./redirects"
import type { AuthIdentity } from "./types"

export async function getCurrentAuthIdentity(): Promise<AuthIdentity | null> {
  const supabase = await createServerSupabaseClient()
  const { data, error } = await supabase.auth.getClaims()

  if (error || !data?.claims.sub) {
    return null
  }

  return {
    id: data.claims.sub,
    email: typeof data.claims.email === "string" ? data.claims.email : null,
  }
}

export async function requireAuthIdentity(
  nextPath = "/onboarding"
): Promise<AuthIdentity> {
  if (await getTemporaryWorkspace()) {
    throw new Error("Changes are disabled during temporary read-only access.")
  }
  const identity = await getCurrentAuthIdentity()
  if (!identity) {
    const safeNext = getSafeInternalNextPath(nextPath)
    redirect(`/auth/sign-in?next=${encodeURIComponent(safeNext)}`)
  }

  return identity
}
