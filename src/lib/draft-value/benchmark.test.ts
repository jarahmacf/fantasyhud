import { describe, expect, it } from "vitest"
import { freezePriceBenchmark } from "./benchmark"
import { market, purchase } from "./fixtures.test-support"

describe("at-purchase price benchmark", () => {
  it("benchmarks the price paid (RB11), separately from the player's market price (RB14)", () => {
    expect(freezePriceBenchmark(purchase(), market())).toMatchObject({
      status: "available",
      benchmark: { pricedPositionRank: 11, playerMarketPositionRank: 14 },
    })
  })
  it("detaches and deeply freezes the original curve, context, and price", () => {
    const source = market()
    const result = freezePriceBenchmark(purchase(), source)
    if (result.status !== "available") throw new Error("Expected a benchmark")
    expect(Object.isFrozen(result.benchmark.market.players[0])).toBe(true)
    expect(Object.isFrozen(result.benchmark.purchase.context)).toBe(true)
    Object.assign(source.players[10]!, { price: 100 })
    expect(result.benchmark.pricedPositionRank).toBe(11)
    expect(result.benchmark.market.players[10]!.price).toBe(34)
  })
  it("does not need the subject player to appear in the comparator market", () => {
    expect(
      freezePriceBenchmark(
        { ...purchase(), playerId: "not-in-market" },
        market()
      )
    ).toMatchObject({
      benchmark: { pricedPositionRank: 11, playerMarketPositionRank: null },
    })
  })
  it("blocks later source publication even if the drafts themselves happened earlier", () => {
    expect(
      freezePriceBenchmark(purchase(), {
        ...market(),
        availableAt: "2026-09-02T00:00:00Z",
      })
    ).toMatchObject({ reason: "future_market_data" })
  })
  it("fails closed on partial historical context and unknown keeper truth", () => {
    expect(
      freezePriceBenchmark(
        {
          ...purchase(),
          context: { ...purchase().context, quality: "partial" },
        },
        market()
      )
    ).toMatchObject({ reason: "inexact_context" })
    for (const isKeeper of [true, null])
      expect(
        freezePriceBenchmark({ ...purchase(), isKeeper }, market())
      ).toMatchObject({ reason: "keeper_or_unknown_keeper" })
  })
  it.each([
    "scoringContextId",
    "formatContextKey",
    "environmentKey",
    "position",
    "positionGroupVersion",
    "playerPool",
    "seasonType",
  ] as const)("does not broaden %s", (key) => {
    expect(
      freezePriceBenchmark(purchase(), {
        ...market(),
        context: { ...market().context, [key]: "different" },
      })
    ).toMatchObject({ reason: "context_mismatch" })
  })
  it("excludes the subject draft and refuses unverified external self-exclusion", () => {
    expect(
      freezePriceBenchmark(purchase(), {
        ...market(),
        constituentDraftIds: ["my-draft", "other-a", "other-b"],
      })
    ).toMatchObject({ reason: "subject_draft_in_sample" })
    expect(
      freezePriceBenchmark(purchase(), {
        ...market(),
        source: "external_market",
        constituentDraftIds: null,
        subjectDraftExcluded: false,
      })
    ).toMatchObject({ reason: "subject_draft_in_sample" })
  })
  it("deduplicates at the canonical-draft boundary by rejecting an inflated count", () => {
    expect(() =>
      freezePriceBenchmark(purchase(), {
        ...market(),
        constituentDraftIds: ["a", "a", "b"],
      })
    ).toThrow(/unique canonical drafts/)
  })
  it("does not silently drop thin-sample players and move every positional rank", () => {
    expect(
      freezePriceBenchmark(purchase(), { ...market(), minimumDrafts: 5 })
    ).toMatchObject({ reason: "insufficient_sample" })
    const source = market()
    expect(
      freezePriceBenchmark(purchase(), {
        ...source,
        players: source.players.map((row, index) => ({
          ...row,
          observations: index === 0 ? 1 : 3,
        })),
      })
    ).toMatchObject({ reason: "insufficient_sample" })
  })
  it("requires matching auction budgets even when normalized fractions agree", () => {
    const target = {
      ...purchase(),
      price: 30,
      context: {
        ...purchase().context,
        priceKind: "auction" as const,
        auctionBudget: 200,
      },
    }
    const source = {
      ...market(),
      context: target.context,
      players: [
        { playerId: "rb-a", price: 0.2, observations: 3 },
        { playerId: "rb-b", price: 0.1, observations: 3 },
      ],
    }
    expect(freezePriceBenchmark(target, source)).toMatchObject({
      benchmark: { pricedPositionRank: 1.5 },
    })
    expect(
      freezePriceBenchmark(target, {
        ...source,
        context: { ...source.context, auctionBudget: 400 },
      })
    ).toMatchObject({ reason: "context_mismatch" })
  })
  it("rejects missing provenance, impossible observations and timezone-free timestamps", () => {
    expect(() =>
      freezePriceBenchmark(purchase(), {
        ...market(),
        availableAt: "2026-09-01T11:00:00",
      })
    ).toThrow(/timezone/)
    expect(() =>
      freezePriceBenchmark(purchase(), { ...market(), sourceRevision: "" })
    ).toThrow(/identifier/)
    expect(() =>
      freezePriceBenchmark(purchase(), {
        ...market(),
        constituentDraftIds: null,
      })
    ).toThrow(/every canonical draft/)
    expect(() =>
      freezePriceBenchmark(purchase(), { ...market(), minimumDrafts: 1 })
    ).toThrow(/two drafts/)
  })
  it("requires a known player pool even if both source labels claim exact quality", () => {
    const unknown = { ...purchase().context, playerPool: "unknown" }
    expect(
      freezePriceBenchmark(
        { ...purchase(), context: unknown },
        { ...market(), context: unknown }
      )
    ).toMatchObject({ reason: "inexact_context" })
  })
})
