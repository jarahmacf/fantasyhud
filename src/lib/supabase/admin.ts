import "server-only"

import { createClient } from "@supabase/supabase-js"

import type { Database } from "./database.types"
import { getPublicSupabaseEnvironment } from "./env"
import { getServerSupabaseEnvironment } from "./server-env"

export function createAdminSupabaseClient() {
  const { url } = getPublicSupabaseEnvironment()
  const { secretKey } = getServerSupabaseEnvironment()

  return createClient<Database>(url, secretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  })
}
