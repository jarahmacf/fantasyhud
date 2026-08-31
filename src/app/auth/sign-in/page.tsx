import { CircleCheck } from "lucide-react"

import { AuthShell } from "@/components/auth/auth-shell"
import { SignInForm } from "@/components/auth/sign-in-form"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { getSafeInternalNextPath } from "@/lib/auth/redirects"

export default async function SignInPage({
  searchParams,
}: {
  searchParams: Promise<{
    next?: string | string[]
    message?: string | string[]
  }>
}) {
  const params = await searchParams
  const rawNext = typeof params.next === "string" ? params.next : null
  const next = getSafeInternalNextPath(rawNext)
  const passwordUpdated = params.message === "password-updated"

  return (
    <AuthShell
      title="Sign in"
      description="Use your FANTASY HUD email and password."
    >
      <div className="grid gap-5">
        {passwordUpdated ? (
          <Alert>
            <CircleCheck aria-hidden="true" />
            <AlertDescription>
              Your password was updated. Sign in with the new password.
            </AlertDescription>
          </Alert>
        ) : null}
        <SignInForm next={next} />
      </div>
    </AuthShell>
  )
}
