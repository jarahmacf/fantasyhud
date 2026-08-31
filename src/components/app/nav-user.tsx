import { HardDrive, LogOut, UserRound } from "lucide-react"

import { signOutAction } from "@/app/auth/actions"
import type { AppShellIdentity } from "@/components/app/app-shell"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

export function NavUser({ identity }: { identity?: AppShellIdentity }) {
  if (identity) {
    return (
      <SidebarMenu>
        <SidebarMenuItem>
          <SidebarMenuButton size="lg" className="pointer-events-none">
            <div className="flex aspect-square size-8 items-center justify-center rounded-lg border bg-muted text-muted-foreground">
              <UserRound aria-hidden="true" className="size-4" />
            </div>
            <div className="grid min-w-0 flex-1 text-left text-sm leading-tight">
              <span className="truncate font-medium">
                {identity.accountLabel}
              </span>
              <span className="truncate text-xs text-muted-foreground">
                {identity.email ?? "Signed in"}
              </span>
            </div>
          </SidebarMenuButton>
        </SidebarMenuItem>
        <SidebarMenuItem>
          <form action={signOutAction}>
            <SidebarMenuButton type="submit" className="w-full cursor-pointer">
              <LogOut aria-hidden="true" />
              <span>Sign out</span>
            </SidebarMenuButton>
          </form>
        </SidebarMenuItem>
      </SidebarMenu>
    )
  }

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton size="lg" className="pointer-events-none">
          <div className="flex aspect-square size-8 items-center justify-center rounded-lg border bg-muted text-muted-foreground">
            <HardDrive aria-hidden="true" className="size-4" />
          </div>
          <div className="grid flex-1 text-left text-sm leading-tight">
            <span className="truncate font-medium">Local workspace</span>
            <span className="truncate text-xs text-muted-foreground">
              No signed-in user
            </span>
          </div>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
