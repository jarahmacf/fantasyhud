import type { CSSProperties, ReactNode } from "react"

import { AppSidebar } from "@/components/app/app-sidebar"
import { FoundationSearchProvider } from "@/components/app/foundation-search"
import { SiteHeader } from "@/components/app/site-header"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"

type ShellStyle = CSSProperties & {
  "--sidebar-width": string
  "--sidebar-width-icon": string
  "--header-height": string
}

const shellStyle: ShellStyle = {
  "--sidebar-width": "16rem",
  "--sidebar-width-icon": "3rem",
  "--header-height": "calc(var(--spacing) * 14)",
}

export type AppShellIdentity = {
  email: string | null
  accountLabel: string
}

export function AppShell({
  children,
  identity,
  showFoundationSearch = false,
}: {
  children: ReactNode
  identity?: AppShellIdentity
  showFoundationSearch?: boolean
}) {
  return (
    <FoundationSearchProvider>
      <SidebarProvider style={shellStyle}>
        <AppSidebar identity={identity} />
        <SidebarInset>
          <SiteHeader showFoundationSearch={showFoundationSearch} />
          <div className="flex flex-1 flex-col">
            <div className="@container/main flex flex-1 flex-col gap-2">
              <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
                {children}
              </div>
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </FoundationSearchProvider>
  )
}
