import { redirect } from "next/navigation"
import { connection } from "next/server"
import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { DraftValueCalculator } from "@/components/draft-value/draft-value-calculator"
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"

export default async function DraftValuePage() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  if (!access.account) redirect("/onboarding")
  return (
    <AppShell
      identity={access.identity}
      section={{
        title: "Draft value",
        description: "Manual calculation",
        badge: "Price and performance",
      }}
    >
      <div className="px-4 lg:px-6">
        <PageHeading
          title="Draft value"
          description="Compare the positional rank your draft price implies with season performance"
        />
      </div>
      <div className="@container/main space-y-6 px-4 lg:px-6">
        <Card>
          <CardHeader>
            <CardTitle>Portfolio tracking is not connected yet</CardTitle>
            <CardDescription>
              Your roster imports do not include draft purchases. Automatic
              comparisons still need complete draft imports, dated ADP or
              auction market samples, and weekly results calculated under your
              exact scoring rules. You can use your own inputs in the calculator
              below.
            </CardDescription>
          </CardHeader>
        </Card>
        <DraftValueCalculator accountId={access.account.id} />
      </div>
    </AppShell>
  )
}
