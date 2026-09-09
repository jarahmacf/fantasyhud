import { describe, expect, it } from "vitest"
import { freezePriceBenchmark } from "./benchmark"
import { market, performance, purchase } from "./fixtures.test-support"
import {
  comparePriceWithPerformance,
  rankPerformanceUniverse,
} from "./performance"

function benchmark() {
  const result = freezePriceBenchmark(purchase(), market())
  if (result.status !== "available") throw new Error("Expected benchmark")
  return result.benchmark
}
describe("seasonal performance against a fixed purchase price", () => {
  it("reports +4 for a price implying RB11 and a Week 6 outcome of RB7", () => {
    expect(
      comparePriceWithPerformance(
        benchmark(),
        rankPerformanceUniverse(performance(), "season_total_points_rank", null)
      )
    ).toMatchObject({
      pricedPositionRank: 11,
      playerMarketPositionRank: 14,
      actualPositionRank: 7,
      rankSurplus: 4,
      throughWeek: 6,
      isFinal: false,
    })
  })
  it("updates the outcome to RB18 without moving the RB11 benchmark", () => {
    const original = benchmark()
    const universe = performance()
    const ranked = rankPerformanceUniverse(
      {
        ...universe,
        throughWeek: 7,
        players: universe.players.map((player) =>
          player.playerId === "rb-14" ? { ...player, points: 1 } : player
        ),
      },
      "season_total_points_rank",
      null
    )
    expect(comparePriceWithPerformance(original, ranked)).toMatchObject({
      rankSurplus: -7,
    })
    expect(original.pricedPositionRank).toBe(11)
  })
  it("ranks points and PPG separately using the disclosed games threshold", () => {
    const universe = {
      ...performance(),
      players: [
        { playerId: "a", position: "RB", points: 100, gamesPlayed: 6 },
        { playerId: "b", position: "RB", points: 90, gamesPlayed: 3 },
        { playerId: "c", position: "RB", points: 50, gamesPlayed: 1 },
      ],
    }
    expect(
      rankPerformanceUniverse(
        universe,
        "season_total_points_rank",
        null
      ).players.map((p) => p.playerId)
    ).toEqual(["a", "b", "c"])
    expect(
      rankPerformanceUniverse(
        universe,
        "season_points_per_game_rank",
        3
      ).players.map((p) => p.playerId)
    ).toEqual(["b", "a"])
    expect(() =>
      rankPerformanceUniverse(universe, "season_points_per_game_rank", null)
    ).toThrow(/minimum-games/)
  })
  it("uses competition ties (1, 1, 3), including unowned players in the universe", () => {
    const universe = {
      ...performance(),
      players: [
        { playerId: "unowned-a", position: "RB", points: 100, gamesPlayed: 6 },
        { playerId: "unowned-b", position: "RB", points: 100, gamesPlayed: 6 },
        { playerId: "rb-14", position: "RB", points: 90, gamesPlayed: 6 },
        { playerId: "qb", position: "QB", points: 500, gamesPlayed: 6 },
      ],
    }
    const ranked = rankPerformanceUniverse(
      universe,
      "season_total_points_rank",
      null
    )
    expect(
      ranked.players.filter((p) => p.position === "RB").map((p) => p.rank)
    ).toEqual([1, 1, 3])
    expect(ranked.players.find((p) => p.playerId === "qb")?.rank).toBe(1)
    expect(comparePriceWithPerformance(benchmark(), ranked)).toMatchObject({
      rankSurplus: 8,
    })
  })
  it("does not score an unknown custom rule or a holdings-only universe", () => {
    expect(() =>
      rankPerformanceUniverse(
        { ...performance(), unscoredRuleKeys: ["bonus_rec_te"] },
        "season_total_points_rank",
        null
      )
    ).toThrow(/Every scoring rule/)
    expect(() =>
      rankPerformanceUniverse(
        { ...performance(), completeUniverse: false },
        "season_total_points_rank",
        null
      )
    ).toThrow(/complete eligible/)
  })
  it("does not compare a default-PPR result, wrong season or changed position", () => {
    for (const changes of [
      { scoringContextId: "default-ppr" },
      { season: 2025 },
      { positionGroupVersion: "other/v1" },
    ])
      expect(
        comparePriceWithPerformance(
          benchmark(),
          rankPerformanceUniverse(
            { ...performance(), ...changes },
            "season_total_points_rank",
            null
          )
        )
      ).toMatchObject({ reason: "outcome_context_mismatch" })
    const universe = performance()
    expect(
      comparePriceWithPerformance(
        benchmark(),
        rankPerformanceUniverse(
          {
            ...universe,
            players: universe.players.map((p) => ({ ...p, position: "WR" })),
          },
          "season_total_points_rank",
          null
        )
      )
    ).toMatchObject({ reason: "position_changed" })
  })
  it("keeps no outcome distinct from zero points and a rank of last", () => {
    expect(
      comparePriceWithPerformance(
        benchmark(),
        rankPerformanceUniverse(performance(), "season_points_per_game_rank", 7)
      )
    ).toMatchObject({ reason: "no_qualifying_outcome" })
    const zero = {
      ...performance(),
      players: [
        { playerId: "zero", position: "RB", points: 0, gamesPlayed: 0 },
        { playerId: "negative", position: "RB", points: -2, gamesPlayed: 1 },
      ],
    }
    expect(
      rankPerformanceUniverse(zero, "season_total_points_rank", null).players[0]
    ).toMatchObject({ rank: 1, pointsPerGame: null })
  })
  it("rejects duplicated players, nonfinite scores and impossible games", () => {
    const source = performance()
    expect(() =>
      rankPerformanceUniverse(
        { ...source, players: [...source.players, source.players[0]!] },
        "season_total_points_rank",
        null
      )
    ).toThrow(/one explicit/)
    for (const changes of [
      { points: NaN },
      { gamesPlayed: 7 },
      { gamesPlayed: 0 },
    ])
      expect(() =>
        rankPerformanceUniverse(
          { ...source, players: [{ ...source.players[0]!, ...changes }] },
          "season_total_points_rank",
          null
        )
      ).toThrow()
  })
  it("does not rank an entirely unplayed season or compare a pre-purchase result", () => {
    const unplayed = {
      ...performance(),
      players: [
        { playerId: "rb-14", position: "RB", points: 0, gamesPlayed: 0 },
      ],
    }
    expect(
      rankPerformanceUniverse(unplayed, "season_total_points_rank", null)
        .players
    ).toEqual([])
    expect(
      comparePriceWithPerformance(
        benchmark(),
        rankPerformanceUniverse(
          { ...performance(), sourceAsOf: "2026-08-31T00:00:00Z" },
          "season_total_points_rank",
          null
        )
      )
    ).toMatchObject({ reason: "outcome_precedes_purchase" })
  })
})
