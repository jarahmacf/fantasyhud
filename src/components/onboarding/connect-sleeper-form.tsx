"use client"

import { AlertCircle } from "lucide-react"
import { useActionState } from "react"

import { connectSleeperAccountAction } from "@/app/onboarding/actions"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { initialSleeperConnectionActionState } from "@/lib/sleeper/types"

export function ConnectSleeperForm() {
  const [state, action, pending] = useActionState(
    connectSleeperAccountAction,
    initialSleeperConnectionActionState
  )
  const usernameError = state.fieldErrors?.username

  return (
    <form action={action} className="grid gap-5">
      {state.message ? (
        <Alert variant="destructive" role="alert">
          <AlertCircle aria-hidden="true" />
          <AlertDescription>{state.message}</AlertDescription>
        </Alert>
      ) : null}
      <div className="grid gap-2">
        <Label htmlFor="sleeper-username">Sleeper username</Label>
        <Input
          id="sleeper-username"
          name="username"
          placeholder="@username"
          autoComplete="off"
          maxLength={101}
          required
          aria-invalid={Boolean(usernameError)}
          aria-describedby="sleeper-username-help"
        />
        <p id="sleeper-username-help" className="text-xs text-muted-foreground">
          FANTASY HUD uses Sleeper&apos;s public, read-only API to resolve the
          account.
        </p>
      </div>
      <Button type="submit" className="w-full" disabled={pending}>
        {pending ? "Connecting…" : "Connect Sleeper account"}
      </Button>
    </form>
  )
}
