"use client"

import Link from "next/link"
import { useActionState } from "react"

import { forgotPasswordAction } from "@/app/auth/actions"
import {
  AuthField,
  AuthFormMessage,
  AuthSubmitButton,
} from "@/components/auth/form-parts"
import { initialAuthActionState } from "@/lib/auth/types"

export function ForgotPasswordForm() {
  const [state, action] = useActionState(
    forgotPasswordAction,
    initialAuthActionState
  )

  return (
    <form action={action} className="grid gap-5">
      <AuthFormMessage state={state} />
      <AuthField
        id="email"
        name="email"
        type="email"
        label="Email"
        autoComplete="email"
        required
        error={state.fieldErrors?.email}
      />
      <AuthSubmitButton>Send reset instructions</AuthSubmitButton>
      <Link
        href="/auth/sign-in"
        className="text-center text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
      >
        Back to sign in
      </Link>
    </form>
  )
}
