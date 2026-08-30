import type { CSSProperties, ReactNode } from "react"

import { AppSidebar } from "@/components/app/app-sidebar"
import { SiteHeader } from "@/components/app/site-header"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"

type ShellStyle = CSSProperties & {
  "--sidebar-width": string
  "--header-height": string
}

const shellStyle: ShellStyle = {
  "--sidebar-width": "15rem",
  "--header-height": "3.5rem",
}

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider style={shellStyle}>
      <AppSidebar />
      <SidebarInset className="min-w-0 bg-background">
        <SiteHeader />
        {children}
      </SidebarInset>
    </SidebarProvider>
  )
}
