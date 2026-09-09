import "server-only"
import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "@/lib/supabase/database.types"

export async function getDraftImportSummary(
  client: SupabaseClient<Database>,
  accountId: string
) {
  const season = await client
    .from("provider_season_states")
    .select("league_season")
    .eq("provider", "sleeper")
    .eq("sport", "nfl")
    .maybeSingle()
  if (season.error) return { status: "unavailable" as const }
  if (!season.data) return { status: "not_imported" as const }
  const result = await client
    .from("sync_runs")
    .select("status, result_counts, finished_at")
    .eq("fantasy_account_id", accountId)
    .eq("scope", "draft_sync")
    .eq("season", season.data.league_season)
    .in("status", ["succeeded", "partial"])
    .order("finished_at", { ascending: false })
    .limit(1)
    .maybeSingle()
  if (result.error) return { status: "unavailable" as const }
  if (!result.data) return { status: "not_imported" as const }
  const counts = result.data.result_counts
  if (!counts || typeof counts !== "object" || Array.isArray(counts))
    return { status: "unavailable" as const }
  const drafts = counts.drafts,
    finalized = counts.finalized_boards
  if (
    typeof drafts !== "number" ||
    !Number.isSafeInteger(drafts) ||
    drafts < 0 ||
    typeof finalized !== "number" ||
    !Number.isSafeInteger(finalized) ||
    finalized < 0 ||
    finalized > drafts
  )
    return { status: "unavailable" as const }
  return {
    status: "imported" as const,
    drafts,
    finalized,
    partial: result.data.status === "partial",
    finishedAt: result.data.finished_at,
  }
}
