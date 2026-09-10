import { beforeEach, expect, it, vi } from "vitest"
vi.mock("server-only", () => ({}))
vi.mock("next/cache", () => ({ unstable_cache: (fn: unknown) => fn }))
vi.mock("@/lib/access/workspace.server", () => ({
  getWorkspaceAccess: vi.fn(),
}))
vi.mock("@/lib/sleeper/nfl-state.server", () => ({ fetchNflState: vi.fn() }))
vi.mock("@/lib/sleeper/leagues.server", () => ({
  fetchSleeperLeagues: vi.fn(),
}))
vi.mock("@/lib/sleeper/http.server", () => ({
  sleeperGetJsonWithMetadata: vi.fn(),
}))
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
import { fetchNflState } from "@/lib/sleeper/nfl-state.server"
import { fetchSleeperLeagues } from "@/lib/sleeper/leagues.server"
import { sleeperGetJsonWithMetadata } from "@/lib/sleeper/http.server"
import { loadTrackerDetail, loadTrackerOverview } from "./source.server"
const owner = "1373015982733295616"
beforeEach(() => {
  vi.clearAllMocks()
  const q = {
    select: () => q,
    eq: () => q,
    is: () => q,
    in: async () => ({ data: [], error: null }),
  }
  vi.mocked(getWorkspaceAccess).mockResolvedValue({
    account: { id: "dfe53328-459b-4120-99e3-6c2982f87446" },
    supabase: { from: () => q },
  } as unknown as Awaited<ReturnType<typeof getWorkspaceAccess>>)
  vi.mocked(fetchNflState).mockResolvedValue({
    season: 2026,
    leagueSeason: 2026,
    week: 1,
    seasonType: "regular",
  } as Awaited<ReturnType<typeof fetchNflState>>)
  vi.mocked(fetchSleeperLeagues).mockResolvedValue([
    {
      externalLeagueId: "fixture-league",
      season: 2026,
      name: "League",
      sport: "nfl",
      status: "in_season",
      seasonType: "regular",
      rosterSize: 1,
      hasSuperflex: false,
      hasIdp: false,
      avatarId: null,
      avatarUrl: null,
      previousExternalLeagueId: null,
      settings: {},
      providerMetadata: {},
      providerUpdatedAt: null,
      fetchedAt: "2026-09-09T23:00:00Z",
      teamCount: 2,
      isBestBall: true,
      scoringSettings: { rec: 1 },
      rosterPositions: ["RB"],
      scoringFormat: "ppr",
      rosterManagementType: "redraft",
    },
  ] as Awaited<ReturnType<typeof fetchSleeperLeagues>>)
  vi.mocked(sleeperGetJsonWithMetadata).mockImplementation(async (path) => ({
    fetchedAt: "2026-09-09T23:00:00Z",
    responseBytes: 100,
    data: path.includes("drafts")
      ? []
      : path.includes("rosters")
        ? [
            { roster_id: 1, owner_id: owner, players: ["p1"] },
            { roster_id: 2, owner_id: "other", players: ["p2"] },
          ]
        : [
            {
              roster_id: 1,
              matchup_id: 1,
              players: ["p1"],
              players_points: { p1: 10 },
              points: 10,
            },
            {
              roster_id: 2,
              matchup_id: 1,
              players: ["p2"],
              players_points: { p2: 20 },
              points: 20,
            },
          ],
  }))
})
it("rejects missing workspace access before any provider request", async () => {
  vi.mocked(getWorkspaceAccess).mockResolvedValue(null)
  await expect(loadTrackerOverview()).rejects.toThrow("prototype")
  expect(fetchNflState).not.toHaveBeenCalled()
})
it("rejects another account before any provider request", async () => {
  vi.mocked(getWorkspaceAccess).mockResolvedValue({
    account: { id: "another" },
  } as Awaited<ReturnType<typeof getWorkspaceAccess>>)
  await expect(loadTrackerOverview()).rejects.toThrow()
  expect(fetchNflState).not.toHaveBeenCalled()
})
it("derives canonical identity and season on the server", async () => {
  const result = await loadTrackerOverview()
  expect(fetchSleeperLeagues).toHaveBeenCalledWith(
    owner,
    2026,
    expect.anything()
  )
  expect(result.otherLeagues![0]).toMatchObject({
    error: null,
    rosters: [
      expect.objectContaining({ owned: true }),
      expect.objectContaining({ owned: false }),
    ],
  })
  expect(JSON.stringify(result)).not.toContain(owner)
  expect(result.leagues).toHaveLength(0)
  expect(result.draftSummary?.completed).toBe(0)
  expect(result.membershipCount).toBe(1)
})
it("does not accept a provider league ID or an unrelated token", async () => {
  await expect(loadTrackerDetail("fixture-league")).rejects.toThrow("Invalid")
  await expect(loadTrackerDetail("a".repeat(24))).rejects.toThrow(
    "current collection"
  )
  expect(sleeperGetJsonWithMetadata).not.toHaveBeenCalledWith(
    ["league", "a".repeat(24), expect.anything()],
    expect.anything()
  )
})
it("preserves a failed league as an explicit error", async () => {
  vi.mocked(sleeperGetJsonWithMetadata).mockImplementation(async (path) => {
    if (path.includes("rosters")) throw new Error("upstream")
    return { data: [], responseBytes: 2, fetchedAt: "2026-09-09T23:00:00Z" }
  })
  const result = await loadTrackerOverview()
  expect(result.otherLeagues).toHaveLength(1)
  expect(result.otherLeagues![0]!.error).toBeTruthy()
})
it("loads matchup history only for a server-discovered league", async () => {
  const overview = await loadTrackerOverview()
  const detail = await loadTrackerDetail(overview.otherLeagues![0]!.token)
  expect(detail.weeks).toHaveLength(1)
  expect(detail.weeks[0]!.matchups![0]!.playerPoints).toEqual({ p1: 10 })
  expect(detail.drafts).toEqual([])
})
