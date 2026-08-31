import { describe, expect, it } from "vitest"

import { getSafeInternalNextPath } from "./redirects"

describe("getSafeInternalNextPath", () => {
  it("accepts internal paths with queries", () => {
    expect(getSafeInternalNextPath("/onboarding?from=sign-in")).toBe(
      "/onboarding?from=sign-in"
    )
  })

  it.each([
    "https://attacker.test",
    "//attacker.test/path",
    "\\\\attacker.test",
    "/\\attacker.test",
    "%2F%2Fattacker.test/path",
    "/%5C%5Cattacker.test",
    "%252F%252Fattacker.test",
    "",
  ])("rejects unsafe next value %s", (candidate) => {
    expect(getSafeInternalNextPath(candidate)).toBe("/onboarding")
  })

  it("supports an explicit safe fallback", () => {
    expect(getSafeInternalNextPath(null, "/auth/update-password")).toBe(
      "/auth/update-password"
    )
  })
})
