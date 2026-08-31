import { describe, expect, it } from "vitest"

import duplicateCollection from "./fixtures/league-collection-duplicate.json"
import emptyCollection from "./fixtures/league-collection-empty.json"
import malformedCollection from "./fixtures/league-collection-malformed.json"
import normalCollection from "./fixtures/league-collection-normal.json"
import wrongSeasonCollection from "./fixtures/league-collection-wrong-season.json"
import bestBallFixture from "./fixtures/league-half-ppr-best-ball.json"
import customFixture from "./fixtures/league-custom-te-premium.json"
import dynastyFixture from "./fixtures/league-dynasty-superflex.json"
import idpFixture from "./fixtures/league-idp.json"
import managedFixture from "./fixtures/league-ppr-managed.json"
import { normalizeSleeperLeagueCollection } from "./league-normalization"

const fetchedAt = "2026-08-31T08:02:00.000Z"

function normalizeOne(value: unknown) {
  return normalizeSleeperLeagueCollection([value], 2026, fetchedAt)[0]!
}

describe("normalizeSleeperLeagueCollection", () => {
  it("preserves canonical IDs as strings and exact source JSON", () => {
    const normalized = normalizeOne(bestBallFixture)
    expect(normalized.externalLeagueId).toBe("fixture-league-best-ball")
    expect(normalized.settings).toEqual(bestBallFixture.settings)
    expect(normalized.scoringSettings).toEqual(bestBallFixture.scoring_settings)
    expect(normalized.rosterPositions).toEqual(bestBallFixture.roster_positions)
  })

  it("classifies redraft half-PPR best ball only from explicit settings", () => {
    expect(normalizeOne(bestBallFixture)).toMatchObject({
      rosterManagementType: "redraft",
      isBestBall: true,
      scoringFormat: "half_ppr",
    })
  })

  it("classifies managed PPR and preserves previous league identity", () => {
    expect(normalizeOne(managedFixture)).toMatchObject({
      rosterManagementType: "keeper",
      isBestBall: false,
      scoringFormat: "ppr",
      previousExternalLeagueId: "fixture-league-managed-2025",
    })
  })

  it("classifies dynasty, standard scoring, and superflex independently", () => {
    expect(normalizeOne(dynastyFixture)).toMatchObject({
      rosterManagementType: "dynasty",
      scoringFormat: "standard",
      hasSuperflex: true,
      hasIdp: false,
    })
  })

  it("classifies verified individual defensive positions but not DEF alone", () => {
    expect(normalizeOne(idpFixture).hasIdp).toBe(true)
    expect(
      normalizeOne({ ...bestBallFixture, roster_positions: ["QB", "DEF"] })
        .hasIdp
    ).toBe(false)
  })

  it("classifies material TE premium as custom", () => {
    expect(normalizeOne(customFixture).scoringFormat).toBe("custom")
  })

  it("returns unknown when base reception scoring is missing or malformed", () => {
    expect(
      normalizeOne({ ...managedFixture, scoring_settings: {} }).scoringFormat
    ).toBe("unknown")
    expect(
      normalizeOne({ ...managedFixture, scoring_settings: { rec: "1" } })
        .scoringFormat
    ).toBe("unknown")
  })

  it("does not treat ordinary receiving yards or touchdowns as custom", () => {
    expect(normalizeOne(bestBallFixture).scoringFormat).toBe("half_ppr")
  })

  it("builds the avatar URL and retains provider metadata", () => {
    expect(normalizeOne(bestBallFixture)).toMatchObject({
      avatarUrl: "https://sleepercdn.com/avatars/fixture-best-ball-avatar",
      providerMetadata: { draft_id: "fixture-draft-best-ball" },
    })
  })

  it("records fetch time and never invents provider update time", () => {
    expect(normalizeOne(bestBallFixture)).toMatchObject({
      fetchedAt,
      providerUpdatedAt: null,
    })
  })

  it("accepts an empty complete collection", () => {
    expect(
      normalizeSleeperLeagueCollection(emptyCollection, 2026, fetchedAt)
    ).toEqual([])
  })

  it("normalizes a complete valid collection", () => {
    expect(
      normalizeSleeperLeagueCollection(normalCollection, 2026, fetchedAt)
    ).toHaveLength(2)
  })

  it("rejects a wrong top-level shape", () => {
    expect(() =>
      normalizeSleeperLeagueCollection({}, 2026, fetchedAt)
    ).toThrow()
  })

  it("rejects the entire collection when one item is malformed", () => {
    expect(() =>
      normalizeSleeperLeagueCollection(malformedCollection, 2026, fetchedAt)
    ).toThrow()
  })

  it("rejects duplicate league IDs", () => {
    expect(() =>
      normalizeSleeperLeagueCollection(duplicateCollection, 2026, fetchedAt)
    ).toThrow()
  })

  it("rejects wrong-season leagues", () => {
    expect(() =>
      normalizeSleeperLeagueCollection(wrongSeasonCollection, 2026, fetchedAt)
    ).toThrow()
  })

  it("rejects numeric provider IDs", () => {
    expect(() =>
      normalizeOne({ ...bestBallFixture, league_id: 9007199254740992 })
    ).toThrow()
  })

  it("does not infer best ball from unexpected truthy values", () => {
    expect(
      normalizeOne({
        ...bestBallFixture,
        settings: { ...bestBallFixture.settings, best_ball: "1" },
      }).isBestBall
    ).toBe(false)
  })
})
