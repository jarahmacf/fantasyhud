import "server-only"

import { sleeperGetJsonWithMetadata } from "./http.server"
import { normalizeSleeperPlayerCatalog } from "./player-normalization"
import type { SleeperPlayerCatalogSource } from "./player-types"

export const sleeperPlayerCatalogTimeoutMs = 30_000
export const sleeperPlayerCatalogMaximumBytes = 25_000_000

export async function fetchSleeperPlayerCatalog(): Promise<SleeperPlayerCatalogSource> {
  const source = await sleeperGetJsonWithMetadata(["players", "nfl"], {
    timeoutMs: sleeperPlayerCatalogTimeoutMs,
    maxResponseBytes: sleeperPlayerCatalogMaximumBytes,
  })
  const records = normalizeSleeperPlayerCatalog(source.data, source.fetchedAt)

  return {
    records,
    sourceFetchedAt: source.fetchedAt,
    sourceBytes: source.responseBytes,
    sourceRecordCount: records.length,
  }
}
