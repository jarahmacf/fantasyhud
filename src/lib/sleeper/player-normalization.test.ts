import { describe, expect, it } from "vitest"

import fixtures from "./fixtures/player-normalization.json"
import {
  normalizeSleeperPlayerCatalog,
  normalizeSleeperPlayerRecord,
} from "./player-normalization"
import { SleeperClientError } from "./types"

const fetchedAt = "2026-08-31T12:00:00.000Z"

function makeCatalog(
  overrides: Record<string, Record<string, unknown>> = {}
): Record<string, Record<string, unknown>> {
  const catalog: Record<string, Record<string, unknown>> = {}
  for (let index = 0; index < 500; index += 1) {
    const id = `fixture-${index.toString().padStart(4, "0")}`
    catalog[id] = {
      player_id: id,
      sport: "nfl",
      full_name: `Fixture Player ${index}`,
      position: "WR",
      fantasy_positions: ["WR"],
      active: true,
    }
  }
  return { ...catalog, ...overrides }
}

describe("normalizeSleeperPlayerRecord", () => {
  it("normalizes display fields, exact IDs, metadata, and search metadata", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "ordinary",
      fixtures.ordinary,
      fetchedAt
    )

    expect(normalized.sleeperPlayerId).toBe("ordinary")
    expect(normalized.profile).toMatchObject({
      displayName: "Ada Lovelace",
      firstName: "Ada",
      fullName: "Ada Lovelace",
      primaryPosition: "QB",
      fantasyPositions: ["QB"],
      nflTeam: "SEA",
      searchRank: 10,
      profileFetchedAt: fetchedAt,
    })
    expect(normalized.externalIds).toEqual([
      {
        namespace: "espn",
        externalId: "12345",
        reportedBy: "sleeper",
        sourceField: "espn_id",
      },
      {
        namespace: "yahoo",
        externalId: "yahoo-ordinary",
        reportedBy: "sleeper",
        sourceField: "yahoo_id",
      },
    ])
    expect(normalized.profile.sourceMetadata).toMatchObject({
      unmodeled_fields: { custom_source_fact: "retained" },
      normalization_warning_fields: [],
    })
  })

  it("classifies team defenses and falls back to their exact team token", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "defense",
      fixtures.defense,
      fetchedAt
    )
    expect(normalized.profile.entityType).toBe("team_defense")
    expect(normalized.profile.displayName).toBe("SF")
  })

  it("preserves dual-position source order while deduplicating", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "dual",
      fixtures.dual,
      fetchedAt
    )
    expect(normalized.profile.fantasyPositions).toEqual(["WR", "RB"])
    expect(normalized.profile.displayName).toBe("Dual Player")
  })

  it("keeps sparse records without inventing an unknown display name", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "sparse",
      fixtures.sparse,
      fetchedAt
    )
    expect(normalized.profile.entityType).toBe("unknown")
    expect(normalized.profile.displayName).toBeNull()
  })

  it("turns malformed optional values into nulls and bounded warnings", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "malformed",
      fixtures.malformed,
      fetchedAt
    )
    expect(normalized.profile).toMatchObject({
      firstName: null,
      active: null,
      primaryPosition: null,
      fantasyPositions: ["QB"],
      age: null,
      injuryStartDate: null,
      newsUpdatedAt: null,
    })
    expect(normalized.externalIds).toEqual([])
    expect(normalized.normalizationWarningCount).toBeGreaterThan(0)
    expect(
      JSON.stringify(normalized.profile.sourceMetadata).length
    ).toBeLessThan(65_536)
  })

  it.each([
    ["leading tab", "\tPlayer Name"],
    ["trailing tab", "Player Name\t"],
    ["leading newline", "\nPlayer Name"],
    ["trailing newline", "Player Name\n"],
    ["carriage return", "Player\rName"],
    ["null byte", "Player\u0000Name"],
    ["DEL", "Player\u007fName"],
    ["interior control character", "Player\u0008Name"],
  ])(
    "rejects a display field containing an original %s",
    (_label, fullName) => {
      const normalized = normalizeSleeperPlayerRecord(
        "control-display",
        { full_name: fullName },
        fetchedAt
      )

      expect(normalized.profile.fullName).toBeNull()
      expect(
        normalized.profile.sourceMetadata.normalization_warning_fields
      ).toContain("full_name")
    }
  )

  it("trims ordinary and Unicode outer whitespace but preserves internal spaces and case", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "display-whitespace",
      {
        first_name: "  Ada  ",
        last_name: "\u2003Lovelace\u2003",
        full_name: "Ada   Lovelace",
      },
      fetchedAt
    )

    expect(normalized.profile).toMatchObject({
      firstName: "Ada",
      lastName: "Lovelace",
      fullName: "Ada   Lovelace",
      displayName: "Ada   Lovelace",
    })
    expect(
      normalized.profile.sourceMetadata.normalization_warning_fields
    ).toEqual([])
  })

  it("keeps exact canonical IDs, token fields, and secondary IDs unchanged", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "Exact-Player_01",
      {
        position: "QB",
        fantasy_positions: ["QB", "SUPER_FLEX"],
        team: "SEA",
        espn_id: "000123",
      },
      fetchedAt
    )

    expect(normalized.sleeperPlayerId).toBe("Exact-Player_01")
    expect(normalized.profile.primaryPosition).toBe("QB")
    expect(normalized.profile.fantasyPositions).toEqual(["QB", "SUPER_FLEX"])
    expect(normalized.profile.nflTeam).toBe("SEA")
    expect(normalized.externalIds[0]?.externalId).toBe("000123")
  })

  it("parses safe epoch seconds and preserves injury data", () => {
    const normalized = normalizeSleeperPlayerRecord(
      "injured",
      { ...fixtures.injured, news_updated: 1_788_134_400 },
      fetchedAt
    )
    expect(normalized.profile.newsUpdatedAt).toBe("2026-08-31T00:00:00.000Z")
    expect(normalized.profile.injuryStartDate).toBe("2026-08-30")
  })

  it("rejects conflicting identity and sport claims", () => {
    expect(() =>
      normalizeSleeperPlayerRecord(
        "canonical",
        { player_id: "different", sport: "nfl" },
        fetchedAt
      )
    ).toThrow(SleeperClientError)
    expect(() =>
      normalizeSleeperPlayerRecord(
        "canonical",
        { player_id: "canonical", sport: "nba" },
        fetchedAt
      )
    ).toThrow(SleeperClientError)
  })

  it("rejects invalid map keys and non-object records", () => {
    expect(() =>
      normalizeSleeperPlayerRecord(" padded ", {}, fetchedAt)
    ).toThrow(SleeperClientError)
    expect(() => normalizeSleeperPlayerRecord("valid", [], fetchedAt)).toThrow(
      SleeperClientError
    )
  })
})

describe("normalizeSleeperPlayerCatalog", () => {
  it("validates a full top-level map and sorts exact IDs", () => {
    const records = normalizeSleeperPlayerCatalog(makeCatalog(), fetchedAt)
    expect(records).toHaveLength(500)
    expect(records[0]?.sleeperPlayerId).toBe("fixture-0000")
    expect(records.at(-1)?.sleeperPlayerId).toBe("fixture-0499")
  })

  it("rejects arrays and catalog counts outside the hard bounds", () => {
    expect(() => normalizeSleeperPlayerCatalog([], fetchedAt)).toThrow(
      SleeperClientError
    )
    expect(() => normalizeSleeperPlayerCatalog({}, fetchedAt)).toThrow(
      SleeperClientError
    )
  })

  it("keeps duplicate secondary candidates separate for database arbitration", () => {
    const catalog = makeCatalog({
      "fixture-0001": {
        player_id: "fixture-0001",
        sport: "nfl",
        espn_id: "shared",
      },
      "fixture-0002": {
        player_id: "fixture-0002",
        sport: "nfl",
        espn_id: "shared",
      },
    })
    const records = normalizeSleeperPlayerCatalog(catalog, fetchedAt)
    expect(records[1]?.externalIds[0]?.externalId).toBe("shared")
    expect(records[2]?.externalIds[0]?.externalId).toBe("shared")
    expect(records[1]?.sleeperPlayerId).not.toBe(records[2]?.sleeperPlayerId)
  })
})
