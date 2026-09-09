import { describe, expect, it } from "vitest"
import { scoreWeeklyBoxScore } from "./weekly-scoring"

describe("exact weekly scoring coverage", () => {
  it("applies the exact reception and positional premium values", () => {
    const rules = { rec: 1, bonus_rec_te: 0.75, bonus_rec_rb: 0.5, rec_yd: 0.1 }
    const stats = {
      receptions: 8,
      receiving_yards: 100,
      fantasy_points_ppr: 999,
    }
    expect(scoreWeeklyBoxScore(rules, "TE", stats)).toMatchObject({
      status: "available",
      points: 24,
    })
    expect(scoreWeeklyBoxScore(rules, "RB", stats)).toMatchObject({
      status: "available",
      points: 22,
    })
    expect(scoreWeeklyBoxScore(rules, "WR", stats)).toMatchObject({
      status: "available",
      points: 18,
    })
  })
  it("honors custom passing touchdowns and completion points", () => {
    expect(
      scoreWeeklyBoxScore({ pass_td: 5, pass_cmp: 0.1, pass_int: -2 }, "QB", {
        passing_tds: 3,
        completions: 20,
        passing_interceptions: 1,
      })
    ).toMatchObject({ status: "available", points: 15 })
  })
  it("blocks distance bonuses instead of approximating from total yards", () => {
    expect(
      scoreWeeklyBoxScore({ rec: 1, rec_40p: 0.5 }, "WR", {
        receptions: 5,
        receiving_yards: 200,
      })
    ).toEqual({
      status: "unavailable",
      unsupportedRuleKeys: ["rec_40p"],
      missingStatKeys: [],
    })
  })
  it("does not construct a complete fumbles total from incomplete subcategories", () => {
    expect(
      scoreWeeklyBoxScore({ fum_lost: -2 }, "RB", {
        rushing_fumbles_lost: 0,
        receiving_fumbles_lost: 0,
        sack_fumbles_lost: 0,
      })
    ).toMatchObject({
      status: "unavailable",
      unsupportedRuleKeys: ["fum_lost"],
    })
  })
  it.each([undefined, null, "0", NaN, Infinity])(
    "does not turn missing or malformed stats into zero: %s",
    (value) => {
      expect(
        scoreWeeklyBoxScore({ rec: 1 }, "RB", { receptions: value })
      ).toMatchObject({
        status: "unavailable",
        missingStatKeys: ["receptions"],
      })
    }
  )
  it("accepts explicit zero and negative yardage", () => {
    expect(
      scoreWeeklyBoxScore({ rush_yd: 0.1, rec: 1 }, "RB", {
        rushing_yards: -10,
        receptions: 0,
      })
    ).toMatchObject({ status: "available", points: -1 })
  })
  it("ignores only numeric zero rules", () => {
    expect(scoreWeeklyBoxScore({ unreviewed: 0 }, "RB", {}).status).toBe(
      "available"
    )
    expect(scoreWeeklyBoxScore({ unreviewed: "0" }, "RB", {}).status).toBe(
      "unavailable"
    )
  })
  it("does not treat unknown positions as proof a premium is irrelevant", () => {
    expect(
      scoreWeeklyBoxScore({ bonus_rec_te: 1 }, "UNKNOWN", { receptions: 5 })
        .status
    ).toBe("unavailable")
  })
  it("does not accept inherited object keys as scoring rules", () => {
    expect(scoreWeeklyBoxScore({ constructor: 1 }, "RB", {}).status).toBe(
      "unavailable"
    )
  })
})
