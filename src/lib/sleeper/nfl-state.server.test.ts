import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import nflStateFixture from "./fixtures/nfl-state.json"
import { fetchNflState, normalizeNflState } from "./nfl-state.server"

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe("normalizeNflState", () => {
  it("normalizes provider state and preserves unmodeled metadata", () => {
    expect(
      normalizeNflState(nflStateFixture, "2026-08-31T08:00:00.000Z")
    ).toEqual({
      season: 2026,
      leagueSeason: 2026,
      leagueCreateSeason: 2027,
      previousSeason: 2025,
      seasonType: "regular",
      week: 1,
      leg: 1,
      displayWeek: 1,
      seasonStartDate: "2026-09-10",
      providerMetadata: { season_has_scores: false },
      fetchedAt: "2026-08-31T08:00:00.000Z",
    })
  })

  it("prefers league_season over season", () => {
    expect(
      normalizeNflState(
        { ...nflStateFixture, season: "2025", league_season: "2026" },
        "2026-08-31T08:00:00.000Z"
      ).leagueSeason
    ).toBe(2026)
  })

  it("falls back to provider season when league_season is absent", () => {
    const withoutLeagueSeason: Record<string, unknown> = {
      ...nflStateFixture,
    }
    delete withoutLeagueSeason.league_season
    expect(
      normalizeNflState(withoutLeagueSeason, "2026-08-31T08:00:00.000Z")
        .leagueSeason
    ).toBe(2026)
  })

  it("never falls back to the local calendar", () => {
    expect(() =>
      normalizeNflState({ season_type: "regular" }, "2026-08-31T08:00:00.000Z")
    ).toThrow("Sleeper returned an unexpected response.")
  })

  it("accepts conservative integer seasons", () => {
    expect(
      normalizeNflState(
        { ...nflStateFixture, season: 2026, league_season: 2026 },
        "2026-08-31T08:00:00.000Z"
      ).season
    ).toBe(2026)
  })

  it("rejects malformed dates and period fields", () => {
    expect(() =>
      normalizeNflState(
        { ...nflStateFixture, week: -1 },
        "2026-08-31T08:00:00.000Z"
      )
    ).toThrow()
    expect(() =>
      normalizeNflState(
        { ...nflStateFixture, season_start_date: "2026-02-31" },
        "2026-08-31T08:00:00.000Z"
      )
    ).toThrow()
  })
})

describe("fetchNflState", () => {
  it("fetches the official state path and timestamps completion", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify(nflStateFixture)))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      fetchNflState({
        environment: { NODE_ENV: "production" },
        retryDelayMs: 0,
        now: () => new Date("2026-08-31T08:01:00.000Z"),
      })
    ).resolves.toMatchObject({
      leagueSeason: 2026,
      fetchedAt: "2026-08-31T08:01:00.000Z",
    })
    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.sleeper.app/v1/state/nfl",
      expect.any(Object)
    )
  })
})
