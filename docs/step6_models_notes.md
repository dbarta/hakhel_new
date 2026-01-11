# Step 6 – HKE models and concerns

## Files copied
- Models: all files from `hke/app/models/hke/*.rb` into `app/models/hke/` (ApplicationRecord, Community, ContactPerson, DeceasedPerson, Relation, RelationsSelection, Selection, Cemetery, Address, LandingPage, Preference, CsvImport, CsvImportLog, FutureMessage, SentMessage, System, Log, CommunityRecord, RelationSelection).
- Model concerns: from `hke/app/models/concerns/hke/` into `app/models/concerns/hke/` (`deduplicatable`, `log_model_events`, `system_info_concern`, `hebrew_transformations`, plus `addressable`, `preferring`, `loggable`).
- Supporting helpers/modules required by models:
  - `app/helpers/hke/application_helper.rb`
  - `app/helpers/hke/message_generator.rb`
  - `app/models/hke/log_helper.rb`
  - `app/models/hke/logger.rb` (from `app/lib/hke/logger.rb`)
  - `app/models/hke/heb.rb` (from `lib/hke/heb.rb`)

## Zeitwerk/autoload fixes
- Removed engine-relative requires; placed shared modules in app autoload paths.
- Converted enums to Rails 8 syntax: `enum :field, { ... }` in `community`, `csv_import`, `csv_import_log`, `future_message`, `sent_message`.
- Wrapped Hebrew date utilities as `Hke::Heb` and extended into `Hke` to satisfy constant expectations.
- Added `Hke::LogHelper` and `Hke::Logger` under app/models; `Hke::Loggable` now lives in model concerns.
- Copied Addressable/Preferring concerns into model concerns (used by models but originally under controller concerns).

## Engine-only references removed/adjusted
- Removed `require_relative` references to engine lib paths in concerns/models; rely on autoloaded modules instead.

## Dependency changes
- Added gem `httparty` (used by `Hke::Heb`).

## Verification
- `bin/rails zeitwerk:check` passes.
- `bin/rails runner 'puts Hke::Community.name; puts Hke::ContactPerson.name'` outputs both constants.
