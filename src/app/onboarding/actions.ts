"use server"

import { revalidatePath } from "next/cache"
import { redirect } from "next/navigation"

import { requireAuthIdentity } from "@/lib/auth/current-user"
import { resolveSleeperUser } from "@/lib/sleeper/client.server"
import {
  SleeperClientError,
  type SleeperConnectionActionState,
} from "@/lib/sleeper/types"
import {
  normalizeSleeperUsername,
  SleeperUsernameValidationError,
} from "@/lib/sleeper/username"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import { createServerSupabaseClient } from "@/lib/supabase/server"

function sleeperErrorState(error: unknown): SleeperConnectionActionState {
  if (error instanceof SleeperUsernameValidationError) {
    return {
      status: "error",
      message: "Enter a valid Sleeper username.",
      fieldErrors: { username: "Enter a valid Sleeper username." },
    }
  }

  if (error instanceof SleeperClientError) {
    if (error.kind === "not_found") {
      return { status: "error", message: "Sleeper account not found." }
    }
    if (error.kind === "invalid_response") {
      return {
        status: "error",
        message: "Sleeper returned an unexpected response. Try again.",
      }
    }
    return {
      status: "error",
      message: "Sleeper is temporarily unavailable. Try again.",
    }
  }

  return {
    status: "error",
    message: "The account could not be connected. Try again.",
  }
}

export async function connectSleeperAccountAction(
  _previousState: SleeperConnectionActionState,
  formData: FormData
): Promise<SleeperConnectionActionState> {
  const identity = await requireAuthIdentity("/onboarding")
  const supabase = await createServerSupabaseClient()
  const { data: existingLinks, error: existingLinksError } = await supabase
    .from("user_fantasy_accounts")
    .select("id")
    .limit(1)

  if (existingLinksError) {
    return {
      status: "error",
      message: "The account could not be connected. Try again.",
    }
  }

  if (existingLinks?.length) {
    redirect("/")
  }

  let submittedUsername: string
  try {
    submittedUsername = normalizeSleeperUsername(formData.get("username"))
  } catch (error) {
    return sleeperErrorState(error)
  }

  let resolved
  try {
    resolved = await resolveSleeperUser(submittedUsername)
  } catch (error) {
    return sleeperErrorState(error)
  }

  const admin = createAdminSupabaseClient()
  const { data, error } = await admin.rpc("connect_sleeper_account", {
    p_user_id: identity.id,
    p_external_user_id: resolved.userId,
    p_username: resolved.username,
    p_display_name: resolved.displayName ?? "",
    p_avatar_url: resolved.avatarUrl ?? "",
    p_provider_metadata: resolved.avatarId
      ? { avatar_id: resolved.avatarId }
      : {},
  })

  if (error || !data?.length) {
    return {
      status: "error",
      message: "The account could not be connected. Try again.",
    }
  }

  revalidatePath("/")
  revalidatePath("/onboarding")
  redirect("/")
}
