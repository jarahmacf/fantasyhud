# ShadcnStore reference record

## Source and license

- ZIP: `shadcn-dashboard-landing-template-main.zip`
- License: MIT License, copyright 2025 ShadcnStore
- Preserved license: `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`

## Reference files inspected

- `nextjs-version/src/app/(dashboard)/layout.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/page.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/components/data-table.tsx`
- `nextjs-version/src/app/(dashboard)/dashboard/components/section-cards.tsx`
- `nextjs-version/src/components/app-sidebar.tsx`
- `nextjs-version/src/components/site-header.tsx`
- `nextjs-version/src/components/ui/sidebar.tsx`
- `nextjs-version/src/app/globals.css`
- `nextjs-version/components.json`
- `nextjs-version/public/dashboard-dark.png`

## Patterns adopted

- Fixed desktop sidebar with a mobile off-canvas counterpart
- Compact bordered top header
- Responsive content inset and tight dashboard spacing
- Near-black application background with a slightly lighter sidebar
- Charcoal cards and panels with thin neutral borders
- Four-column compact status-card proportions
- Low-radius controls and surfaces
- Muted sticky table header, dense rows, and responsive table overflow
- Small outline status badges
- `new-york` shadcn component feel, neutral CSS variables, and Lucide icons
- Restrained blue interaction color and semantic green status color
- Tabular, monospaced status and identifier styling

## Features intentionally excluded

- Theme, appearance, sidebar-layout, side, variant, and collapse customizers
- Upgrade promotion, ShadcnStore branding, template logo, and promotional footer
- Landing, authentication, error, mail, chat, calendar, task, FAQ, pricing, and settings pages
- Search command palette, external links, theme toggle, and user menu
- Charts, tabs, drag-and-drop, inline editing, row selection, pagination, and actions menus
- Column customization, “Customize Columns,” and “Add Section” controls
- Fake analytics, fake fantasy-football data, authentication, and backend behavior

## Dependencies intentionally excluded

- Recharts and chart helpers
- dnd-kit
- Zustand
- Sonner
- Form libraries
- React Query
- TanStack Table
- Dependencies used only by removed demos and customizers

## Adaptation record

No reference source file was copied wholesale or substantially ported. The application shell, card proportions, and table surface treatment were selectively reimplemented in the new repository. Current shadcn/ui primitives were generated through the shadcn CLI, not copied from the ZIP.
