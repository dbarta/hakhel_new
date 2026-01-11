# HKE paths and placement in `hakhel_new`

- Keep the Ruby namespace `Hke::`.
- Keep database tables named `hke_*` (no renames).
- Routes stay under `/hke/...` but will be defined directly in `hakhel_new/config/routes.rb` (no engine mount/gem).

### Where each area will live
- Models: `app/models/hke/`, model concerns: `app/models/concerns/hke/`.
- Controllers: `app/controllers/hke/`, API controllers `app/controllers/hke/api/v1/`, shared controller concerns `app/controllers/concerns/hke/`.
- Services: `app/services/hke/`, imports: `app/services/hke/import/`.
- Jobs: `app/jobs/hke/`.
- Mailers: `app/mailers/hke/`.
- Views: `app/views/hke/` with layouts in `app/views/layouts/hke/` and liquid templates in `app/views/hke/liquid_templates/`.
- Locales: `config/locales/`.
- Initializers: `config/initializers/`.
- Docs: `docs/`.
