import { describe, expect, it } from "vitest"

import { validateServerSupabaseEnvironment } from "./server-env"

describe("validateServerSupabaseEnvironment", () => {
  it("accepts and trims a hosted Supabase secret key", () => {
    expect(
      validateServerSupabaseEnvironment({
        SUPABASE_SECRET_KEY: "  sb_secret_example  ",
      })
    ).toEqual({ secretKey: "sb_secret_example" })
  })

  it("accepts a local service-role equivalent without enforcing a format", () => {
    expect(
      validateServerSupabaseEnvironment({
        SUPABASE_SECRET_KEY: "local-service-role-value",
      })
    ).toEqual({ secretKey: "local-service-role-value" })
  })

  it("rejects a missing key", () => {
    expect(() => validateServerSupabaseEnvironment({})).toThrow(
      "SUPABASE_SECRET_KEY must be provided."
    )
  })

  it("rejects a blank key", () => {
    expect(() =>
      validateServerSupabaseEnvironment({ SUPABASE_SECRET_KEY: "   " })
    ).toThrow("SUPABASE_SECRET_KEY must be provided.")
  })

  it("never includes the supplied key in an error", () => {
    const sensitiveValue = "do-not-echo-this-secret"

    expect(() =>
      validateServerSupabaseEnvironment({
        SUPABASE_SECRET_KEY: `${sensitiveValue}\nsecond-line`,
      })
    ).toThrowError(
      expect.objectContaining({
        message: expect.not.stringContaining(sensitiveValue),
      })
    )
  })
})
