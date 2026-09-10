import { connection } from "next/server"
import { notFound, redirect } from "next/navigation"
import { AppShell } from "@/components/app/app-shell"
import { PlayerProfile } from "@/components/research/player-profile"
import { getWorkspaceAccess } from "@/lib/access/workspace.server"
export default async function PlayerPage({
  params,
  searchParams,
}: {
  params: Promise<{ token: string }>
  searchParams: Promise<{ context?: string }>
}) {
  await connection()
  const access = await getWorkspaceAccess(),
    { token } = await params,
    { context } = await searchParams
  if (!access?.account) redirect("/auth/sign-in")
  if (!/^[a-f0-9]{24}$/.test(token)) notFound()
  return (
    <AppShell identity={access.identity}>
      <div className="space-y-6 px-4 lg:px-6">
        <PlayerProfile token={token} initialContext={context ?? null} />
      </div>
    </AppShell>
  )
}
