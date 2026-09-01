import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))
vi.mock("./http.server", () => ({
  sleeperGetJsonWithMetadata: vi.fn(),
}))

import { sleeperGetJsonWithMetadata } from "./http.server"
import {
  fetchSleeperPlayerCatalog,
  sleeperPlayerCatalogMaximumBytes,
  sleeperPlayerCatalogTimeoutMs,
} from "./player-catalog.server"

const mockedGet = vi.mocked(sleeperGetJsonWithMetadata)

beforeEach(() => mockedGet.mockReset())

describe("fetchSleeperPlayerCatalog", () => {
  it("fetches the unfiltered full endpoint with its large-response limits", async () => {
    const data: Record<string, Record<string, unknown>> = {}
    for (let index = 0; index < 500; index += 1) {
      const id = `player-${index.toString().padStart(4, "0")}`
      data[id] = { player_id: id, sport: "nfl" }
    }
    mockedGet.mockResolvedValue({
      data,
      fetchedAt: "2026-08-31T12:00:00.000Z",
      responseBytes: 20_000,
    })

    const result = await fetchSleeperPlayerCatalog()

    expect(mockedGet).toHaveBeenCalledWith(["players", "nfl"], {
      timeoutMs: sleeperPlayerCatalogTimeoutMs,
      maxResponseBytes: sleeperPlayerCatalogMaximumBytes,
    })
    expect(sleeperPlayerCatalogTimeoutMs).toBe(30_000)
    expect(sleeperPlayerCatalogMaximumBytes).toBe(15_000_000)
    expect(result).toMatchObject({
      sourceRecordCount: 500,
      sourceBytes: 20_000,
      sourceFetchedAt: "2026-08-31T12:00:00.000Z",
    })
  })
})
