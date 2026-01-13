# Step 13: Terminal seed/import scripts

## What was added
- Runner scripts (Rails runner targets):
  - `script/hke/init_db_with_admin.rb`
  - `script/hke/import_from_csv.rb`
- Support code:
  - `script/hke/support/api_seeds_executor.rb`
  - `script/hke/support/api_seeds_helper.rb`
  - `script/hke/support/seeds_helper.rb`
- Data files:
  - `db/data/hke/deceased_2022_02_28_no_blanks.csv`
  - `db/data/hke/test_deceased_1_deceased.csv`
- Executable shims inside the repo:
  - `script/07_initialize_db_with_admin.sh`
  - `script/08_import_from_csv.sh`
- Optional PATH wrappers (in `rails_scripts/`):
  - `rails_scripts/07_initialize_db_with_admin.sh`
  - `rails_scripts/08_import_from_csv.sh`

## How to run
- From repo root:
  - `./script/07_initialize_db_with_admin.sh 1`
  - `./script/08_import_from_csv.sh 5`
- From PATH (if `rails_scripts` is on PATH):
  - `07_initialize_db_with_admin.sh 1`
  - `08_import_from_csv.sh 5`

Each wrapper resolves the repo root relative to its own location, cds there, and runs:
- `bin/rails runner 'load Rails.root.join("script","hke","init_db_with_admin.rb")' "$@"`
- `bin/rails runner 'load Rails.root.join("script","hke","import_from_csv.rb")' "$@"`

## Behavior notes
- `init_db_with_admin.rb` clears data and recreates admin/account/community/system using `ApiSeedsExecutor` (pulls helpers via Rails autoload; no `Hke::Engine.root`).
- `import_from_csv.rb` imports up to the provided count (default 1000) from `db/data/hke/deceased_2022_02_28_no_blanks.csv`; logging via `Hke::Loggable`.
- Both accept numeric args through `ARGV` just like the original engine runners.

## Environment assumptions
- Rails app boots normally; database configured/migrated.
- HKE routes/API reachable at `/hke/api/v1`.
- Default API base in helpers is `http://localhost:3000`; override with `HAKHEL_BASE_URL` if needed.
- Sidekiq optional; absence is handled by logging.
