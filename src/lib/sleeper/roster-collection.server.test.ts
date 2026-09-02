import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))
vi.mock("./league-users.server", () => ({
  fetchSleeperLeagueUsers: vi.fn(),
}))
vi.mock("./rosters.server", () => ({
  fetchSleeperLeagueRosters: vi.fn(),
}))

import { fetchSleeperLeagueUsers } from "./league-users.server"
import {
  fetchNormalizedSleeperRosterBundles,
  sleeperRosterLeagueConcurrency,
} from "./roster-collection.server"
import { fetchSleeperLeagueRosters } from "./rosters.server"

const mockedUsers = vi.mocked(fetchSleeperLeagueUsers)
const mockedRosters = vi.mocked(fetchSleeperLeagueRosters)

beforeEach(() => {
  vi.clearAllMocks()
  mockedUsers.mockImplementation(async () => ({
    data: [],
    responseBytes: 10,
    fetchedAt: "2026-09-01T20:29:59.000Z",
  }))
  mockedRosters.mockImplementation(async () => ({
    data: [],
    responseBytes: 20,
    fetchedAt: "2026-09-01T20:29:59.500Z",
  }))
})

describe("fetchNormalizedSleeperRosterBundles", () => {
  it("fetches both endpoints and returns exact league order with sanitized metadata", async () => {
    let tick = 0
    const bundles = await fetchNormalizedSleeperRosterBundles(
      [
        { externalLeagueId: "league-b", rosterPositions: ["QB"] },
        { externalLeagueId: "league-a", rosterPositions: ["QB"] },
      ],
      2026,
      {
        now: () => new Date("2026-09-01T20:30:00.000Z"),
        monotonicNow: () => {
          tick += 5
          return tick
        },
      }
    )

    expect(bundles.map((bundle) => bundle.externalLeagueId)).toEqual([
      "league-a",
      "league-b",
    ])
    expect(mockedUsers).toHaveBeenCalledTimes(2)
    expect(mockedRosters).toHaveBeenCalledTimes(2)
    expect(bundles[0]?.sourceMetadata).toMatchObject({
      users_endpoint_succeeded: 1,
      rosters_endpoint_succeeded: 1,
      users_response_bytes: 10,
      rosters_response_bytes: 20,
    })
    expect(sleeperRosterLeagueConcurrency).toBe(4)
  })

  it("rejects the entire collection after one endpoint failure", async () => {
    mockedRosters.mockRejectedValueOnce(new Error("source failed"))
    await expect(
      fetchNormalizedSleeperRosterBundles(
        [{ externalLeagueId: "league-a", rosterPositions: ["QB"] }],
        2026
      )
    ).rejects.toThrow("source failed")
  })

  it("caps collection at four leagues and eight endpoint requests", async () => {
    let activeRequests = 0
    let maximumActiveRequests = 0
    const endpoint = async () => {
      activeRequests += 1
      maximumActiveRequests = Math.max(maximumActiveRequests, activeRequests)
      await new Promise((resolve) => setTimeout(resolve, 5))
      activeRequests -= 1
      return {
        data: [],
        responseBytes: 10,
        fetchedAt: "2026-09-01T20:29:59.000Z",
      }
    }
    mockedUsers.mockImplementation(endpoint)
    mockedRosters.mockImplementation(endpoint)

    await fetchNormalizedSleeperRosterBundles(
      Array.from({ length: 6 }, (_value, index) => ({
        externalLeagueId: `league-${index}`,
        rosterPositions: ["QB"],
      })),
      2026
    )

    expect(maximumActiveRequests).toBe(8)
  })
})
