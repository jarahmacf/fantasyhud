import { createServerClient } from "@supabase/ssr"
import { cookies } from "next/headers"

import type { Database } from "./database.types"
import { getPublicSupabaseEnvironment } from "./env"

export async function createServerSupabaseClient() {
  const { url, publishableKey } = getPublicSupabaseEnvironment()
  const cookieStore = await cookies()

  return createServerClient<Database>(url, publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options)
          })
        } catch {
          // Server Components may read cookies but cannot write response cookies.
        }
      },
    },
  })
}
