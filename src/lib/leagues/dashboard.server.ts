import "server-only"

import {
  loadCurrentSeasonLeagueDashboard,
  type LeagueDashboardReader,
} from "@/lib/leagues/dashboard-data"
import { createServerSupabaseClient } from "@/lib/supabase/server"

type ServerSupabaseClient = Awaited<
  ReturnType<typeof createServerSupabaseClient>
>

class LeagueDashboardQueryError extends Error {}

export async function loadLeagueDashboardData(
  supabase: ServerSupabaseClient,
  fantasyAccountId: string
) {
  const reader: LeagueDashboardReader = {
    async getCurrentLeagueSeason() {
      const result = await supabase
        .from("provider_season_states")
        .select("league_season")
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .maybeSingle()

      if (result.error) throw new LeagueDashboardQueryError()
      return result.data?.league_season ?? null
    },
    async getLatestAttempt(accountId) {
      const result = await supabase
        .from("sync_runs")
        .select("season, status")
        .eq("fantasy_account_id", accountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "league_discovery")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle()

      if (result.error) throw new LeagueDashboardQueryError()
      return result.data
    },
    async getCurrentSeasonLeagues(accountId, season) {
      const result = await supabase
        .from("fantasy_account_leagues")
        .select(
          "league_id, leagues!inner(id, provider, sport, season, name, status, team_count, roster_management_type, is_best_ball, scoring_format, has_superflex)"
        )
        .eq("fantasy_account_id", accountId)
        .is("removed_at", null)
        .eq("leagues.provider", "sleeper")
        .eq("leagues.sport", "nfl")
        .eq("leagues.season", season)

      if (result.error) throw new LeagueDashboardQueryError()
      return result.data.map(({ leagues: league }) => ({
        id: league.id,
        name: league.name,
        status: league.status,
        teamCount: league.team_count,
        rosterManagementType: league.roster_management_type,
        isBestBall: league.is_best_ball,
        scoringFormat: league.scoring_format,
        hasSuperflex: league.has_superflex,
      }))
    },
    async hasCurrentSeasonSuccess(accountId, season) {
      const result = await supabase
        .from("sync_runs")
        .select("id")
        .eq("fantasy_account_id", accountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "league_discovery")
        .eq("season", season)
        .eq("status", "succeeded")
        .limit(1)
        .maybeSingle()

      if (result.error) throw new LeagueDashboardQueryError()
      return result.data !== null
    },
    async hasCurrentSeasonRosterImport(accountId, season) {
      const result = await supabase
        .from("sync_runs")
        .select("id")
        .eq("fantasy_account_id", accountId)
        .eq("provider", "sleeper")
        .eq("sport", "nfl")
        .eq("scope", "roster_sync")
        .eq("season", season)
        .in("status", ["succeeded", "partial"])
        .limit(1)
        .maybeSingle()

      if (result.error) throw new LeagueDashboardQueryError()
      return result.data !== null
    },
  }

  return loadCurrentSeasonLeagueDashboard(reader, fantasyAccountId)
}
