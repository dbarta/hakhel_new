# Step 4 – locales and initializers copied

- Locales copied:
  - `config/locales/hke.en.yml` (from `hke/config/locales/en.yml`)
  - `config/locales/hke.he.yml` (from `hke/config/locales/he.yml`)

- Initializers copied (prefixed to avoid collisions):
  - `config/initializers/hke_i18n.rb`
  - `config/initializers/hke_logging_filters.rb`
  - `config/initializers/hke_cors.rb`

- Conflicts/collisions:
  - None detected; files are prefixed `hke_` to avoid overriding existing Jumpstart initializers. CORS settings remain permissive as in the engine.

- Env vars/credentials observed:
  - CORS origins are hard-coded (`*`, `localhost:3000`, `127.0.0.1:3000`). No additional env vars referenced in these initializers. If production needs restricted origins, adjust `hke_cors.rb` accordingly.
