import "server-only"
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchNormalizedSleeperDraftCollection } from "@/lib/sleeper/draft-collection.server"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import { createServerSupabaseClient } from "@/lib/supabase/server"
import type { Json } from "@/lib/supabase/database.types"

type DraftImportResult =
  | { status: "running"; message: string }
  | {
      status: "success" | "partial"
      message: string
      drafts: number
      confirmedParticipations: number
    }
  | { status: "error"; message: string }
function record(value: Json | undefined): Record<string, Json | undefined> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Invalid draft import result.")
  return value
}
/** App identity and primary account are resolved on the server; caller supplies no account IDs. */
export async function importPrimaryAccountDrafts(): Promise<DraftImportResult> {
  const identity = await requireAuthIdentity("/draft-value")
  const userClient = await createServerSupabaseClient()
  const result = await userClient
    .from("user_fantasy_accounts")
    .select("fantasy_accounts!inner(id, provider)")
    .eq("user_id", identity.id)
    .eq("is_primary", true)
    .maybeSingle()
  const account = result.data?.fantasy_accounts
  if (result.error || !account || account.provider !== "sleeper")
    return {
      status: "error",
      message: "Connect a Sleeper account before importing drafts.",
    }
  const admin = createAdminSupabaseClient()
  let runId: string | null = null
  try {
    const start = await admin.rpc("start_sleeper_draft_sync", {
      p_user_id: identity.id,
      p_fantasy_account_id: account.id,
    })
    if (start.error) throw new Error("Draft import could not start.")
    const started = record(start.data)
    if (started.reused === true)
      return { status: "running", message: "Draft import is already running." }
    if (
      typeof started.runId !== "string" ||
      typeof started.externalUserId !== "string" ||
      typeof started.season !== "number" ||
      !Array.isArray(started.externalLeagueIds) ||
      !started.externalLeagueIds.every((x) => typeof x === "string")
    )
      throw new Error("Invalid frozen draft scope.")
    runId = started.runId
    const actor = {
      p_user_id: identity.id,
      p_fantasy_account_id: account.id,
      p_sync_run_id: runId,
    }
    const collection = await fetchNormalizedSleeperDraftCollection(
      {
        externalUserId: started.externalUserId,
        season: started.season,
        externalLeagueIds: started.externalLeagueIds as string[],
      },
      {
        heartbeat: async () => {
          const result = await admin.rpc("heartbeat_sleeper_draft_sync", actor)
          if (result.error) throw new Error("Draft import is no longer active.")
        },
      }
    )
    const { drafts, ...header } = collection
    const stage = async (key: string, payload: unknown) => {
      const result = await admin.rpc("stage_sleeper_draft_source", {
        ...actor,
        p_source_key: key,
        p_payload: payload as Json,
      })
      if (result.error) throw new Error("Draft source could not be staged.")
    }
    await stage("collections", header)
    for (const draft of drafts)
      await stage(`draft:${draft.detail.externalDraftId}`, draft)
    const completion = await admin.rpc("complete_sleeper_draft_sync", actor)
    if (completion.error) throw new Error("Draft publication failed.")
    const counts = record(completion.data)
    for (const key of [
      "drafts",
      "confirmedParticipations",
      "unresolvedParticipations",
      "mutableBoards",
    ])
      if (
        typeof counts[key] !== "number" ||
        !Number.isSafeInteger(counts[key]) ||
        counts[key] < 0
      )
        throw new Error("Invalid draft result counts.")
    const partial =
      (counts.unresolvedParticipations as number) > 0 ||
      (counts.mutableBoards as number) > 0
    return {
      status: partial ? "partial" : "success",
      message: partial
        ? "Drafts imported; some boards or participation remain unresolved."
        : "Draft import complete.",
      drafts: counts.drafts as number,
      confirmedParticipations: counts.confirmedParticipations as number,
    }
  } catch {
    if (runId)
      await admin.rpc("fail_sleeper_draft_sync", {
        p_user_id: identity.id,
        p_fantasy_account_id: account.id,
        p_sync_run_id: runId,
      })
    return {
      status: "error",
      message:
        "Draft import could not be completed. Previous imports are preserved.",
    }
  }
}
