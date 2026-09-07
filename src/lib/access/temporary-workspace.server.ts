import "server-only"

import { createClient } from "@supabase/supabase-js"
import { cache } from "react"

import type { Database } from "@/lib/supabase/database.types"
import { getPublicSupabaseEnvironment } from "@/lib/supabase/env"

// This client deliberately has no user cookies, session, or server secret.
export const getTemporaryWorkspace = cache(async () => {
  if (process.env.FANTASYHUD_TEMPORARY_ACCESS === "off") return null

  const { url, publishableKey } = getPublicSupabaseEnvironment()
  const supabase = createClient<Database>(url, publishableKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  })
  const { data, error } = await supabase.rpc("get_temporary_workspace")
  // A previous schema may still be serving during an integration deployment.
  if (error?.code === "PGRST202") return null
  if (error) throw new Error("Unable to load workspace access settings.")
  const account = data?.[0]
  return account ? { account, supabase } : null
})
