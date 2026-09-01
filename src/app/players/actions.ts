"use server"

import { revalidatePath } from "next/cache"

import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchSleeperPlayerCatalog } from "@/lib/sleeper/player-catalog.server"
import type {
  NormalizedSleeperPlayerRecord,
  PlayerCatalogActionState,
} from "@/lib/sleeper/player-types"
import { SleeperClientError } from "@/lib/sleeper/types"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import type { Json } from "@/lib/supabase/database.types"
import { createServerSupabaseClient } from "@/lib/supabase/server"

class PlayerCatalogCompletionError extends Error {}

function toRpcRecord(record: NormalizedSleeperPlayerRecord): Json {
  const profile = record.profile
  return {
    external_player_id: record.sleeperPlayerId,
    profile: {
      sport: profile.sport,
      entity_type: profile.entityType,
      display_name: profile.displayName,
      first_name: profile.firstName,
      last_name: profile.lastName,
      full_name: profile.fullName,
      primary_position: profile.primaryPosition,
      fantasy_positions: profile.fantasyPositions,
      nfl_team: profile.nflTeam,
      active: profile.active,
      status: profile.status,
      jersey_number: profile.jerseyNumber,
      age: profile.age,
      height: profile.height,
      weight: profile.weight,
      years_experience: profile.yearsExperience,
      college: profile.college,
      high_school: profile.highSchool,
      birth_country: profile.birthCountry,
      depth_chart_position: profile.depthChartPosition,
      depth_chart_order: profile.depthChartOrder,
      injury_status: profile.injuryStatus,
      injury_body_part: profile.injuryBodyPart,
      injury_start_date: profile.injuryStartDate,
      practice_participation: profile.practiceParticipation,
      news_updated_at: profile.newsUpdatedAt,
      search_rank: profile.searchRank,
      profile_source: profile.profileSource,
      source_metadata: profile.sourceMetadata as Json,
      profile_fetched_at: profile.profileFetchedAt,
    },
    external_ids: record.externalIds.map((externalId) => ({
      namespace: externalId.namespace,
      external_id: externalId.externalId,
      reported_by: externalId.reportedBy,
      source_field: externalId.sourceField,
    })),
    normalization_warning_count: record.normalizationWarningCount,
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
        message: "Sleeper returned an unexpected player catalog. Try again.",
        retryable: true,
      }
    }
    return {
      code: "source_unavailable",
      message: "Sleeper is temporarily unavailable. Try again.",
      retryable: true,
    }
  }

  if (error instanceof PlayerCatalogCompletionError) {
    return {
      code: "completion_failed",
      message: "Player catalog refresh could not be completed. Try again.",
      retryable: true,
    }
  }

  return {
    code: "player_catalog_failed",
    message: "Player catalog refresh could not be completed. Try again.",
    retryable: true,
  }
}

export async function refreshSleeperPlayerCatalogAction(
  _previousState: PlayerCatalogActionState,
  _formData: FormData
): Promise<PlayerCatalogActionState> {
  void _previousState
  void _formData
  const identity = await requireAuthIdentity("/players")
  const supabase = await createServerSupabaseClient()
  const accountResult = await supabase
    .from("user_fantasy_accounts")
    .select("fantasy_accounts!inner(provider)")
    .eq("user_id", identity.id)
    .eq("fantasy_accounts.provider", "sleeper")
    .limit(1)
    .maybeSingle()

  if (accountResult.error || !accountResult.data) {
    return {
      status: "error",
      message: "Connect a Sleeper account before importing players.",
    }
  }

  const admin = createAdminSupabaseClient()
  const startResult = await admin.rpc("start_sleeper_player_catalog_sync", {
    p_user_id: identity.id,
  })
  const started = startResult.data?.[0]

  if (startResult.error || !started) {
    return {
      status: "error",
      message: "Player catalog refresh could not be completed. Try again.",
    }
  }

  if (started.catalog_fresh) {
    revalidatePath("/players")
    return { status: "success", message: "Player catalog is current." }
  }

  if (started.reused_run && !started.created_run) {
    revalidatePath("/players")
    return {
      status: "running",
      message: "Player catalog refresh is already running.",
    }
  }

  try {
    const source = await fetchSleeperPlayerCatalog()
    const records = [...source.records].sort((left, right) =>
      left.sleeperPlayerId < right.sleeperPlayerId
        ? -1
        : left.sleeperPlayerId > right.sleeperPlayerId
          ? 1
          : 0
    )

    for (let offset = 0; offset < records.length; offset += 500) {
      const batch = records.slice(offset, offset + 500).map(toRpcRecord)
      const staged = await admin.rpc("stage_sleeper_player_catalog_batch", {
        p_user_id: identity.id,
        p_catalog_run_id: started.catalog_run_id,
        p_batch_index: Math.floor(offset / 500),
        p_expected_total: source.sourceRecordCount,
        p_source_fetched_at: source.sourceFetchedAt,
        p_source_bytes: source.sourceBytes,
        p_records: batch,
      })
      if (staged.error || !staged.data?.[0]) {
        throw new PlayerCatalogCompletionError()
      }
    }

    const completion = await admin.rpc("complete_sleeper_player_catalog_sync", {
      p_user_id: identity.id,
      p_catalog_run_id: started.catalog_run_id,
    })
    const completed = completion.data?.[0]
    if (completion.error || !completed) {
      throw new PlayerCatalogCompletionError()
    }

    revalidatePath("/players")
    return {
      status: "success",
      message: "Player catalog refreshed.",
      observedRecords: completed.observed_records,
    }
  } catch (error) {
    const failure = safeFailure(error)
    await admin.rpc("fail_sleeper_player_catalog_sync", {
      p_user_id: identity.id,
      p_catalog_run_id: started.catalog_run_id,
      p_error_code: failure.code,
      p_error_message: failure.message,
      p_retryable: failure.retryable,
    })
    revalidatePath("/players")
    return { status: "error", message: failure.message }
  }
}
