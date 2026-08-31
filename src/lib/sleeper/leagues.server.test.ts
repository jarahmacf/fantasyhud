import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import normalCollection from "./fixtures/league-collection-normal.json"
import { fetchSleeperLeagues } from "./leagues.server"

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe("fetchSleeperLeagues", () => {
  it("uses the canonical external ID and provider-derived season", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify(normalCollection)))
    vi.stubGlobal("fetch", fetchMock)

    const leagues = await fetchSleeperLeagues("900719925474099312345", 2026, {
      environment: { NODE_ENV: "production" },
      retryDelayMs: 0,
      now: () => new Date("2026-08-31T08:03:00.000Z"),
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.sleeper.app/v1/user/900719925474099312345/leagues/nfl/2026",
      expect.any(Object)
    )
    expect(leagues).toHaveLength(2)
    expect(leagues[0]?.fetchedAt).toBe("2026-08-31T08:03:00.000Z")
  })

  it("URL-encodes canonical ID strings", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify([])))
    vi.stubGlobal("fetch", fetchMock)

    await fetchSleeperLeagues("canonical/id", 2026, {
      environment: {
        NODE_ENV: "test",
        SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
        SLEEPER_LOCAL_TEST_MODE: "1",
      },
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:4100/v1/user/canonical%2Fid/leagues/nfl/2026",
      expect.any(Object)
    )
  })

  it("rejects malformed canonical IDs before any request", async () => {
    vi.stubGlobal("fetch", vi.fn())
    await expect(fetchSleeperLeagues("", 2026)).rejects.toMatchObject({
      kind: "invalid_response",
    })
    expect(fetch).not.toHaveBeenCalled()
  })
})
