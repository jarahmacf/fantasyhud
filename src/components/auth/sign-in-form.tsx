"use client"

import Link from "next/link"
import { useActionState } from "react"

import { signInAction } from "@/app/auth/actions"
import {
  AuthField,
  AuthFormMessage,
  AuthSubmitButton,
} from "@/components/auth/form-parts"
import { initialAuthActionState } from "@/lib/auth/types"

export function SignInForm({ next }: { next: string }) {
  const [state, action] = useActionState(signInAction, initialAuthActionState)

  return (
    <form action={action} className="grid gap-5">
      <input type="hidden" name="next" value={next} />
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
      <div className="grid gap-2">
        <AuthField
          id="password"
          name="password"
          type="password"
          label="Password"
          autoComplete="current-password"
          required
          error={state.fieldErrors?.password}
        />
        <Link
          href="/auth/forgot-password"
          className="justify-self-end text-xs text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
        >
          Forgot password?
        </Link>
      </div>
      <AuthSubmitButton>Sign in</AuthSubmitButton>
      <p className="text-center text-sm text-muted-foreground">
        New to FANTASY HUD?{" "}
        <Link
          href="/auth/sign-up"
          className="font-medium text-foreground underline-offset-4 hover:underline"
        >
          Create an account
        </Link>
      </p>
    </form>
  )
}
