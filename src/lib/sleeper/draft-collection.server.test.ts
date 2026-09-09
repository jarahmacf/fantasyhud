import { beforeEach, describe, expect, it, vi } from "vitest"
vi.mock("server-only", () => ({}))
vi.mock("./http.server", () => ({ sleeperGetJsonWithMetadata: vi.fn() }))
import { sleeperGetJsonWithMetadata } from "./http.server"
import { fetchNormalizedSleeperDraftCollection } from "./draft-collection.server"
const mocked = vi.mocked(sleeperGetJsonWithMetadata)
const detail = {
  draft_id: "draft-a",
  league_id: "league-a",
  season: "2026",
  sport: "nfl",
  season_type: "regular",
  type: "snake",
  status: "pre_draft",
  settings: { teams: 2, rounds: 1 },
  metadata: {},
}
const scope = {
  externalUserId: "user-a",
  season: 2026,
  externalLeagueIds: ["league-a"],
}
beforeEach(() => {
  vi.clearAllMocks()
  mocked.mockImplementation(async (path) => ({
    data: path[0] === "draft" ? (path[2] === "picks" ? [] : detail) : [detail],
    responseBytes: 200,
    fetchedAt: "2026-09-09T10:00:00.000Z",
  }))
})
describe("complete draft source collection", () => {
  it("fetches a shared draft once and retains both collection memberships", async () => {
    const heartbeat = vi.fn(async () => {})
    const result = await fetchNormalizedSleeperDraftCollection(scope, {
      heartbeat,
    })
    expect(mocked.mock.calls.map(([p]) => p.join("/"))).toEqual([
      "user/user-a/drafts/nfl/2026",
      "league/league-a/drafts",
      "draft/draft-a",
      "draft/draft-a/picks",
    ])
    expect(result.drafts).toHaveLength(1)
    expect(result.userCollection.externalDraftIds).toEqual(["draft-a"])
    expect(result.leagueCollections[0]?.externalDraftIds).toEqual(["draft-a"])
    expect(heartbeat).toHaveBeenCalledTimes(4)
  })
  it("never turns a failed source into an empty collection", async () => {
    mocked.mockRejectedValueOnce(new Error("source failed"))
    await expect(fetchNormalizedSleeperDraftCollection(scope)).rejects.toThrow()
  })
  it("rejects mismatched detail after valid collection lists", async () => {
    mocked.mockImplementation(async (path) => ({
      data:
        path[0] === "draft" ? { ...detail, league_id: "different" } : [detail],
      responseBytes: 100,
      fetchedAt: "2026-09-09T10:00:00Z",
    }))
    await expect(fetchNormalizedSleeperDraftCollection(scope)).rejects.toThrow()
  })
  it("accepts complete explicit empty lists without a board request", async () => {
    mocked.mockResolvedValue({
      data: [],
      responseBytes: 2,
      fetchedAt: "2026-09-09T10:00:00Z",
    })
    expect((await fetchNormalizedSleeperDraftCollection(scope)).drafts).toEqual(
      []
    )
    expect(mocked).toHaveBeenCalledTimes(2)
  })
  it("rejects duplicate frozen leagues before any source call", async () => {
    await expect(
      fetchNormalizedSleeperDraftCollection({
        ...scope,
        externalLeagueIds: ["league-a", "league-a"],
      })
    ).rejects.toThrow()
    expect(mocked).not.toHaveBeenCalled()
  })
  it("bounds the complete collection memory budget", async () => {
    mocked.mockResolvedValue({
      data: [],
      responseBytes: 10_000_000,
      fetchedAt: "2026-09-09T10:00:00Z",
    })
    await expect(
      fetchNormalizedSleeperDraftCollection({
        ...scope,
        externalLeagueIds: ["a", "b", "c", "d"],
      })
    ).rejects.toThrow()
  })
  it("stops when the run heartbeat rejects a stale attempt", async () => {
    await expect(
      fetchNormalizedSleeperDraftCollection(scope, {
        heartbeat: async () => {
          throw new Error("stale")
        },
      })
    ).rejects.toThrow("stale")
    expect(mocked).toHaveBeenCalledTimes(1)
  })
})
