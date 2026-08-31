"use client"

import { createBrowserClient } from "@supabase/ssr"

import type { Database } from "./database.types"
import { getPublicSupabaseEnvironment } from "./env"

export function createBrowserSupabaseClient() {
  const { url, publishableKey } = getPublicSupabaseEnvironment()

  return createBrowserClient<Database>(url, publishableKey)
}
