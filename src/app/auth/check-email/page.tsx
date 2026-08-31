import { Mail } from "lucide-react"
import Link from "next/link"

import { AuthShell } from "@/components/auth/auth-shell"
import { Button } from "@/components/ui/button"

export default function CheckEmailPage() {
  return (
    <AuthShell
      title="Check your email"
      description="Open the confirmation link to finish signing in."
    >
      <div className="grid gap-5 text-sm">
        <div className="flex items-start gap-3 rounded-lg border bg-muted/30 p-4 text-muted-foreground">
          <Mail aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
          <p>
            Delivery can take a moment. The link will return you securely to
            FANTASY HUD.
          </p>
        </div>
        <Button asChild variant="outline" className="w-full">
          <Link href="/auth/sign-in">Back to sign in</Link>
        </Button>
      </div>
    </AuthShell>
  )
}
