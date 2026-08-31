import { afterEach, describe, expect, it, vi } from "vitest"

import { buildAuthRedirectUrl, resolveSiteUrl } from "./site-url"

afterEach(() => {
  vi.unstubAllEnvs()
})

describe("resolveSiteUrl", () => {
  it("prefers and normalizes the configured site URL", () => {
    expect(
      resolveSiteUrl({
        NEXT_PUBLIC_SITE_URL: " https://fantasyhud.vercel.app/// ",
        NEXT_PUBLIC_VERCEL_URL: "ignored.vercel.app",
      })
    ).toBe("https://fantasyhud.vercel.app")
  })

  it("adds HTTPS to a Vercel hostname", () => {
    expect(
      resolveSiteUrl({ NEXT_PUBLIC_VERCEL_URL: "preview.example.vercel.app" })
    ).toBe("https://preview.example.vercel.app")
  })

  it("preserves explicit localhost HTTP", () => {
    expect(
      resolveSiteUrl({ NEXT_PUBLIC_SITE_URL: "http://localhost:3000/" })
    ).toBe("http://localhost:3000")
  })

  it("falls back to local development", () => {
    expect(resolveSiteUrl({})).toBe("http://localhost:3000")
  })

  it("rejects unsupported protocols and non-origin paths", () => {
    expect(() =>
      resolveSiteUrl({ NEXT_PUBLIC_SITE_URL: "ftp://example.test" })
    ).toThrow("must use the http: or https: protocol")
    expect(() =>
      resolveSiteUrl({ NEXT_PUBLIC_SITE_URL: "https://example.test/app" })
    ).toThrow("must be a plain site origin")
  })
})

describe("buildAuthRedirectUrl", () => {
  it("builds only known absolute auth callback URLs", () => {
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://fantasyhud.vercel.app/")
    expect(buildAuthRedirectUrl("/auth/confirm")).toBe(
      "https://fantasyhud.vercel.app/auth/confirm"
    )
    expect(
      buildAuthRedirectUrl("/auth/confirm?next=/auth/update-password")
    ).toBe(
      "https://fantasyhud.vercel.app/auth/confirm?next=/auth/update-password"
    )
    expect(() => buildAuthRedirectUrl("/onboarding")).toThrow(
      "Auth redirect path is not allowed"
    )
  })
})
