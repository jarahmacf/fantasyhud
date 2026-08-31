import { createServerClient } from "@supabase/ssr"
import { type NextRequest, NextResponse } from "next/server"

import type { Database } from "./database.types"
import { getPublicSupabaseEnvironment } from "./env"

export async function refreshSupabaseSession(request: NextRequest) {
  const { url, publishableKey } = getPublicSupabaseEnvironment()
  let response = NextResponse.next({ request })

  const supabase = createServerClient<Database>(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet, headersToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        )
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options)
        )
        Object.entries(headersToSet).forEach(([name, value]) =>
          response.headers.set(name, value)
        )
      },
    },
  })

  await supabase.auth.getClaims()
  return response
}
