import { connection } from "next/server"

import { AuthShell } from "@/components/auth/auth-shell"
import { UpdatePasswordForm } from "@/components/auth/update-password-form"
import { requireAuthIdentity } from "@/lib/auth/current-user"

export default async function UpdatePasswordPage() {
  await connection()
  await requireAuthIdentity("/auth/update-password")

  return (
    <AuthShell
      title="Choose a new password"
      description="Use at least 8 characters. Your other sessions will be signed out."
    >
      <UpdatePasswordForm />
    </AuthShell>
  )
}
