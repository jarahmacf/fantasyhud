import { describe, it, expect } from "vitest"
import {
  normalizeMarket,
  normalizeStatistics,
  scorePlayer,
  rankPerformance,
  matchAuction,
  priceImpliedRank,
  marketField,
  hasCompletedParticipation,
  type ResearchContext,
  type MarketPlayer,
  type AuctionObservation,
} from "./model"
const context: ResearchContext = {
  token: "fixture",
  name: "Fixture",
  scoring: { rec: 1, bonus_rec_te: 0.5, rec_yd: 0.1 },
  positions: ["QB", "RB", "WR", "TE", "SUPER_FLEX", "BN"],
  teams: 12,
  dynasty: false,
}
const row = {
  player_id: "player-1",
  player: { first_name: "Fixture", last_name: "Tight End", position: "TE" },
  team: "SEA",
  category: "stat",
  season: "2026",
  season_type: "regular",
  week: 1,
  stats: { gp: 1, rec: 4, bonus_rec_te: 4, rec_yd: 60 },
  last_modified: 1789000000000,
}
const market: MarketPlayer[] = Array.from({ length: 40 }, (_, i) => ({
  id: `p${i}`,
  name: `Player ${i}`,
  position: "RB",
  team: null,
  injury: null,
  updatedAt: null,
  adp: { adp_2qb: i * 5 + 2, adp_ppr: i * 5 + 2 },
}))
const peers: AuctionObservation[] = market.flatMap((p, i) =>
  ["peer1", "peer2"].map((draft) => ({
    draft,
    player: p.id,
    amount: 80 - i * 2,
    budget: 200,
    teams: 12,
    context,
  }))
)
describe("source-backed research", () => {
  it("does not use projections as actual statistics", () => {
    expect(() =>
      normalizeStatistics({ ...row, category: "proj" }, 2026, 1)
    ).toThrow()
    expect(() =>
      normalizeStatistics([{ ...row, category: "proj" }], 2026, 1)
    ).toThrow("Projections")
  })
  it("extracts only explicit ADP, rejects sentinels and never consumes search rank or projected points", () => {
    const p = normalizeMarket(
      [
        {
          ...row,
          category: "proj",
          week: undefined,
          stats: {
            adp_ppr: 23.4,
            adp_2qb: 999,
            search_rank: 1,
            pts_ppr: 300,
            gp: 17,
          },
        },
      ],
      2026
    )[0]!
    expect(p.adp).toEqual({ adp_ppr: 23.4 })
    expect(p).not.toHaveProperty("stats")
  })
  it("rejects wrong season, duplicate identities and numeric player IDs", () => {
    expect(() => normalizeStatistics([row], 2025, 1)).toThrow()
    expect(() => normalizeStatistics([row, row], 2026, 1)).toThrow("Duplicate")
    expect(() =>
      normalizeStatistics([{ ...row, player_id: 9007199254740992 }], 2026, 1)
    ).toThrow("identity")
  })
  it("uses exact TE bonuses; unknown nonzero rules suppress scoring", () => {
    const s = normalizeStatistics([row], 2026, 1)[0]!
    expect(scorePlayer(s, context.scoring)).toBe(12)
    expect(scorePlayer(s, { ...context.scoring, unknown_rule: 2 })).toBeNull()
    expect(scorePlayer(s, { ...context.scoring, unknown_rule: 0 })).toBe(12)
  })
  it("unplayed players cannot become zero-point rank leaders and negative scores remain actual results", () => {
    const s = normalizeStatistics(
      [
        row,
        { ...row, player_id: "idle", stats: { gp: 0 } },
        { ...row, player_id: "negative", stats: { gp: 1, rec_yd: -20 } },
      ],
      2026,
      1
    )
    const ranks = rankPerformance(s, context.scoring, 1)
    expect(ranks.has("idle")).toBe(false)
    expect(ranks.get("negative")).toMatchObject({ points: -2, rank: 2 })
    expect(rankPerformance(s, context.scoring, 0).size).toBe(0)
  })
  it("counts completed participation, rather than source memberships or misleading complete labels", () => {
    const completed = Array.from({ length: 45 }, () => ({
      complete: true,
      error: null,
      picks: [{ own: true }],
    }))
    const extra = [
      { complete: false, error: null, picks: [] },
      { complete: false, error: null, picks: [{ own: true }] },
      { complete: true, error: null, picks: [{ own: false }] },
    ]
    expect(
      [...completed, ...extra].filter(hasCompletedParticipation)
    ).toHaveLength(45)
  })
  it("selects league market fields automatically", () => {
    expect(marketField(context)).toBe("adp_2qb")
    expect(marketField({ ...context, dynasty: true })).toBe("adp_dynasty_2qb")
    expect(
      marketField({ ...context, positions: ["QB"], scoring: { rec: 0.5 } })
    ).toBe("adp_half_ppr")
  })
  it("imputes position rank from market ADP, not within-draft selection order", () => {
    expect(priceImpliedRank(34, "RB", market, "adp_2qb")).toBe(7.4)
    expect(priceImpliedRank(1, "RB", market, "adp_2qb")).toBeNull()
  })
  it("automatically maps auction price to ADP and excludes every own-board observation", () => {
    const fit = matchAuction(60, 200, 12, "subject", context, peers, market)
    expect(fit.equivalentAdp).toBe(52)
    expect(fit.peerDrafts).toBe(2)
    const contaminated = [
      ...peers,
      ...peers.map((p) => ({ ...p, draft: "subject", amount: 200 })),
    ]
    expect(
      matchAuction(60, 200, 12, "subject", context, contaminated, market)
    ).toEqual(fit)
  })
  it("normalizes different budgets and team sizes explicitly", () => {
    const normal = matchAuction(60, 200, 12, "subject", context, peers, market)
    expect(
      matchAuction(120, 400, 12, "subject", context, peers, market)
        .equivalentAdp
    ).toBe(normal.equivalentAdp)
    const adjusted = matchAuction(
      50,
      200,
      10,
      "subject",
      context,
      peers,
      market
    )
    expect(adjusted.equivalentAdp).toBe(52)
    expect(adjusted.adjustedTeams).toBe(true)
  })
  it("does not silently broaden scoring or extrapolate missing auction samples", () => {
    expect(
      matchAuction(
        60,
        200,
        12,
        "subject",
        { ...context, scoring: { rec: 0 } },
        peers,
        market
      ).equivalentAdp
    ).toBeNull()
    const bound = matchAuction(190, 200, 12, "subject", context, peers, market)
    expect(bound.equivalentAdp).toBeNull()
    expect(bound.adpBound).toEqual({ value: 2, direction: "at_most" })
    expect(
      matchAuction(60, 200, 12, "subject", context, peers.slice(0, 4), market)
        .equivalentAdp
    ).toBeNull()
  })
  it("ties use shared performance ranks while games and missing weeks stay explicit", () => {
    const s = normalizeStatistics([row, { ...row, player_id: "tie" }], 2026, 1)
    const ranks = rankPerformance(s, context.scoring, 2)
    expect([...ranks.values()].map((p) => p.rank)).toEqual([1, 1])
    expect(ranks.get("tie")?.games).toBe(1)
    expect(ranks.get("tie")?.weekly).toHaveLength(1)
  })
})
