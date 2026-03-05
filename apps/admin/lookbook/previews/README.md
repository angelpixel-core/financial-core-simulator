# Lookbook Preview Conventions

This folder contains component previews for development catalogs at `/lookbook`.

Conventions:
- One preview class per component.
- Mirror component namespaces in folders.
- Prefer state methods: `default`, `loading`, `empty`, `error`.
- Keep previews deterministic (no external API calls).
- Use realistic labels/values from Financial Core Simulator domain.

Current examples:
- `Admin::Dashboard::KpiCardComponent`
- `Admin::Ui::DataTableComponent`
- `Admin::Ui::EmptyStateComponent`
