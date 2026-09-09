import { describe, expect, it } from "vitest"
import {
  calculateManualBenchmark,
  compareManualOutcome,
  EMPTY_CALCULATOR,
  restoreManualCalculation,
  saveManualCalculation,
} from "./calculator"

const input = {
  ...EMPTY_CALCULATOR,
  contextLabel: "My exact scoring / format / market date",
  curve: "10,30\n11,34\n12,39",
  playerMarketRank: "14",
}
const outcome = {
  week: "6",
  rankingType: "season_total_points_rank" as const,
  actualRank: "7",
  minimumGames: "",
  gamesPlayed: "",
}
describe("manual calculation boundary", () => {
  it("uses the same price interpolation as the contextual benchmark engine", () => {
    expect(calculateManualBenchmark(input)).toMatchObject({
      pricedRank: 11,
      playerMarketRank: 14,
      priceLabel: "3.10 · pick 34",
    })
    expect(
      compareManualOutcome(calculateManualBenchmark(input), outcome)
    ).toMatchObject({ surplus: 4, actualRank: 7, week: 6 })
  })
  it("converts manual auction amounts into budget shares before interpolation", () => {
    expect(
      calculateManualBenchmark({
        ...input,
        kind: "auction",
        auctionAmount: "25",
        auctionBudget: "200",
        curve: "10,40\n11,30\n12,20",
      })
    ).toMatchObject({
      pricedRank: 11.5,
      priceLabel: "25 of 200 · 12.5% of budget",
    })
  })
  it("requires a format label and real numeric inputs, including explicit zero", () => {
    expect(() => calculateManualBenchmark(EMPTY_CALCULATOR)).toThrow(
      /Name the scoring/
    )
    for (const curve of [
      "",
      "10,",
      "10,NaN",
      "10, 30, other",
      "10, 30\n12, 39",
    ])
      expect(() => calculateManualBenchmark({ ...input, curve })).toThrow()
    expect(() => calculateManualBenchmark({ ...input, teams: "" })).toThrow(
      /number/
    )
    expect(() =>
      compareManualOutcome(calculateManualBenchmark(input), {
        ...outcome,
        actualRank: "",
      })
    ).toThrow(/number/)
  })
  it("rejects unqualified PPG outcomes and does not replace them with total-points ranks", () => {
    const ppg = {
      ...outcome,
      rankingType: "season_points_per_game_rank" as const,
      minimumGames: "4",
      gamesPlayed: "3",
    }
    expect(() =>
      compareManualOutcome(calculateManualBenchmark(input), ppg)
    ).toThrow(/does not qualify/)
    expect(
      compareManualOutcome(calculateManualBenchmark(input), {
        ...ppg,
        gamesPlayed: "4",
      })
    ).toMatchObject({ minimumGames: 4, gamesPlayed: 4, surplus: 4 })
  })
  it("round-trips a fixed calculation and its separate weekly comparisons", () => {
    const benchmark = calculateManualBenchmark(input)
    const history = [
      compareManualOutcome(benchmark, outcome),
      compareManualOutcome(benchmark, {
        ...outcome,
        week: "7",
        actualRank: "18",
      }),
    ]
    expect(
      restoreManualCalculation(saveManualCalculation(benchmark, history))
    ).toEqual({ benchmark, history })
  })
  it("recomputes saved metrics and rejects corrupt or incompatible browser storage", () => {
    const saved = JSON.parse(
      saveManualCalculation(calculateManualBenchmark(input), [])
    )
    saved.pricedRank = -100
    expect(
      restoreManualCalculation(JSON.stringify(saved)).benchmark.pricedRank
    ).toBe(11)
    for (const value of [
      "null",
      "{}",
      "not JSON",
      JSON.stringify({ ...saved, version: 2 }),
      JSON.stringify({ ...saved, input: { ...input, curve: "" } }),
    ])
      expect(() => restoreManualCalculation(value)).toThrow(
        /invalid|unsupported/
      )
    expect(() => restoreManualCalculation("x".repeat(65537))).toThrow(/large/)
  })
})
