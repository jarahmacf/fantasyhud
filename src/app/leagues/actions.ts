"use server"

import { revalidatePath } from "next/cache"

import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchSleeperLeagues } from "@/lib/sleeper/leagues.server"
import { fetchNflState } from "@/lib/sleeper/nfl-state.server"
import {
  SleeperClientError,
  type LeagueDiscoveryActionState,
} from "@/lib/sleeper/types"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import type { Json } from "@/lib/supabase/database.types"
import { createServerSupabaseClient } from "@/lib/supabase/server"

class LeagueCompletionError extends Error {}

function toJson(value: unknown): Json {
  return JSON.parse(JSON.stringify(value)) as Json
}

function safeFailure(error: unknown): {
  code: string
  message: string
  retryable: boolean
} {
  if (error instanceof SleeperClientError) {
    if (error.kind === "invalid_response" || error.kind === "not_found") {
      return {
        code: "invalid_source_response",
        message: "Sleeper returned an unexpected league response. Try again.",
        retryable: true,
      }
    }

    return {
      code: "source_unavailable",
      message: "Sleeper is temporarily unavailable. Try again.",
      retryable: true,
    }
  }

  if (error instanceof LeagueCompletionError) {
    return {
      code: "completion_failed",
      message: "League discovery could not be completed. Try again.",
      retryable: true,
    }
  }

  return {
    code: "league_discovery_failed",
    message: "League discovery could not be completed. Try again.",
    retryable: true,
  }
}

export async function importCurrentSleeperLeaguesAction(
  _previousState: LeagueDiscoveryActionState,
  _formData: FormData
): Promise<LeagueDiscoveryActionState> {
  void _previousState
  void _formData
  const identity = await requireAuthIdentity("/")
  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select(
      "fantasy_account_id, is_primary, fantasy_accounts!inner(id, provider, external_user_id)"
    )
    .eq("user_id", identity.id)
    .eq("is_primary", true)
    .maybeSingle()

  if (accountResult.error) {
    return {
      status: "error",
      message: "League discovery could not be completed. Try again.",
    }
  }

  const link = accountResult.data
  if (!link || link.fantasy_accounts.provider !== "sleeper") {
    return {
      status: "error",
      message: "Connect a Sleeper account before importing leagues.",
    }
  }

  const account = link.fantasy_accounts
  const admin = createAdminSupabaseClient()
  const startResult = await admin.rpc("start_sleeper_league_discovery", {
    p_user_id: identity.id,
    p_fantasy_account_id: account.id,
  })
  const started = startResult.data?.[0]

  if (startResult.error || !started) {
    return {
      status: "error",
      message: "League discovery could not be completed. Try again.",
    }
  }

  if (started.reused_run && !started.created_run) {
    revalidatePath("/")
    return {
      status: "running",
      message: "League discovery is already running.",
    }
  }

  try {
    const state = await fetchNflState()
    const leagues = await fetchSleeperLeagues(
      account.external_user_id,
      state.leagueSeason
    )
    const completionResult = await admin.rpc(
      "complete_sleeper_league_discovery",
      {
        p_user_id: identity.id,
        p_fantasy_account_id: account.id,
        p_sync_run_id: started.sync_run_id,
        p_state: toJson({
          season: state.season,
          league_season: state.leagueSeason,
          league_create_season: state.leagueCreateSeason,
          previous_season: state.previousSeason,
          season_type: state.seasonType,
          week: state.week,
          leg: state.leg,
          display_week: state.displayWeek,
          season_start_date: state.seasonStartDate,
          provider_metadata: state.providerMetadata,
          fetched_at: state.fetchedAt,
        }),
        p_leagues: toJson(
          leagues.map((league) => ({
            external_league_id: league.externalLeagueId,
            sport: league.sport,
            season: league.season,
            name: league.name,
            status: league.status,
            season_type: league.seasonType,
            team_count: league.teamCount,
            roster_size: league.rosterSize,
            roster_management_type: league.rosterManagementType,
            is_best_ball: league.isBestBall,
            has_superflex: league.hasSuperflex,
            has_idp: league.hasIdp,
            scoring_format: league.scoringFormat,
            avatar_id: league.avatarId,
            avatar_url: league.avatarUrl,
            previous_external_league_id: league.previousExternalLeagueId,
            settings: league.settings,
            scoring_settings: league.scoringSettings,
            roster_positions: league.rosterPositions,
            provider_metadata: league.providerMetadata,
            provider_updated_at: league.providerUpdatedAt,
            fetched_at: league.fetchedAt,
          }))
        ),
      }
    )

    const completed = completionResult.data?.[0]
    if (completionResult.error || !completed) {
      throw new LeagueCompletionError()
    }

    revalidatePath("/")
    return {
      status: "success",
      message: "League discovery complete.",
      activeLeagues: completed.active_associations,
      leagueSeason: state.leagueSeason,
    }
  } catch (error) {
    const failure = safeFailure(error)
    await admin.rpc("fail_sleeper_league_discovery", {
      p_user_id: identity.id,
      p_fantasy_account_id: account.id,
      p_sync_run_id: started.sync_run_id,
      p_error_code: failure.code,
      p_error_message: failure.message,
      p_retryable: failure.retryable,
    })
    revalidatePath("/")
    return { status: "error", message: failure.message }
  }
}
