import { beforeEach, it, expect, vi } from "vitest"
vi.mock("server-only", () => ({}))
vi.mock("@/lib/tracker/source.server", () => ({
  requireTrackerAccess: vi.fn(),
  loadTrackerResearchSource: vi.fn(),
  trackerPlayerToken: (id: string) =>
    id === "p1" ? "b".repeat(24) : "c".repeat(24),
}))
vi.mock("./consumer.server", () => ({
  loadMarket: vi.fn(),
  loadWeeklyStatistics: vi.fn(),
}))
import {
  requireTrackerAccess,
  loadTrackerResearchSource,
} from "@/lib/tracker/source.server"
import { loadMarket, loadWeeklyStatistics } from "./consumer.server"
import { loadResearch, loadPlayerProfile } from "./source.server"
const token = "a".repeat(24)
const league = {
  token,
  name: "Synthetic league",
  scoring: { rec: 1, rush_yd: 0.1 },
  positions: ["QB", "RB"],
  teams: 2,
  management: "redraft",
  rosters: [{ owned: true, players: ["p1"] }],
  matchups: [{ playerPoints: { p1: 12 } }],
}
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(requireTrackerAccess).mockResolvedValue(
    {} as Awaited<ReturnType<typeof requireTrackerAccess>>
  )
  vi.mocked(loadTrackerResearchSource).mockResolvedValue({
    state: { season: 2026, week: 2 },
    overview: { leagues: [league], membershipCount: 4 },
    boards: [
      {
        id: "draft",
        type: "snake",
        complete: true,
        error: null,
        teams: 2,
        leagueToken: token,
        picks: [
          {
            id: "p1",
            name: "Runner",
            position: "RB",
            team: "BUF",
            pick: 12,
            own: true,
            keeper: false,
            amount: null,
          },
        ],
      },
    ],
  } as unknown as Awaited<ReturnType<typeof loadTrackerResearchSource>>)
  vi.mocked(loadMarket).mockResolvedValue({
    fetchedAt: "2026-09-10T12:00:00Z",
    url: "https://api.sleeper.app/projections/nfl/2026",
    players: [
      {
        id: "p1",
        name: "Runner",
        position: "RB",
        team: "BUF",
        injury: null,
        updatedAt: null,
        adp: { adp_ppr: 10 },
      },
      {
        id: "p2",
        name: "Other Runner",
        position: "RB",
        team: "SEA",
        injury: null,
        updatedAt: null,
        adp: { adp_ppr: 20 },
      },
    ],
  })
  vi.mocked(loadWeeklyStatistics).mockImplementation(async (_, week) => ({
    url: `https://api.sleeper.app/stats/nfl/2026/${week}`,
    fetchedAt: "2026-09-10T12:00:00Z",
    rows: [
      {
        id: "p1",
        position: "RB",
        week,
        team: "BUF",
        opponent: "SEA",
        updatedAt: null,
        stats: { gp: 1, rec: 2, rush_yd: 100 },
      },
      {
        id: "p2",
        position: "RB",
        week,
        team: "SEA",
        opponent: "BUF",
        updatedAt: null,
        stats: { gp: 1, rec: 4, rush_yd: 120 },
      },
    ],
  }))
})
it("automatically connects actual picks, explicit market prices and full-source weekly results", async () => {
  const r = await loadResearch()
  expect(r.membershipCount).toBe(4)
  expect(r.completedDrafts).toBe(1)
  expect(r.acquisitions[0]).toMatchObject({
    marketAdp: 10,
    equivalentAdp: 12,
    adpGain: 2,
    impliedRank: 1.2,
    actualRank: 2,
    livePoints: 24,
    points: 12,
    rankGain: -0.8,
  })
  expect(r.issues).toEqual([])
})
it("never manufactures an ADP baseline when the feed fails", async () => {
  vi.mocked(loadMarket).mockRejectedValue(new Error("unavailable"))
  const r = await loadResearch()
  expect(r.acquisitions[0]?.marketAdp).toBeNull()
  expect(r.acquisitions[0]?.impliedRank).toBeNull()
  expect(r.issues).toContain(
    "Sleeper ADP could not be refreshed. No substitute rankings were invented."
  )
})
it("suppresses cumulative outcomes for a missing week", async () => {
  vi.mocked(loadWeeklyStatistics).mockRejectedValueOnce(
    new Error("unavailable")
  )
  const r = await loadResearch()
  expect(r.acquisitions[0]?.actualRank).toBeNull()
  expect(r.acquisitions[0]?.rankGain).toBeNull()
})
it("cross-checks against authoritative matchup player scores and withholds disagreement", async () => {
  vi.mocked(loadTrackerResearchSource).mockResolvedValueOnce({
    ...(await loadTrackerResearchSource()),
    overview: {
      leagues: [{ ...league, matchups: [{ playerPoints: { p1: 999 } }] }],
      membershipCount: 4,
    },
  } as unknown as Awaited<ReturnType<typeof loadTrackerResearchSource>>)
  const r = await loadResearch()
  expect(r.acquisitions[0]?.livePoints).toBeNull()
  expect(r.issues.join()).toContain("could not be verified")
})
it("profiles provide actual weekly history and source dates with opaque identifiers", async () => {
  const r = await loadPlayerProfile("b".repeat(24), token)
  expect(r.weekly).toHaveLength(2)
  expect(r.weekly[1]).toMatchObject({
    points: 12,
    cumulative: 24,
    provisional: true,
  })
  expect(r.marketAdp).toBe(10)
  expect(r.acquisitions).toHaveLength(1)
})
it("rejects arbitrary provider and context identifiers", async () => {
  await expect(loadPlayerProfile("p1", null)).rejects.toThrow("Invalid")
  await expect(
    loadPlayerProfile("b".repeat(24), "f".repeat(24))
  ).rejects.toThrow("context")
})
it("access is checked before calling research sources", async () => {
  vi.mocked(requireTrackerAccess).mockRejectedValue(new Error("access denied"))
  await expect(loadResearch()).rejects.toThrow("access denied")
  expect(loadTrackerResearchSource).not.toHaveBeenCalled()
  expect(loadMarket).not.toHaveBeenCalled()
})
