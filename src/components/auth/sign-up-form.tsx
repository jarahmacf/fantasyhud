"use client"

import Link from "next/link"
import { useActionState } from "react"

import { signUpAction } from "@/app/auth/actions"
import {
  AuthField,
  AuthFormMessage,
  AuthSubmitButton,
} from "@/components/auth/form-parts"
import { initialAuthActionState } from "@/lib/auth/types"

export function SignUpForm() {
  const [state, action] = useActionState(signUpAction, initialAuthActionState)

  return (
    <form action={action} className="grid gap-5">
      <AuthFormMessage state={state} />
      <AuthField
        id="displayName"
        name="displayName"
        label="Display name"
        autoComplete="name"
        maxLength={100}
        required
        error={state.fieldErrors?.displayName}
      />
      <AuthField
        id="email"
        name="email"
        type="email"
        label="Email"
        autoComplete="email"
        required
        error={state.fieldErrors?.email}
      />
      <AuthField
        id="password"
        name="password"
        type="password"
        label="Password"
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
      <AuthSubmitButton>Create account</AuthSubmitButton>
      <p className="text-center text-sm text-muted-foreground">
        Already have an account?{" "}
        <Link
          href="/auth/sign-in"
          className="font-medium text-foreground underline-offset-4 hover:underline"
        >
          Sign in
        </Link>
      </p>
    </form>
  )
}
