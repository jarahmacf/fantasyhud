export interface ServerSupabaseEnvironment {
  secretKey: string
}

export interface ServerSupabaseEnvironmentRecord {
  SUPABASE_SECRET_KEY?: string
}

export function validateServerSupabaseEnvironment(
  environment: ServerSupabaseEnvironmentRecord
): ServerSupabaseEnvironment {
  const secretKey = environment.SUPABASE_SECRET_KEY?.trim()

  if (!secretKey) {
    throw new Error("SUPABASE_SECRET_KEY must be provided.")
  }
  if (/[\u0000-\u001f\u007f]/u.test(secretKey)) {
    throw new Error("SUPABASE_SECRET_KEY must be a single valid value.")
  }

  return { secretKey }
}

export function getServerSupabaseEnvironment(): ServerSupabaseEnvironment {
  return validateServerSupabaseEnvironment({
    SUPABASE_SECRET_KEY: process.env.SUPABASE_SECRET_KEY,
  })
}
