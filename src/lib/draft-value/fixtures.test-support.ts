import type {
  DraftPurchase,
  PositionalMarketSnapshot,
  PriceContext,
} from "./benchmark"
import type { PerformanceUniverse } from "./performance"

export function context(): PriceContext {
  return {
    scoringContextId: "exact-scoring",
    formatContextKey: "exact-format",
    environmentKey: "exact-environment",
    quality: "exact",
    season: 2026,
    seasonType: "regular",
    playerPool: "all_players",
    position: "RB",
    positionGroupVersion: "primary-at-time/v1",
    teamCount: 12,
    priceKind: "pick",
    auctionBudget: null,
  }
}
export function purchase(): DraftPurchase {
  return {
    pickId: "pick-34",
    draftId: "my-draft",
    playerId: "rb-14",
    acquiredAt: "2026-09-01T12:00:00Z",
    isKeeper: false,
    price: 34,
    context: context(),
  }
}
export function market(): PositionalMarketSnapshot {
  return {
    id: "market-snapshot",
    source: "portfolio",
    sourceRevision: "immutable-source-revision",
    availableAt: "2026-09-01T11:00:00Z",
    windowStartsAt: "2026-08-01T00:00:00Z",
    windowEndsAt: "2026-09-01T10:00:00Z",
    context: context(),
    keeperPolicy: "excluded",
    subjectDraftExcluded: true,
    constituentDraftIds: ["other-a", "other-b", "other-c"],
    sampleSize: 3,
    minimumDrafts: 3,
    minimumObservations: 3,
    samplePolicyVersion: "fixture-only/v1",
    players: Array.from({ length: 14 }, (_, index) => ({
      playerId: `rb-${index + 1}`,
      price: index < 9 ? index + 1 : 30 + (index - 9) * 4,
      observations: 3,
    })),
  }
}
export function performance(): PerformanceUniverse {
  return {
    id: "week-6-revision-a",
    scoringContextId: "exact-scoring",
    source: "test-fixture",
    sourceRevision: "a",
    sourceAsOf: "2026-10-20T12:00:00Z",
    scoringEngineVersion: "fixture-only/v1",
    positionGroupVersion: "primary-at-time/v1",
    season: 2026,
    seasonType: "regular",
    throughWeek: 6,
    isFinal: false,
    completeUniverse: true,
    unscoredRuleKeys: [],
    players: Array.from({ length: 18 }, (_, index) => ({
      playerId: index === 6 ? "rb-14" : `outcome-${index}`,
      position: "RB",
      points: 200 - index * 5,
      gamesPlayed: 6,
    })),
  }
}
