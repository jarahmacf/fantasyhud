import { connection } from "next/server"
import { redirect } from "next/navigation"
import { AppShell } from "@/components/app/app-shell"
import { PageHeading } from "@/components/app/page-heading"
import { LiveTracker } from "@/components/tracker/live-tracker"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
export const maxDuration = 300
export default async function TrackerPage() {
  await connection()
  const access = await getWorkspaceAccess()
  if (!access) redirect("/auth/sign-in")
  return (
    <AppShell
      identity={access.identity}
      section={{
        title: "Live tracker",
        description: "Single-user prototype",
        badge: "Sleeper league scores",
      }}
    >
      <div className="px-4 lg:px-6">
        <PageHeading
          title="Your season, live"
          description="Leagues, matchups, rosters and draft value for @jarahmacf"
        />
      </div>
      <div className="@container/main space-y-6 px-4 lg:px-6">
        <LiveTracker />
      </div>
    </AppShell>
  )
}
