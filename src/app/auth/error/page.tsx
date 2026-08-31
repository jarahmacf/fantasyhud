import { TriangleAlert } from "lucide-react"
import Link from "next/link"

import { AuthShell } from "@/components/auth/auth-shell"
import { Button } from "@/components/ui/button"

export default function AuthErrorPage() {
  return (
    <AuthShell
      title="Authentication link not accepted"
      description="The link may be invalid, expired, or already used."
    >
      <div className="grid gap-5 text-sm">
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 p-4 text-muted-foreground">
          <TriangleAlert
            aria-hidden="true"
            className="mt-0.5 size-4 shrink-0 text-destructive"
          />
          <p>Request a new link or return to sign in and try again.</p>
        </div>
        <Button asChild variant="outline" className="w-full">
          <Link href="/auth/sign-in">Back to sign in</Link>
        </Button>
      </div>
    </AuthShell>
  )
}
