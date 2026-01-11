# Step 5 – locales and initializers

- Copied locales:
  - `config/locales/hke.en.yml` (from `hke/config/locales/en.yml`)
  - `config/locales/hke.he.yml` (from `hke/config/locales/he.yml`)

- Copied initializers (prefixed to avoid collisions):
  - `config/initializers/hke_i18n.rb`
  - `config/initializers/hke_logging_filters.rb`
  - `config/initializers/hke_cors.rb` (adds `require "rack/cors"`)

- Conflicts/resolution:
  - None detected with existing Jumpstart initializers. CORS remains permissive as in the engine; existing app CORS initializers were left intact.

- Gems:
  - `rack-cors` already present in `Gemfile`; no new gems added.
