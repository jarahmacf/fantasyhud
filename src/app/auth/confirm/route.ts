import type { EmailOtpType } from "@supabase/supabase-js"
import { type NextRequest, NextResponse } from "next/server"

import { getSafeInternalNextPath } from "@/lib/auth/redirects"
import { createServerSupabaseClient } from "@/lib/supabase/server"

const acceptedEmailOtpTypes = new Set<EmailOtpType>([
  "email",
  "signup",
  "recovery",
  "invite",
  "magiclink",
  "email_change",
  "reauthentication",
])

export async function GET(request: NextRequest) {
  const tokenHash = request.nextUrl.searchParams.get("token_hash")
  const typeValue = request.nextUrl.searchParams.get("type")
  const code = request.nextUrl.searchParams.get("code")
  const defaultNext =
    typeValue === "recovery" ? "/auth/update-password" : "/onboarding"
  const next = getSafeInternalNextPath(
    request.nextUrl.searchParams.get("next"),
    defaultNext
  )
  const supabase = await createServerSupabaseClient()

  let verified = false
  if (
    tokenHash &&
    typeValue &&
    acceptedEmailOtpTypes.has(typeValue as EmailOtpType)
  ) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: typeValue as EmailOtpType,
    })
    verified = !error
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    verified = !error
  }

  return NextResponse.redirect(
    new URL(verified ? next : "/auth/error", request.nextUrl.origin)
  )
}
