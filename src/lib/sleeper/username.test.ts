import { describe, expect, it } from "vitest"

import {
  normalizeSleeperUsername,
  SleeperUsernameValidationError,
} from "./username"

describe("normalizeSleeperUsername", () => {
  it("trims outer whitespace", () => {
    expect(normalizeSleeperUsername("  FixtureUser  ")).toBe("FixtureUser")
  })

  it("removes one optional leading at sign", () => {
    expect(normalizeSleeperUsername("@FixtureUser")).toBe("FixtureUser")
    expect(normalizeSleeperUsername("@@FixtureUser")).toBe("@FixtureUser")
  })

  it("preserves username case", () => {
    expect(normalizeSleeperUsername("MixedCase")).toBe("MixedCase")
  })

  it.each(["", "   ", "@"])('rejects empty input "%s"', (value) => {
    expect(() => normalizeSleeperUsername(value)).toThrow(
      SleeperUsernameValidationError
    )
  })

  it("rejects input longer than 100 characters", () => {
    expect(normalizeSleeperUsername("a".repeat(100))).toHaveLength(100)
    expect(() => normalizeSleeperUsername("a".repeat(101))).toThrow(
      SleeperUsernameValidationError
    )
  })

  it("rejects internal whitespace", () => {
    expect(() => normalizeSleeperUsername("two words")).toThrow(
      SleeperUsernameValidationError
    )
  })

  it("rejects control characters", () => {
    expect(() => normalizeSleeperUsername("name\u0000value")).toThrow(
      SleeperUsernameValidationError
    )
    expect(() => normalizeSleeperUsername("name\n")).toThrow(
      SleeperUsernameValidationError
    )
  })

  it.each(["name/path", "name\\path", "name?query", "name#hash"])(
    'rejects path or query syntax "%s"',
    (value) => {
      expect(() => normalizeSleeperUsername(value)).toThrow(
        SleeperUsernameValidationError
      )
    }
  )

  it("rejects non-string input", () => {
    expect(() => normalizeSleeperUsername(null)).toThrow(
      SleeperUsernameValidationError
    )
  })
})
