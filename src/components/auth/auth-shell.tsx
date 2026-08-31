import { PanelsTopLeft } from "lucide-react"
import type { ReactNode } from "react"

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

export function AuthShell({
  title,
  description,
  children,
}: {
  title: string
  description: string
  children: ReactNode
}) {
  return (
    <main className="flex min-h-svh items-center justify-center px-4 py-10">
      <div className="w-full max-w-md space-y-6">
        <header className="flex items-center justify-center gap-3 text-center">
          <span className="flex size-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
            <PanelsTopLeft aria-hidden="true" className="size-4" />
          </span>
          <div className="text-left text-sm leading-tight">
            <div className="font-medium">FANTASY HUD</div>
            <div className="text-xs text-muted-foreground">
              Portfolio Command Center
            </div>
          </div>
        </header>
        <Card className="bg-gradient-to-t from-primary/5 to-card shadow-xs dark:bg-card">
          <CardHeader>
            <CardTitle role="heading" aria-level={1} className="text-xl">
              {title}
            </CardTitle>
            <CardDescription>{description}</CardDescription>
          </CardHeader>
          <CardContent>{children}</CardContent>
        </Card>
      </div>
    </main>
  )
}
