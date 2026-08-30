import Link from "next/link"
import { PanelsTopLeft } from "lucide-react"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarSeparator,
} from "@/components/ui/sidebar"

function PlaceholderMark() {
  return (
    <span
      aria-hidden="true"
      className="grid size-8 shrink-0 grid-cols-2 gap-0.5 rounded-md border border-blue-400/25 bg-blue-500/10 p-1.5"
    >
      <span className="rounded-[1px] bg-blue-400" />
      <span className="rounded-[1px] bg-blue-400/35" />
      <span className="rounded-[1px] bg-blue-400/35" />
      <span className="rounded-[1px] bg-blue-400" />
    </span>
  )
}

export function AppSidebar() {
  return (
    <Sidebar collapsible="offcanvas" variant="sidebar">
      <SidebarHeader className="px-3 pb-3 pt-4">
        <Link
          href="/"
          className="flex min-w-0 items-center gap-3 rounded-md px-1 py-1 outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring"
        >
          <PlaceholderMark />
          <span className="grid min-w-0 leading-tight">
            <span className="truncate text-sm font-semibold tracking-[0.08em] text-white">
              FANTASY HUD
            </span>
            <span className="truncate text-[11px] text-sidebar-foreground/55">
              Portfolio Command Center
            </span>
          </span>
        </Link>
      </SidebarHeader>

      <SidebarSeparator />

      <SidebarContent className="pt-2">
        <SidebarGroup>
          <SidebarGroupLabel className="font-mono text-[10px] uppercase tracking-[0.14em]">
            Workspace
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <SidebarMenuButton
                  asChild
                  isActive
                  className="h-9 data-[active=true]:bg-blue-500/10 data-[active=true]:text-blue-200"
                >
                  <Link href="/">
                    <PanelsTopLeft aria-hidden="true" />
                    <span>Foundation</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter className="p-3">
        <div className="flex items-center gap-2 rounded-md border border-sidebar-border bg-black/10 px-2.5 py-2 font-mono text-[10px] text-sidebar-foreground/60">
          <span
            aria-hidden="true"
            className="size-1.5 rounded-full bg-zinc-500"
          />
          <span>Local foundation</span>
        </div>
      </SidebarFooter>
    </Sidebar>
  )
}
