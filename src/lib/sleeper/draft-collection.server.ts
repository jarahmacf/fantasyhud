import "server-only"

import { mapWithBoundedConcurrency } from "./bounded-concurrency"
import {
  exactDraftToken,
  invalidDraft,
  maximumDrafts,
  normalizeDraftBoard,
  normalizeDraftDetail,
  normalizeDraftList,
} from "./draft-normalization"
import {
  sleeperGetJsonWithMetadata,
  type SleeperHttpOptions,
} from "./http.server"

export type FrozenDraftScope = Readonly<{
  externalUserId: string
  season: number
  externalLeagueIds: readonly string[]
}>

type CollectionOptions = SleeperHttpOptions & {
  heartbeat?: () => Promise<void>
}

/** Complete sources only. Callers stage privately and publish the entire collection atomically. */
export async function fetchNormalizedSleeperDraftCollection(
  scope: FrozenDraftScope,
  options: CollectionOptions = {}
) {
  const accountId = exactDraftToken(scope.externalUserId)
  const season = scope.season
  const leagueIds = scope.externalLeagueIds.map(exactDraftToken).sort()
  if (
    !Number.isSafeInteger(season) ||
    season < 1900 ||
    season > 2999 ||
    leagueIds.length > 1_000 ||
    new Set(leagueIds).size !== leagueIds.length
  )
    invalidDraft()
  const { heartbeat = async () => {}, ...httpOptions } = options
  let collectionBytes = 0
  const read = async (segments: string[]) => {
    const result = await sleeperGetJsonWithMetadata(segments, {
      ...httpOptions,
      timeoutMs: 10_000,
      maxResponseBytes: 10_000_000,
    })
    collectionBytes += result.responseBytes
    if (collectionBytes > 40_000_000) invalidDraft()
    await heartbeat()
    return result
  }
  const userSource = await read([
    "user",
    accountId,
    "drafts",
    "nfl",
    String(season),
  ])
  const userDrafts = normalizeDraftList(userSource.data, season)
  const leagues = await mapWithBoundedConcurrency(
    leagueIds,
    4,
    async (externalLeagueId) => {
      const source = await read(["league", externalLeagueId, "drafts"])
      const drafts = normalizeDraftList(source.data, season, externalLeagueId)
      return {
        externalLeagueId,
        sourceFetchedAt: source.fetchedAt,
        responseBytes: source.responseBytes,
        drafts,
      }
    }
  )
  const expected = new Map(userDrafts.map((d) => [d.externalDraftId, d]))
  for (const league of leagues)
    for (const draft of league.drafts) {
      const existing = expected.get(draft.externalDraftId)
      if (
        existing &&
        (existing.externalLeagueId !== draft.externalLeagueId ||
          existing.seasonType !== draft.seasonType ||
          existing.draftType !== draft.draftType)
      )
        invalidDraft()
      expected.set(draft.externalDraftId, draft)
    }
  if (expected.size > maximumDrafts) invalidDraft()
  const drafts = await mapWithBoundedConcurrency(
    [...expected.values()].sort((a, b) =>
      a.externalDraftId < b.externalDraftId ? -1 : 1
    ),
    4,
    async (expectedDetail) => {
      const id = expectedDetail.externalDraftId
      // Detail follows list; picks follow detail. No source timestamp is invented from draft creation.
      const detailSource = await read(["draft", id])
      const detail = normalizeDraftDetail(detailSource.data, season, id)
      if (
        detail.externalLeagueId !== expectedDetail.externalLeagueId ||
        detail.seasonType !== expectedDetail.seasonType ||
        detail.draftType !== expectedDetail.draftType
      )
        invalidDraft()
      const picksSource = await read(["draft", id, "picks"])
      const board = normalizeDraftBoard(detail, picksSource.data)
      // Mutable boards can legitimately advance between detail and picks and are never finalized.
      return {
        ...board,
        detailFetchedAt: detailSource.fetchedAt,
        boardFetchedAt: picksSource.fetchedAt,
        sourceBytes: detailSource.responseBytes + picksSource.responseBytes,
      }
    }
  )
  return {
    version: "sleeper-draft-collection/v1" as const,
    scope: { externalUserId: accountId, season, externalLeagueIds: leagueIds },
    userCollection: {
      sourceFetchedAt: userSource.fetchedAt,
      externalDraftIds: userDrafts.map((d) => d.externalDraftId),
      responseBytes: userSource.responseBytes,
    },
    leagueCollections: leagues.map((l) => ({
      externalLeagueId: l.externalLeagueId,
      sourceFetchedAt: l.sourceFetchedAt,
      externalDraftIds: l.drafts.map((d) => d.externalDraftId),
      responseBytes: l.responseBytes,
    })),
    drafts,
  }
}
export type NormalizedDraftCollection = Awaited<
  ReturnType<typeof fetchNormalizedSleeperDraftCollection>
>
