# Task 002.1 template-fidelity audit

The supplied ShadcnStore Next.js dashboard is the canonical visual implementation reference for this pass. The reference screenshot and all files named in Task 002.1 were inspected from the attached MIT-licensed archive before production code was changed.

| Area                    | Reference implementation                                                                        | Current implementation                                                             | Required correction                                                                                  | Production file                                                       |
| ----------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Dark color tokens       | Neutral shadcn dark tokens: `background` 0.145, `card` 0.205, neutral primary/accent/ring       | Near-black background with a chromatic blue primary, accent, and ring              | Adopt the reference dark neutral token set; reserve color for semantic state                         | `src/app/globals.css`                                                 |
| Radius                  | `--radius: 0.625rem` with shadcn derived sizes                                                  | `--radius: 0.375rem` with custom derived sizes                                     | Use the reference radius and derivation                                                              | `src/app/globals.css`                                                 |
| Sidebar width           | `16rem`, icon width `3rem`                                                                      | `15rem`; icon width inherited from primitive only                                  | Set both canonical dimensions on the provider                                                        | `src/components/app/app-shell.tsx`                                    |
| Header height           | `calc(var(--spacing) * 14)`                                                                     | `3.5rem` literal                                                                   | Use the canonical variable expression                                                                | `src/components/app/app-shell.tsx`                                    |
| Page width and padding  | Full-width inset with `px-4 lg:px-6`                                                            | Centered `max-w-[1440px]` with `lg:px-8`                                           | Remove the max-width container and use reference padding                                             | `src/app/page.tsx`                                                    |
| Page heading            | Plain `text-2xl font-bold tracking-tight` title and muted description                           | Blue all-caps eyebrow plus a custom title weight/size                              | Use the dashboard title composition and remove the decorative eyebrow                                | `src/components/app/page-heading.tsx`                                 |
| Summary cards           | Card primitive with header, description, title, action, footer, subtle primary-to-card gradient | Custom `StatusCard` article with smaller radius and monospaced values              | Replace with the reference Card composition and four truthful foundation cards                       | `src/components/data/foundation-summary-cards.tsx`                    |
| Active navigation state | Neutral `sidebar-accent` active background and foreground                                       | Custom blue active wash and blue foreground                                        | Use `SidebarMenuButton`'s canonical neutral active state                                             | `src/components/app/app-sidebar.tsx`                                  |
| Table shell             | Rounded-lg bordered surface, muted sticky header, canonical table primitives                    | Rounded-md custom table wrapper and hand-built sorting                             | Use a typed TanStack table inside the reference shell                                                | `src/components/data/data-table.tsx`                                  |
| Table toolbar           | Compact horizontal control row aligned to table padding                                         | Separate heading block; no result/search state                                     | Add section label, visible result count, and active-search state only                                | `src/components/data/foundation-status-table.tsx`                     |
| Table row density       | `h-10` headers and compact `p-2` cells with neutral row hover                                   | Custom uppercase 10px headers and `h-11 px-4` cells                                | Restore reference header/cell density and typography                                                 | `src/components/data/data-table.tsx`                                  |
| Typography              | Inter-like hierarchy with restrained normal sans usage                                          | Geist retained, but monospaced and uppercase treatments are overused               | Keep Geist; match reference sizes, weights, and hierarchy; reserve mono for technical values         | UI components and `src/app/globals.css`                               |
| Accent usage            | Neutral grayscale UI; chromatic colors are semantic only                                        | Blue logo, navigation, eyebrow, primary, ring, and selection wash                  | Remove broad blue identity and keep only semantic success/warning/failure color                      | `src/app/globals.css` and app components                              |
| Footer/account block    | 32px account-block proportions in `SidebarFooter`                                               | Bordered terminal-like monospaced status strip                                     | Preserve the proportions but show truthful “Local workspace / No signed-in user” text without a menu | `src/components/app/app-sidebar.tsx`                                  |
| Mobile sidebar behavior | Off-canvas `Sheet` driven by `SidebarProvider` and `SidebarTrigger`                             | Off-canvas primitive exists; trigger is desktop-hidden and header spacing diverges | Keep the Sheet behavior, expose the canonical trigger, and test the open state at 390px              | `src/components/ui/sidebar.tsx`, `src/components/app/site-header.tsx` |

## Reference files inspected

- `nextjs-version/public/dashboard-dark.png`
- `nextjs-version/src/app/globals.css`
- `nextjs-version/src/app/(dashboard)/layout.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/page.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/components/section-cards.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/components/data-table.tsx`
- `nextjs-version/src/components/app-sidebar.tsx`
- `nextjs-version/src/components/site-header.tsx`
- `nextjs-version/src/components/nav-main.tsx`
- `nextjs-version/src/components/nav-user.tsx`
- `nextjs-version/src/components/ui/card.tsx`
- `nextjs-version/src/components/ui/sidebar.tsx`
- `nextjs-version/src/components/ui/table.tsx`

## Current files inspected

- `src/app/globals.css`
- `src/app/page.tsx`
- `src/components/app/app-shell.tsx`
- `src/components/app/app-sidebar.tsx`
- `src/components/app/site-header.tsx`
- `src/components/data/data-table.tsx`
- `src/components/data/status-card.tsx`
- `src/components/data/foundation-status-table.tsx`
- `REFERENCE_STYLE.md`
- `DECISIONS.md`
