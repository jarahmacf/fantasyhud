"use client"

import { useActionState } from "react"

import { updatePasswordAction } from "@/app/auth/actions"
import {
  AuthField,
  AuthFormMessage,
  AuthSubmitButton,
} from "@/components/auth/form-parts"
import { initialAuthActionState } from "@/lib/auth/types"

export function UpdatePasswordForm() {
  const [state, action] = useActionState(
    updatePasswordAction,
    initialAuthActionState
  )

  return (
    <form action={action} className="grid gap-5">
      <AuthFormMessage state={state} />
      <AuthField
        id="password"
        name="password"
        type="password"
        label="New password"
        autoComplete="new-password"
        minLength={8}
        required
        error={state.fieldErrors?.password}
      />
      <AuthField
        id="confirmPassword"
        name="confirmPassword"
        type="password"
        label="Confirm password"
        autoComplete="new-password"
        minLength={8}
        required
        error={state.fieldErrors?.confirmPassword}
      />
      <AuthSubmitButton>Update password</AuthSubmitButton>
    </form>
  )
}
