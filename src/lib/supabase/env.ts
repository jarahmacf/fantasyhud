export interface PublicSupabaseEnvironment {
  url: string
  publishableKey: string
}

export interface PublicSupabaseEnvironmentRecord {
  NEXT_PUBLIC_SUPABASE_URL?: string
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string
}

export function validatePublicSupabaseEnvironment(
  environment: PublicSupabaseEnvironmentRecord
): PublicSupabaseEnvironment {
  const url = environment.NEXT_PUBLIC_SUPABASE_URL?.trim()
  const publishableKey =
    environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim()

  if (!url) {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL must be provided.")
  }

  let parsedUrl: URL
  try {
    parsedUrl = new URL(url)
  } catch {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL must be a valid URL.")
  }

  if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_URL must use the http: or https: protocol."
    )
  }

  if (!publishableKey) {
    throw new Error("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be provided.")
  }

  return { url, publishableKey }
}

export function getPublicSupabaseEnvironment(): PublicSupabaseEnvironment {
  return validatePublicSupabaseEnvironment({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  })
}
