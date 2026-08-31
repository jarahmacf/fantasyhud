# FANTASY HUD visual system

The supplied ShadcnStore Next.js dashboard is the canonical implementation base. `REFERENCE_STYLE.md` records its license, allowed adaptations, and excluded demo scope.

## Tokens

Use the shadcn neutral variables in `src/app/globals.css`. Dark mode uses these canonical values:

| Token family             | Rule                                                                                     |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| Background               | `background: oklch(0.145 0 0)`; `foreground: oklch(0.985 0 0)`                           |
| Card and popover         | `oklch(0.205 0 0)` with `oklch(0.985 0 0)` foreground                                    |
| Primary                  | `oklch(0.922 0 0)` with `oklch(0.205 0 0)` foreground                                    |
| Secondary, muted, accent | `oklch(0.269 0 0)` surfaces; muted foreground `oklch(0.708 0 0)`                         |
| Border and input         | `oklch(1 0 0 / 10%)` border; `oklch(1 0 0 / 15%)` input                                  |
| Ring                     | `oklch(0.556 0 0)`                                                                       |
| Sidebar                  | Card-level neutral surface, matching neutral foreground, accent, border, and ring values |

Chart tokens remain the canonical reference values even though this stage renders no charts. The base radius is `0.625rem`; derived component radii use the shadcn `-4px`, `-2px`, base, and `+4px` scale.

## Dimensions and page rhythm

- Desktop sidebar width: `16rem`.
- Collapsed icon width: `3rem`.
- Header height: `calc(var(--spacing) * 14)`.
- Shell order: `SidebarProvider` → `AppSidebar` + `SidebarInset` → `SiteHeader` + main content.
- Main container: `@container/main flex flex-1 flex-col gap-2`.
- Inner vertical rhythm: `flex flex-col gap-4 py-4 md:gap-6 md:py-6`.
- Page horizontal inset: `px-4 lg:px-6`.
- Pages are full width; do not introduce a centered application-wide max-width.

## Headings

Page headings use a `px-4 lg:px-6` wrapper. The title is `text-2xl font-bold tracking-tight`; its description uses `text-muted-foreground`. Do not add decorative eyebrows or marketing-hero layout to application screens.

## Cards

Summary cards use the `Card` primitive composition:

```text
Card
├── CardHeader
│   ├── CardDescription
│   ├── CardTitle
│   └── CardAction
└── CardFooter
```

The summary grid is `grid gap-4 sm:grid-cols-2 xl:grid-cols-4`. Its only surface gradient is the reference treatment: `from-primary/5 to-card bg-gradient-to-t shadow-xs`, with `dark:bg-card`. Card values use sans-serif by default; use `tabular-nums` only when it improves numeric alignment.

## Tables

Data tables use typed TanStack column definitions and shadcn table primitives. The shell is `rounded-lg border bg-card`; the header is sticky with a neutral muted surface; header and cell density is `h-10 px-2` and `p-2`. Sorting must expose `aria-sort`. The table container owns horizontal overflow. Column metadata controls left, center, right, and tabular-numeric alignment.

Toolbars contain only controls that perform a real action. Foundation search is controlled by the header, matches System, Status, and Detail, and reports filtered and total row counts. Empty states must describe the active data set.

## Typography and color

- Use Geist Sans for interface text and Geist Mono only for identifiers, code, technical values, or fixed-width numeric data.
- Follow the reference sizes and weights; do not apply uppercase or letter spacing to routine labels.
- Neutral variables are the default interface identity.
- Chromatic colors communicate success, warning, or failure only.
- Do not use blue as a decorative background, navigation state, focus identity, logo identity, or page-heading accent.

## Mobile behavior

Below the sidebar breakpoint, the sidebar renders in the existing shadcn Sheet and opens through the header trigger. The header search remains usable in the available width. Tables retain horizontal scrolling rather than collapsing or hiding columns. Mobile visual coverage uses a 390 × 844 viewport and includes both closed and open sidebar states.

## Reference file mapping

| Production concern                  | Canonical reference file                                                    |
| ----------------------------------- | --------------------------------------------------------------------------- |
| Tokens and radii                    | `nextjs-version/src/app/globals.css`                                        |
| Shell dimensions and rhythm         | `nextjs-version/src/app/(dashboard)/layout.tsx`                             |
| Page heading and horizontal spacing | `nextjs-version/src/app/(dashboard)/dashboard/page.tsx`                     |
| Summary cards                       | `nextjs-version/src/app/(dashboard)/dashboard/components/section-cards.tsx` |
| Table composition                   | `nextjs-version/src/app/(dashboard)/dashboard/components/data-table.tsx`    |
| Sidebar structure                   | `nextjs-version/src/components/app-sidebar.tsx`                             |
| Header structure                    | `nextjs-version/src/components/site-header.tsx`                             |
| Navigation structure                | `nextjs-version/src/components/nav-main.tsx`                                |
| Footer/account proportions          | `nextjs-version/src/components/nav-user.tsx`                                |
| Card primitive                      | `nextjs-version/src/components/ui/card.tsx`                                 |
| Sidebar primitive                   | `nextjs-version/src/components/ui/sidebar.tsx`                              |
| Table primitive                     | `nextjs-version/src/components/ui/table.tsx`                                |
| Visual target                       | `nextjs-version/public/dashboard-dark.png`                                  |
