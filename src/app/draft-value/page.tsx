import { redirect } from "next/navigation"
import { connection } from "next/server"
import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { DraftImportControl } from "@/components/draft-value/draft-import-control"
import { getDraftImportSummary } from "@/lib/drafts/summary.server"
import { DraftValueCalculator } from "@/components/draft-value/draft-value-calculator"
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"

export const maxDuration = 300

export default async function DraftValuePage() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  if (!access.account) redirect("/onboarding")
  const draftSummary = await getDraftImportSummary(
    access.supabase,
    access.account.id
  )
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
            <CardTitle>
              {draftSummary.status === "imported"
                ? `${draftSummary.drafts} drafts imported`
                : draftSummary.status === "unavailable"
                  ? "Draft import status is unavailable"
                  : "Portfolio tracking is not connected yet"}
            </CardTitle>
            <CardDescription>
              {draftSummary.status === "imported"
                ? `${draftSummary.finalized} boards finalized${draftSummary.partial ? "; some boards or participation remain unresolved" : ""}. Automatic price comparisons still need dated ADP or auction samples and weekly results under your exact scoring rules. The calculator below uses your own inputs.`
                : "Your roster imports do not include draft purchases. Automatic comparisons still need complete draft imports, dated ADP or auction market samples, and weekly results calculated under your exact scoring rules. You can use your own inputs in the calculator below."}
            </CardDescription>
          </CardHeader>
          {!access.readOnly ? (
            <CardFooter>
              <DraftImportControl
                hasImported={draftSummary.status === "imported"}
              />
            </CardFooter>
          ) : null}
        </Card>
        <DraftValueCalculator accountId={access.account.id} />
      </div>
    </AppShell>
  )
}
