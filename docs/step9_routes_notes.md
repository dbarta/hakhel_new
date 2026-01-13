# Step 9 – HKE routes inlined

## Structure
- Added a `namespace :hke, path: "/hke"` block in `config/routes.rb` with the same resources/actions as the former engine.
- Admin namespace preserved (`/hke/admin/...`) for communities/users and system preferences.
- Community/admin-facing resources: logs, cemeteries, communities (show/edit/update), future_messages (blast/toggle_approval + approve/bulk/dis/approve_all), csv_imports (destroy_all), message_management, landing_pages, contact_people (index/import_csv POST), deceased_people (index/import_csv POST), community_preferences.
- API under `/hke/api/v1` with JSON defaults: twilio status callback, system, cemeteries, communities, future_messages (blast), deceased_people, contact_people, relations, csv_imports (index/show/create/update), csv_import_logs (create).
- Retained engine root-equivalent routes (`/hke` dashboard) and legacy contact_people shortcuts.

## Deviations / notes
- Engine mount removed; all routes defined directly.
- Paths/names mirror engine; webhook URL uses same `/hke/api/v1/twilio/sms/status`.

## Verification
- `bin/rails routes | grep -E '^hke|/hke'` shows expected route set under `/hke`.
- `bin/rails runner 'p Rails.application.routes.recognize_path("/hke/api/v1/future_messages", method: :get)'` resolves to `hke/api/v1/future_messages#index`.
