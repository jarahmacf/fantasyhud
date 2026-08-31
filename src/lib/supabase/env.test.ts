import { describe, expect, it } from "vitest"

import { validatePublicSupabaseEnvironment } from "./env"

const validKey = "publishable-test-value"

describe("validatePublicSupabaseEnvironment", () => {
  it("accepts a local HTTP URL", () => {
    expect(
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toEqual({
      url: "http://127.0.0.1:54321",
      publishableKey: validKey,
    })
  })

  it("accepts an HTTPS URL", () => {
    expect(
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toEqual({
      url: "https://example.supabase.co",
      publishableKey: validKey,
    })
  })

  it("rejects a missing URL", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toThrow("NEXT_PUBLIC_SUPABASE_URL must be provided.")
  })

  it("rejects a blank URL", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "  ",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toThrow("NEXT_PUBLIC_SUPABASE_URL must be provided.")
  })

  it("rejects an invalid URL", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "not a URL",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toThrow("NEXT_PUBLIC_SUPABASE_URL must be a valid URL.")
  })

  it("rejects an unsupported URL protocol", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "ftp://example.com",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: validKey,
      })
    ).toThrow("must use the http: or https: protocol")
  })

  it("rejects a missing publishable key", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
      })
    ).toThrow("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be provided.")
  })

  it("rejects a blank publishable key", () => {
    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "  ",
      })
    ).toThrow("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be provided.")
  })

  it("trims public values", () => {
    expect(
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "  https://example.supabase.co  ",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: `  ${validKey}  `,
      })
    ).toEqual({
      url: "https://example.supabase.co",
      publishableKey: validKey,
    })
  })

  it("never includes a key value in validation errors", () => {
    const sensitiveValue = "do-not-echo-this-value"

    expect(() =>
      validatePublicSupabaseEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: sensitiveValue,
      })
    ).toThrowError(
      expect.objectContaining({
        message: expect.not.stringContaining(sensitiveValue),
      })
    )
  })
})
