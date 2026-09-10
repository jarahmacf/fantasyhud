import type { AdpField, ResearchContext } from "./model"
export type Acquisition = {
  key: string
  playerToken: string
  name: string
  position: string
  team: string | null
  leagueToken: string
  league: string
  draftType: string
  paid: number | null
  budget: number | null
  teams: number | null
  equivalentAdp: number | null
  adpBound?: { value: number; direction: "at_most" | "at_least" }
  rankBound?: { value: number; direction: "at_most" | "at_least" }
  marketAdp: number | null
  adpField: AdpField
  adpGain: number | null
  impliedRank: number | null
  actualRank: number | null
  liveRank: number | null
  rankGain: number | null
  points: number | null
  livePoints: number | null
  games: number
  pointsAbovePrice: number | null
  peerDrafts: number
  matchedPlayers: number
  adjustedTeams: boolean
  reason: string | null
}
export type ResearchPlayer = {
  token: string
  name: string
  position: string
  team: string | null
  injury: string | null
  adp: number | null
  held: number
  drafted: number
  updatedAt: string | null
}
export type ResearchData = {
  season: number
  week: number
  completedWeek: number
  fetchedAt: string
  marketFetchedAt: string | null
  marketUrl: string
  statsFetchedAt: string | null
  membershipCount: number
  completedDrafts: number
  snakeDrafts: number
  auctionDrafts: number
  unresolvedDrafts: number
  contexts: ResearchContext[]
  players: ResearchPlayer[]
  acquisitions: Acquisition[]
  issues: string[]
}
export type PlayerProfile = {
  player: ResearchPlayer
  context: ResearchContext
  contexts: ResearchContext[]
  acquisitions: Acquisition[]
  adpField: AdpField
  marketAdp: number | null
  marketRank: number | null
  livePoints: number | null
  points: number | null
  ppg: number | null
  games: number
  actualRank: number | null
  liveRank: number | null
  eligiblePlayers: number
  weekly: {
    week: number
    opponent: string | null
    points: number | null
    cumulative: number | null
    rank: number | null
    provisional: boolean
    status: string
    stats: Record<string, number> | null
  }[]
  season: number
  completedWeek: number
  week: number
  marketFetchedAt: string | null
  statsFetchedAt: string | null
  issues: string[]
}
