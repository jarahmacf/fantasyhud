"use server"

import { revalidatePath } from "next/cache"

import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchNormalizedSleeperRosterBundles } from "@/lib/sleeper/roster-collection.server"
import type {
  NormalizedRosterLeagueBundle,
  RosterImportActionState,
} from "@/lib/sleeper/roster-types"
import { SleeperClientError } from "@/lib/sleeper/types"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import type { Json } from "@/lib/supabase/database.types"
import { createServerSupabaseClient } from "@/lib/supabase/server"

class RosterImportCompletionError extends Error {}

function revalidateRosterSurfaces(): void {
  revalidatePath("/")
  revalidatePath("/rosters")
}

function toRpcBundle(bundle: NormalizedRosterLeagueBundle): Json {
  return {
    external_league_id: bundle.externalLeagueId,
    league_season: bundle.leagueSeason,
    bundle_fetched_at: bundle.bundleFetchedAt,
    users: bundle.users.map((user) => ({
      external_user_id: user.externalUserId,
      username: user.username,
      display_name: user.displayName,
      team_name: user.teamName,
      avatar_id: user.avatarId,
      avatar_url: user.avatarUrl,
      is_commissioner: user.isCommissioner,
      metadata: user.metadata as Json,
    })),
    rosters: bundle.rosters.map((roster) => ({
      external_roster_id: roster.externalRosterId,
      owner_external_user_id: roster.ownerExternalUserId,
      co_owner_external_user_ids: roster.coOwnerExternalUserIds,
      source_player_ids: roster.sourcePlayerIds,
      source_starter_ids: roster.sourceStarterIds,
      source_reserve_ids: roster.sourceReserveIds,
      source_taxi_ids: roster.sourceTaxiIds,
      source_keeper_ids: roster.sourceKeeperIds,
      settings: roster.settings as Json,
      metadata: roster.metadata as Json,
      memberships:
        roster.memberships?.map((membership) => ({
          external_player_id: membership.externalPlayerId,
          source_order: membership.sourceOrder,
          is_starter: membership.isStarter,
          starter_order: membership.starterOrder,
          starter_slot: membership.starterSlot,
          is_reserve: membership.isReserve,
          is_taxi: membership.isTaxi,
          is_keeper: membership.isKeeper,
          source_metadata: membership.sourceMetadata as Json,
        })) ?? null,
    })),
    source_metadata: bundle.sourceMetadata as Json,
  }
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
        message: "Sleeper returned an unexpected roster response. Try again.",
        retryable: true,
      }
    }
    return {
      code: "source_unavailable",
      message: "Sleeper is temporarily unavailable. Try again.",
      retryable: true,
    }
  }

  return {
    code:
      error instanceof RosterImportCompletionError
        ? "completion_failed"
        : "roster_import_failed",
    message: "Roster import could not be completed. Try again.",
    retryable: true,
  }
}

function parseRosterPositions(value: Json): string[] | null {
  if (
    !Array.isArray(value) ||
    value.length > 1_000 ||
    value.some(
      (position) =>
        typeof position !== "string" || !/^[A-Z0-9_]{1,64}$/u.test(position)
    )
  ) {
    return null
  }
  return value as string[]
}

export async function importCurrentSleeperRostersAction(
  _previousState: RosterImportActionState,
  _formData: FormData
): Promise<RosterImportActionState> {
  void _previousState
  void _formData

  const identity = await requireAuthIdentity("/rosters")
  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select(
      "fantasy_account_id, fantasy_accounts!inner(id, provider, external_user_id)"
    )
    .eq("user_id", identity.id)
    .eq("is_primary", true)
    .maybeSingle()

  if (accountResult.error) {
    return {
      status: "error",
      message: "Roster import could not be completed. Try again.",
    }
  }
  const account = accountResult.data?.fantasy_accounts
  if (!account || account.provider !== "sleeper") {
    return {
      status: "error",
      message: "Connect a Sleeper account before importing rosters.",
    }
  }

  const seasonResult = await supabase
    .from("provider_season_states")
    .select("league_season")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .maybeSingle()
  if (seasonResult.error) {
    return {
      status: "error",
      message: "Roster import could not be completed. Try again.",
    }
  }
  if (!seasonResult.data) {
    return {
      status: "error",
      message: "Import current-season leagues first.",
    }
  }

  const associationResult = await supabase
    .from("fantasy_account_leagues")
    .select(
      "league_id, leagues!inner(external_league_id, provider, sport, season)"
    )
    .eq("fantasy_account_id", account.id)
    .is("removed_at", null)
    .eq("leagues.provider", "sleeper")
    .eq("leagues.sport", "nfl")
    .eq("leagues.season", seasonResult.data.league_season)
    .limit(1)
  if (associationResult.error) {
    return {
      status: "error",
      message: "Roster import could not be completed. Try again.",
    }
  }
  if (!associationResult.data.length) {
    return {
      status: "error",
      message: "Import current-season leagues first.",
    }
  }

  const catalogResult = await supabase
    .from("provider_catalog_runs")
    .select("id")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .eq("catalog", "players")
    .eq("status", "succeeded")
    .limit(1)
    .maybeSingle()
  if (catalogResult.error) {
    return {
      status: "error",
      message: "Roster import could not be completed. Try again.",
    }
  }
  if (!catalogResult.data) {
    return {
      status: "error",
      message: "Import the player catalog first.",
    }
  }

  const admin = createAdminSupabaseClient()
  const startResult = await admin.rpc("start_sleeper_roster_sync", {
    p_user_id: identity.id,
    p_fantasy_account_id: account.id,
  })
  const started = startResult.data?.[0]
  if (startResult.error || !started) {
    return {
      status: "error",
      message: "Roster import could not be completed. Try again.",
    }
  }

  if (started.reused_run && !started.created_run) {
    revalidateRosterSurfaces()
    return {
      status: "running",
      message: "Roster import is already running.",
    }
  }

  try {
    const frozenLeagueResult = await supabase
      .from("fantasy_account_leagues")
      .select(
        "league_id, leagues!inner(external_league_id, roster_positions, provider, sport, season)"
      )
      .eq("fantasy_account_id", account.id)
      .is("removed_at", null)
      .eq("leagues.provider", "sleeper")
      .eq("leagues.sport", "nfl")
      .eq("leagues.season", started.league_season)
      .in("leagues.external_league_id", started.expected_external_league_ids)

    if (frozenLeagueResult.error) throw new RosterImportCompletionError()

    const leaguePositions = new Map<string, string[]>()
    for (const association of frozenLeagueResult.data) {
      const positions = parseRosterPositions(
        association.leagues.roster_positions
      )
      if (!positions) throw new RosterImportCompletionError()
      leaguePositions.set(association.leagues.external_league_id, positions)
    }

    const frozenLeagues = started.expected_external_league_ids.map(
      (externalLeagueId) => {
        const rosterPositions = leaguePositions.get(externalLeagueId)
        if (!rosterPositions) throw new RosterImportCompletionError()
        return { externalLeagueId, rosterPositions }
      }
    )

    if (
      frozenLeagues.length !== leaguePositions.size ||
      new Set(started.expected_external_league_ids).size !==
        started.expected_external_league_ids.length
    ) {
      throw new RosterImportCompletionError()
    }

    const bundles = [
      ...(await fetchNormalizedSleeperRosterBundles(
        frozenLeagues,
        started.league_season
      )),
    ].sort((left, right) =>
      left.externalLeagueId < right.externalLeagueId
        ? -1
        : left.externalLeagueId > right.externalLeagueId
          ? 1
          : 0
    )

    for (const bundle of bundles) {
      const stageResult = await admin.rpc(
        "stage_sleeper_roster_league_bundle",
        {
          p_user_id: identity.id,
          p_fantasy_account_id: account.id,
          p_sync_run_id: started.sync_run_id,
          p_external_league_id: bundle.externalLeagueId,
          p_bundle: toRpcBundle(bundle),
        }
      )
      if (stageResult.error || !stageResult.data?.[0]) {
        throw new RosterImportCompletionError()
      }
    }

    const completionResult = await admin.rpc("complete_sleeper_roster_sync", {
      p_user_id: identity.id,
      p_fantasy_account_id: account.id,
      p_sync_run_id: started.sync_run_id,
    })
    const completed = completionResult.data?.[0]
    if (
      completionResult.error ||
      !completed ||
      (completed.final_status !== "succeeded" &&
        completed.final_status !== "partial")
    ) {
      throw new RosterImportCompletionError()
    }

    revalidateRosterSurfaces()
    if (completed.final_status === "partial") {
      return {
        status: "partial",
        message:
          "Roster data imported, but some league ownership could not be resolved.",
        unresolvedOwnershipLeagues: completed.unresolved_ownership_leagues,
        activeOwnedRosters: completed.active_owned_rosters,
        activeOwnedMemberships: completed.active_owned_memberships,
      }
    }
    return {
      status: "success",
      message: "Roster import complete.",
      activeOwnedRosters: completed.active_owned_rosters,
      activeOwnedMemberships: completed.active_owned_memberships,
    }
  } catch (error) {
    const failure = safeFailure(error)
    await admin.rpc("fail_sleeper_roster_sync", {
      p_user_id: identity.id,
      p_fantasy_account_id: account.id,
      p_sync_run_id: started.sync_run_id,
      p_error_code: failure.code,
      p_error_message: failure.message,
      p_retryable: failure.retryable,
    })
    revalidateRosterSurfaces()
    return { status: "error", message: failure.message }
  }
}
