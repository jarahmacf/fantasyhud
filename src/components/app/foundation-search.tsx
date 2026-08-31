"use client"

import * as React from "react"

type FoundationSearchContextValue = {
  searchText: string
  setSearchText: (value: string) => void
}

const FoundationSearchContext = React.createContext<
  FoundationSearchContextValue | undefined
>(undefined)

export function FoundationSearchProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [searchText, setSearchText] = React.useState("")

  return (
    <FoundationSearchContext.Provider value={{ searchText, setSearchText }}>
      {children}
    </FoundationSearchContext.Provider>
  )
}

export function useFoundationSearch() {
  const context = React.useContext(FoundationSearchContext)

  if (!context) {
    throw new Error(
      "useFoundationSearch must be used within FoundationSearchProvider"
    )
  }

  return context
}
