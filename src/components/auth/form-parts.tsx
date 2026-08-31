"use client"

import { AlertCircle, CircleCheck } from "lucide-react"
import type { ReactNode } from "react"
import { useFormStatus } from "react-dom"

import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import type { AuthActionState } from "@/lib/auth/types"

export function AuthField({
  id,
  label,
  error,
  ...props
}: {
  id: string
  label: string
  error?: string
} & Omit<React.ComponentProps<typeof Input>, "id">) {
  const errorId = `${id}-error`
  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        aria-invalid={Boolean(error)}
        aria-describedby={error ? errorId : undefined}
        {...props}
      />
      {error ? (
        <p id={errorId} className="text-xs text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  )
}

export function AuthFormMessage({ state }: { state: AuthActionState }) {
  if (!state.message || state.status === "idle") {
    return null
  }

  const isError = state.status === "error"
  return (
    <Alert variant={isError ? "destructive" : "default"}>
      {isError ? (
        <AlertCircle aria-hidden="true" />
      ) : (
        <CircleCheck aria-hidden="true" />
      )}
      <AlertDescription>{state.message}</AlertDescription>
    </Alert>
  )
}

export function AuthSubmitButton({ children }: { children: ReactNode }) {
  const { pending } = useFormStatus()
  return (
    <Button type="submit" className="w-full" disabled={pending}>
      {pending ? "Please wait…" : children}
    </Button>
  )
}
