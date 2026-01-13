# Step 8 – controller concerns and controllers

## Files copied
- Controller concerns: `app/controllers/concerns/hke/*.rb` plus `app/controllers/concerns/set_locale.rb`.
- Controllers: all `app/controllers/hke/**` including web CRUD/dashboard/message controllers and API controllers under `hke/api/v1/**` plus base controllers.

## Fixes/refactors
- `set_locale.rb` moved to `module SetLocale` (non-namespaced) to match include in `ApplicationController`.
- Added stub `app/controllers/concerns/current_helper.rb` to satisfy `include CurrentHelper` (Jumpstart may supply richer impl).
- Pagy dependency surfaced; added `config/initializers/pagy.rb` with lightweight fallback for `Pagy::Backend`.
- `app/controllers/hke/logs_controller.rb` now requires `pagy` explicitly to load backend module.

## Dependencies
- `pagy` already present via Jumpstart; initializer ensures constant availability.

## Verification
- `bin/rails zeitwerk:check` passes.
- `bin/rails runner 'puts Hke::Api::V1::FutureMessagesController.name; puts Hke::DashboardController.name'` confirms controller load.

## TODO / remaining
- Routes under `/hke` still to be inlined; currently controllers rely on future route mapping.
- Authorization/policy wiring untouched; revisit when integrating routes/views.
