import "server-only"

import { createServerSupabaseClient } from "@/lib/supabase/server"

type ServerSupabaseClient = Awaited<
  ReturnType<typeof createServerSupabaseClient>
>

export type PlayerCatalogRunStatus =
  "not_imported" | "running" | "succeeded" | "failed" | "partial"

export type PlayerCatalogPreviewRow = {
  id: string
  sleeperExternalId: string
  displayName: string | null
  primaryPosition: string | null
  fantasyPositions: string[]
  nflTeam: string | null
  active: boolean | null
  status: string | null
  injuryStatus: string | null
  injuryBodyPart: string | null
}

export type PlayerCatalogDashboard = {
  latestStatus: PlayerCatalogRunStatus
  lastRefreshedAt: string | null
  canonicalEntities: number
  activePlayers: number
  teamDefenses: number
  externalIdMappings: number
  preview: PlayerCatalogPreviewRow[]
}

export class PlayerCatalogQueryError extends Error {}

export async function loadPlayerCatalogDashboard(
  supabase: ServerSupabaseClient
): Promise<PlayerCatalogDashboard> {
  const [
    latestResult,
    successResult,
    entityCount,
    activeCount,
    defenseCount,
    mappingCount,
    previewResult,
  ] = await Promise.all([
    supabase
      .from("provider_catalog_runs")
      .select("status")
      .eq("provider", "sleeper")
      .eq("sport", "nfl")
      .eq("catalog", "players")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("provider_catalog_runs")
      .select("source_fetched_at")
      .eq("provider", "sleeper")
      .eq("sport", "nfl")
      .eq("catalog", "players")
      .eq("status", "succeeded")
      .order("source_fetched_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase.from("players").select("id", { count: "exact", head: true }),
    supabase
      .from("players")
      .select("id, player_external_ids!inner(id)", {
        count: "exact",
        head: true,
      })
      .eq("entity_type", "player")
      .eq("active", true)
      .eq("player_external_ids.namespace", "sleeper")
      .eq("player_external_ids.sport", "nfl")
      .eq("player_external_ids.is_primary", true)
      .is("player_external_ids.removed_at", null),
    supabase
      .from("players")
      .select("id, player_external_ids!inner(id)", {
        count: "exact",
        head: true,
      })
      .eq("entity_type", "team_defense")
      .eq("player_external_ids.namespace", "sleeper")
      .eq("player_external_ids.sport", "nfl")
      .eq("player_external_ids.is_primary", true)
      .is("player_external_ids.removed_at", null),
    supabase
      .from("player_external_ids")
      .select("id", { count: "exact", head: true })
      .is("removed_at", null),
    supabase
      .from("players")
      .select(
        "id, display_name, primary_position, fantasy_positions, nfl_team, active, status, injury_status, injury_body_part, player_external_ids!inner(external_id)"
      )
      .eq("active", true)
      .eq("player_external_ids.namespace", "sleeper")
      .eq("player_external_ids.sport", "nfl")
      .eq("player_external_ids.is_primary", true)
      .is("player_external_ids.removed_at", null)
      .order("display_name", { ascending: true, nullsFirst: false })
      .order("external_id", {
        ascending: true,
        referencedTable: "player_external_ids",
      })
      .limit(50),
  ])

  const results = [
    latestResult,
    successResult,
    entityCount,
    activeCount,
    defenseCount,
    mappingCount,
    previewResult,
  ]
  if (results.some((result) => result.error)) {
    throw new PlayerCatalogQueryError()
  }

  const status = latestResult.data?.status
  if (
    status !== undefined &&
    status !== "running" &&
    status !== "succeeded" &&
    status !== "failed" &&
    status !== "partial"
  ) {
    throw new PlayerCatalogQueryError()
  }

  const preview = (previewResult.data ?? [])
    .map((player) => ({
      id: player.id,
      sleeperExternalId: player.player_external_ids[0]?.external_id ?? "",
      displayName: player.display_name,
      primaryPosition: player.primary_position,
      fantasyPositions: player.fantasy_positions,
      nflTeam: player.nfl_team,
      active: player.active,
      status: player.status,
      injuryStatus: player.injury_status,
      injuryBodyPart: player.injury_body_part,
    }))
    .filter((player) => player.sleeperExternalId)
    .sort((left, right) => {
      const leftName = left.displayName ?? "\uffff"
      const rightName = right.displayName ?? "\uffff"
      const nameOrder = leftName.localeCompare(rightName)
      return (
        nameOrder ||
        left.sleeperExternalId.localeCompare(right.sleeperExternalId)
      )
    })
    .slice(0, 50)

  return {
    latestStatus: status ?? "not_imported",
    lastRefreshedAt: successResult.data?.source_fetched_at ?? null,
    canonicalEntities: entityCount.count ?? 0,
    activePlayers: activeCount.count ?? 0,
    teamDefenses: defenseCount.count ?? 0,
    externalIdMappings: mappingCount.count ?? 0,
    preview,
  }
}
