import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import {
  fetchSleeperLeagueUsers,
  sleeperLeagueUsersMaximumBytes,
  sleeperLeagueUsersTimeoutMs,
} from "./league-users.server"

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe("fetchSleeperLeagueUsers", () => {
  it("uses an encoded exact league path and the roster-source limits", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response("[]"))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      fetchSleeperLeagueUsers("league/id", {
        environment: {
          NODE_ENV: "test",
          SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
          SLEEPER_LOCAL_TEST_MODE: "1",
        },
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ data: [], responseBytes: 2 })

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:4100/v1/league/league%2Fid/users",
      expect.objectContaining({
        method: "GET",
        headers: { Accept: "application/json" },
        cache: "no-store",
      })
    )
    expect(sleeperLeagueUsersTimeoutMs).toBe(10_000)
    expect(sleeperLeagueUsersMaximumBytes).toBe(5_000_000)
  })

  it("rejects a padded league ID before a request", async () => {
    vi.stubGlobal("fetch", vi.fn())
    await expect(fetchSleeperLeagueUsers(" league ")).rejects.toMatchObject({
      kind: "invalid_response",
    })
    expect(fetch).not.toHaveBeenCalled()
  })
})
