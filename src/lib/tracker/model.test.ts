import { describe, expect, it } from "vitest"
import {
  evaluateTrackerDraft,
  normalizeTrackerMatchups,
  normalizeTrackerRosters,
  type TrackerDraft,
  type TrackerWeek,
} from "./model"
const draft: TrackerDraft = {
  id: "d",
  type: "snake",
  complete: true,
  teams: 2,
  error: null,
  picks: [1, 2].map((n) => ({
    id: `p${n}`,
    name: `Player ${n}`,
    position: "RB",
    team: null,
    pick: n,
    round: 1,
    slot: n,
    own: n === 1,
    keeper: null,
    amount: null,
  })),
}
const week = (scores: Record<string, number>): TrackerWeek => ({
  week: 1,
  fetchedAt: "2026-09-09T23:00:00Z",
  error: null,
  matchups: normalizeTrackerMatchups([
    {
      roster_id: 1,
      matchup_id: 1,
      players: Object.keys(scores),
      starters: ["p1"],
      points: 10,
      custom_points: 0,
      players_points: scores,
    },
  ]),
})
describe("PickWorth league-source adaptation", () => {
  it("preserves zero commissioner overrides and missing scores", () => {
    const [row] = normalizeTrackerMatchups([
      {
        roster_id: 1,
        matchup_id: null,
        players: null,
        starters: null,
        points: 12,
        custom_points: 0,
      },
    ])
    expect(row!.customPoints).toBe(0)
    expect(row!.playerPoints).toBeNull()
    expect(row!.players).toBeNull()
  })
  it("allows repeated starter placeholders without making players", () => {
    expect(
      normalizeTrackerMatchups([
        {
          roster_id: 1,
          matchup_id: null,
          players: [],
          starters: ["0", "0"],
          points: 0,
        },
      ])[0]!.starters
    ).toEqual(["0", "0"])
  })
  it("rejects duplicate rosters and malformed score values", () => {
    expect(() =>
      normalizeTrackerMatchups([{ roster_id: 1 }, { roster_id: 1 }])
    ).toThrow()
    expect(() =>
      normalizeTrackerMatchups([{ roster_id: 1, players_points: { p1: "2" } }])
    ).toThrow()
  })
  it("confirms owner and co-owner independently from league membership", () => {
    expect(
      normalizeTrackerRosters(
        [
          {
            roster_id: 1,
            owner_id: "other",
            co_owners: ["me"],
            players: [],
            settings: { wins: 0 },
          },
        ],
        "me"
      )[0]
    ).toMatchObject({ owned: true, wins: 0, losses: null })
  })
  it("maps draft cost to position rank and compares complete observed scores", () => {
    const rows = evaluateTrackerDraft(draft, [week({ p1: 10, p2: 20 })], 1)
    expect(rows[0]).toMatchObject({
      priceRank: 1,
      actualRank: 2,
      rankDelta: -1,
      pointsAbovePrice: -10,
      keeper: null,
    })
    expect(rows[1]).toMatchObject({
      priceRank: 2,
      actualRank: 1,
      rankDelta: 1,
      pointsAbovePrice: 10,
    })
  })
  it("uses competition ranks for tied scores", () => {
    expect(
      evaluateTrackerDraft(draft, [week({ p1: 10, p2: 10 })], 1).map(
        (p) => p.actualRank
      )
    ).toEqual([1, 1])
  })
  it("does not publish preseason all-zero ranks", () => {
    expect(
      evaluateTrackerDraft(draft, [week({ p1: 0, p2: 0 })], 1).every(
        (p) => p.actualRank === null
      )
    ).toBe(true)
  })
  it("never invents a missing drafted player's zero", () => {
    const rows = evaluateTrackerDraft(draft, [week({ p1: 10 })], 1)
    expect(rows[1]!.points).toBeNull()
    expect(
      rows.every((p) => p.actualRank === null && p.rankDelta === null)
    ).toBe(true)
  })
  it("suppresses comparisons when a whole week fails", () => {
    expect(
      evaluateTrackerDraft(
        draft,
        [
          week({ p1: 10, p2: 20 }),
          { week: 2, fetchedAt: "now", matchups: null, error: "failed" },
        ],
        2
      ).every((p) => p.rankDelta === null)
    ).toBe(true)
  })
  it("rejects conflicting observations without double-counting duplicate scores", () => {
    const w = week({ p1: 10, p2: 20 })
    w.matchups!.push({
      ...w.matchups![0]!,
      rosterId: "2",
      playerPoints: { p1: 10 },
    })
    expect(evaluateTrackerDraft(draft, [w], 1)[0]!.points).toBe(10)
    w.matchups![1]!.playerPoints = { p1: 11 }
    expect(() => evaluateTrackerDraft(draft, [w], 1)).toThrow("Conflicting")
  })
  it("keeps auction dollars separate from nomination order", () => {
    const d = {
      ...draft,
      type: "auction",
      picks: draft.picks.map((p, i) => ({ ...p, amount: i ? 40 : 5 })),
    }
    expect(
      evaluateTrackerDraft(d, [week({ p1: 10, p2: 20 })], 1).map(
        (p) => p.priceRank
      )
    ).toEqual([2, 1])
  })
  it("requires all auction prices and a completed board", () => {
    const d = {
      ...draft,
      type: "auction",
      picks: draft.picks.map((p, i) => ({ ...p, amount: i ? null : 5 })),
    }
    expect(
      evaluateTrackerDraft(d, [week({ p1: 10, p2: 20 })], 1).every(
        (p) => p.priceRank === null
      )
    ).toBe(true)
    expect(
      evaluateTrackerDraft(
        { ...draft, complete: false },
        [week({ p1: 10, p2: 20 })],
        1
      ).every((p) => p.actualRank === null)
    ).toBe(true)
  })
})
