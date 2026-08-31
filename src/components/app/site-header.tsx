import { Separator } from "@/components/ui/separator"
import { SidebarTrigger } from "@/components/ui/sidebar"

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-20 flex h-(--header-height) shrink-0 items-center border-b bg-background">
      <div className="flex w-full items-center gap-2 px-4 sm:px-6 lg:px-8">
        <SidebarTrigger className="-ml-1 md:hidden" />
        <Separator
          orientation="vertical"
          className="mx-1 hidden data-[orientation=vertical]:h-4 sm:block md:hidden"
        />
        <span className="text-sm font-medium text-foreground">
          Backend foundation
        </span>
        <span className="ml-auto inline-flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.12em] text-muted-foreground">
          <span
            aria-hidden="true"
            className="size-1.5 rounded-full bg-zinc-500"
          />
          Git-connected
        </span>
      </div>
    </header>
  )
}
