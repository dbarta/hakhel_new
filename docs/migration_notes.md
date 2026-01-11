# HKE migration notes (sequence only, no code copied yet)

## Checklist
- Build a schema-baseline migration from `hakhel/db/schema.rb` covering all `hke_*` tables (preserve names and columns).
- Review `hke/db/migrate/*.rb` and `hakhel/db/migrate/*_hke.rb` to confirm the baseline includes every schema element.
- Migration order for code/assets after baseline:
  1. Locales
  2. Initializers
  3. Models
  4. Model/controller concerns
  5. Services
  6. Jobs
  7. Mailers
  8. Controllers
  9. Routes (inline under `/hke/...` in `config/routes.rb`)
  10. Views (including layouts and liquid templates)
- Integrate host-app touchpoints after code copy: `User` roles/association, navbar links, login redirects, any helpers that reference `Hke::`.
