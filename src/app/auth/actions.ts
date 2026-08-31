"use server"

import { revalidatePath } from "next/cache"
import { redirect } from "next/navigation"

import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { getSafeInternalNextPath } from "@/lib/auth/redirects"
import type { AuthActionState } from "@/lib/auth/types"
import {
  validateEmailRequest,
  validatePasswordUpdate,
  validateSignIn,
  validateSignUp,
} from "@/lib/auth/validation"
import { buildAuthRedirectUrl } from "@/lib/site-url"
import { createServerSupabaseClient } from "@/lib/supabase/server"

export async function signInAction(
  _previousState: AuthActionState,
  formData: FormData
): Promise<AuthActionState> {
  const validation = validateSignIn(formData)
  if (!validation.success) {
    return validation.state
  }

  const supabase = await createServerSupabaseClient()
  const { error } = await supabase.auth.signInWithPassword(validation.data)
  if (error) {
    return {
      status: "error",
      message: "Email or password was not accepted.",
    }
  }

  const next = getSafeInternalNextPath(
    typeof formData.get("next") === "string"
      ? (formData.get("next") as string)
      : null
  )
  redirect(next)
}

export async function signUpAction(
  _previousState: AuthActionState,
  formData: FormData
): Promise<AuthActionState> {
  const validation = validateSignUp(formData)
  if (!validation.success) {
    return validation.state
  }

  const supabase = await createServerSupabaseClient()
  const { data, error } = await supabase.auth.signUp({
    email: validation.data.email,
    password: validation.data.password,
    options: {
      data: { display_name: validation.data.displayName },
      emailRedirectTo: buildAuthRedirectUrl("/auth/confirm"),
    },
  })

  if (error) {
    return {
      status: "error",
      message:
        "Your account could not be created. Check the form and try again.",
    }
  }

  if (data.session) {
    redirect("/onboarding")
  }

  redirect("/auth/check-email")
}

export async function forgotPasswordAction(
  _previousState: AuthActionState,
  formData: FormData
): Promise<AuthActionState> {
  const validation = validateEmailRequest(formData)
  if (!validation.success) {
    return validation.state
  }

  const supabase = await createServerSupabaseClient()
  const { error } = await supabase.auth.resetPasswordForEmail(
    validation.data.email,
    {
      redirectTo: buildAuthRedirectUrl(
        "/auth/confirm?next=/auth/update-password"
      ),
    }
  )

  if (error) {
    return {
      status: "error",
      message: "Reset instructions could not be requested. Try again shortly.",
    }
  }

  return {
    status: "success",
    message:
      "If an account matches that address, password reset instructions will arrive by email.",
  }
}

export async function updatePasswordAction(
  _previousState: AuthActionState,
  formData: FormData
): Promise<AuthActionState> {
  const validation = validatePasswordUpdate(formData)
  if (!validation.success) {
    return validation.state
  }

  const identity = await getCurrentAuthIdentity()
  if (!identity) {
    return {
      status: "error",
      message:
        "Open a current password recovery link before updating your password.",
    }
  }

  const supabase = await createServerSupabaseClient()
  const { error } = await supabase.auth.updateUser({
    password: validation.data.password,
  })
  if (error) {
    return {
      status: "error",
      message:
        "Your password could not be updated. Request a new recovery link.",
    }
  }

  await supabase.auth.signOut({ scope: "global" })
  redirect("/auth/sign-in?message=password-updated")
}

export async function signOutAction() {
  const supabase = await createServerSupabaseClient()
  const { data } = await supabase.auth.getClaims()

  if (data?.claims.sub) {
    await supabase.auth.signOut()
  }

  revalidatePath("/", "layout")
  redirect("/auth/sign-in")
}
