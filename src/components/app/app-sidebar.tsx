"use client"

import { PanelsTopLeft } from "lucide-react"
import Link from "next/link"

import { NavMain } from "@/components/app/nav-main"
import { NavUser } from "@/components/app/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

function PlaceholderMark() {
  return (
    <span
      aria-hidden="true"
      className="flex aspect-square size-8 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground"
    >
      <PanelsTopLeft className="size-4" />
    </span>
  )
}

const navigation = [
  {
    label: "Workspace",
    items: [{ title: "Foundation", url: "/foundation", icon: PanelsTopLeft }],
  },
]

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href="/foundation">
                {/* Temporary neutral mark: replace when a canonical brand asset exists. */}
                <PlaceholderMark />
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">FANTASY HUD</span>
                  <span className="truncate text-xs">
                    Portfolio Command Center
                  </span>
                </div>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        {navigation.map((group) => (
          <NavMain key={group.label} {...group} />
        ))}
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
