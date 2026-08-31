# ShadcnStore canonical reference

## Source and license

- Source archive: `shadcn-dashboard-landing-template-main.zip`
- Canonical screenshot: `nextjs-version/public/dashboard-dark.png`
- License: MIT License, copyright 2025 ShadcnStore
- Preserved license: `THIRD_PARTY_LICENSES/ShadcnStore-MIT.txt`

The supplied ShadcnStore Next.js dashboard is FANTASY HUD's canonical visual implementation reference. Direct adaptation of its MIT-licensed DOM structure, Tailwind classes, tokens, dimensions, and component composition is intentionally permitted and preferred. Recreating these patterns from memory is discouraged because it causes spacing and hierarchy drift.

Preserve exact reference values where product requirements allow. Before changing the application shell, sidebar, header, cards, table, heading, or page spacing, inspect the corresponding reference source listed in `VISUAL_SYSTEM.md`.

## Deliberate product adaptations

- Geist Sans and Geist Mono replace Inter; this is the deliberate font deviation.
- FANTASY HUD identity and repository-foundation facts replace ShadcnStore branding and demo analytics.
- Navigation exposes only the real Foundation route.
- The header search filters the local foundation table instead of opening a demo command palette.
- The footer describes a local workspace and explicitly states that no user is signed in.
- Semantic green is limited to truthful ready/configured statuses.

## Excluded reference features

- Theme, appearance, sidebar-layout, side, variant, and collapse customizers
- Upgrade promotion, template branding, promotional notifications, and promotional footer
- Landing, authentication, error, mail, chat, calendar, task, FAQ, pricing, and settings pages
- External marketing links, theme toggle, and fake user menu
- Charts, demo analytics, tabs, drag-and-drop, row selection, inline editing, pagination, and actions menus
- Column customization, `Customize Columns`, and `Add Section` controls
- Fake fantasy data, future-product navigation, authentication, and backend behavior

These exclusions remove demo scope. They do not authorize alternate shell, spacing, card, or table styling.
