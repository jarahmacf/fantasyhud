import { Check, CircleCheck, GitBranch, ShieldCheck } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

const summaries = [
  {
    label: "Application",
    value: "Ready",
    badge: "App Router",
    Icon: CircleCheck,
    summary: "Next.js foundation is running",
    detail: "The repository renders the dashboard shell.",
  },
  {
    label: "TypeScript",
    value: "Strict",
    badge: "Ready",
    Icon: Check,
    summary: "Strict checks are enabled",
    detail: "Compiler checks protect the application boundary.",
  },
  {
    label: "Test suite",
    value: "4 gates",
    badge: "Ready",
    Icon: ShieldCheck,
    summary: "Unit, public, auth, and database checks",
    detail: "Vitest, Playwright, and pgTAP cover the foundation.",
  },
  {
    label: "Delivery",
    value: "Linked",
    badge: "Configured",
    Icon: GitBranch,
    summary: "Hosted services follow the repository",
    detail: "Vercel and Supabase integrations are configured.",
  },
] as const

export function FoundationSummaryCards() {
  return (
    <section
      aria-label="Foundation summary"
      className="grid gap-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:shadow-xs sm:grid-cols-2 xl:grid-cols-4 dark:*:data-[slot=card]:bg-card"
    >
      {summaries.map(({ label, value, badge, Icon, summary, detail }) => (
        <Card key={label} className="@container/card">
          <CardHeader>
            <CardDescription>{label}</CardDescription>
            <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
              {value}
            </CardTitle>
            <CardAction>
              <Badge variant="outline">
                <Icon aria-hidden="true" />
                {badge}
              </Badge>
            </CardAction>
          </CardHeader>
          <CardFooter className="flex-col items-start gap-1.5 text-sm">
            <div className="line-clamp-1 flex gap-2 font-medium">
              {summary}
              <Icon aria-hidden="true" className="size-4" />
            </div>
            <div className="text-muted-foreground">{detail}</div>
          </CardFooter>
        </Card>
      ))}
    </section>
  )
}
