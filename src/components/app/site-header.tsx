"use client"

import * as React from "react"
import { Search, X } from "lucide-react"

import { useFoundationSearch } from "@/components/app/foundation-search"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { SidebarTrigger } from "@/components/ui/sidebar"

export function SiteHeader() {
  const { searchText, setSearchText } = useFoundationSearch()
  const searchRef = React.useRef<HTMLInputElement>(null)

  React.useEffect(() => {
    function focusSearch(event: KeyboardEvent) {
      if (event.key.toLowerCase() === "k" && (event.metaKey || event.ctrlKey)) {
        event.preventDefault()
        searchRef.current?.focus()
      }
    }

    document.addEventListener("keydown", focusSearch)
    return () => document.removeEventListener("keydown", focusSearch)
  }, [])

  return (
    <header className="flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-(--header-height)">
      <div className="flex w-full items-center gap-1 px-4 py-3 lg:gap-2 lg:px-6">
        <SidebarTrigger className="-ml-1" />
        <Separator
          orientation="vertical"
          className="mx-2 data-[orientation=vertical]:h-4"
        />
        <div className="relative max-w-sm flex-1">
          <Search
            aria-hidden="true"
            className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
          />
          <input
            ref={searchRef}
            type="search"
            aria-label="Search foundation status"
            placeholder="Search foundation…"
            value={searchText}
            onChange={(event) => setSearchText(event.target.value)}
            className="h-9 w-full rounded-md border border-input bg-transparent py-1 pl-9 pr-16 text-sm shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
          />
          {searchText ? (
            <Button
              type="button"
              variant="ghost"
              size="icon-xs"
              aria-label="Clear search"
              onClick={() => {
                setSearchText("")
                searchRef.current?.focus()
              }}
              className="absolute right-1.5 top-1/2 -translate-y-1/2"
            >
              <X aria-hidden="true" />
            </Button>
          ) : (
            <kbd className="pointer-events-none absolute right-2 top-1/2 hidden -translate-y-1/2 rounded border bg-muted px-1.5 font-sans text-[10px] text-muted-foreground sm:inline-flex">
              ⌘K
            </kbd>
          )}
        </div>
        <div className="ml-auto hidden items-center gap-2 sm:flex">
          <Button variant="ghost" size="sm" className="pointer-events-none">
            Backend foundation
          </Button>
          <Badge variant="outline">Foundation</Badge>
        </div>
      </div>
    </header>
  )
}
