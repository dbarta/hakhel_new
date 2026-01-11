# HKE migration plan (hakhel/hke → hakhel_new)

## Goal & assumptions
- Move all HKE functionality from the existing engine (`hke/`) and host app (`hakhel/`) into `hakhel_new/` as first-class Rails code (no engine mount/gem).
- Keep behavior, routes, and DB schema equivalent; reuse Jumpstart Pro conventions already in `hakhel_new/`.
- No application code changes now—this document is planning/inventory only.

## Inventory (source)
### Engine code (`hke/`)
- Models: `app/models/hke/*.rb` (`application_record.rb`, `community.rb`, `contact_person.rb`, `deceased_person.rb`, `relation.rb`, `relations_selection.rb`, `selection.rb`, `landing_page.rb`, `preference.rb`, `csv_import.rb`, `csv_import_log.rb`, `future_message.rb`, `sent_message.rb`, `system.rb`, `log.rb`, `community_record.rb`), concerns `app/models/concerns/hke/*.rb` (`deduplicatable.rb`, `log_model_events.rb`, `system_info_concern.rb`, `hebrew_transformations.rb`).
- Migrations: `db/migrate/*.rb` (34 files, e.g. `20231209122112_create_hke_addresses.rb`, `20231211193244_create_hke_contact_people.rb`, `20231216093314_create_hke_relations.rb`, `20240827075146_create_hke_future_messages.rb`, `20250429064828_create_hke_logs.rb`, `20251023120000_create_hke_csv_import_logs_and_add_name_to_imports.rb`).
- Controllers / routes / API: Engine routes `config/routes.rb` defines admin/community dashboards, CRUD for cemeteries/contact_people/deceased_people/future_messages/landing_pages/logs/message_management/csv_imports/selections, and API `api/v1` endpoints for systems, cemeteries, communities, future_messages (with `blast`), deceased_people, contact_people, relations, csv_imports, csv_import_logs, twilio callbacks. Controllers under `app/controllers/hke/**` (admin dashboard/communities/system_preferences, community-facing dashboard/logs/cemeteries/future_messages/contact_people/deceased_people/landing_pages/selections/csv_imports/message_management/sms_messages/addresses), API controllers under `app/controllers/hke/api/v1/**`, base controller `app/controllers/hke/api/base_controller.rb`. Controller concerns: `app/controllers/concerns/hke/authorization.rb`, `set_community_as_tenant.rb`, `addressable.rb`, `preferring.rb`, plus `app/controllers/concerns/set_locale.rb`.
- Services: `app/services/hke/message_processor.rb`, `app/services/hke/import/csv_import_api_client.rb`, `app/services/hke/twilio_send.rb`, `app/services/hke/twilio_sms_sender.rb`, `app/services/hke/liquid_renderer.rb`.
- Jobs / Sidekiq: `app/jobs/hke/csv_import_job.rb`, `future_message_send_job.rb`, `future_message_daily_scheduler_job.rb`, `future_message_community_daily_scheduler_job.rb`, base `app/jobs/hke/application_job.rb`.
- Mailers: `app/mailers/hke/application_mailer.rb` (no other mailers found).
- Views: `app/views/hke/**` covering dashboards, admin CRUD, contact_people/deceased_people/cemeteries/landing_pages/selections, csv_imports, message_management, logs, addresses, liquid templates (`app/views/hke/liquid_templates/...`), layouts (`app/views/layouts/hke/landing.html.erb`), jbuilder JSON for selections/future_messages/cemeteries. (Numerous partials such as `_search_results`, `_messages_approval_table`, `_community_admin_navbar`.)
- JavaScript / React: none in `app/javascript` (search returned no files).
- Locales / i18n: `config/locales/en.yml`, `config/locales/he.yml`.
- Initializers / configuration: `config/initializers/i18n.rb`, `config/initializers/logging_filters.rb`, `config/initializers/cors.rb`.
- Tests/specs: RSpec-based `spec/**` (models, controllers, factories, support helpers such as `spec/support/acts_as_tenant.rb`, `spec/support/api_logger.rb`, factories for HKE models).

### Host app touchpoints (`hakhel/`)
- Engine mount: `config/routes.rb` mounts `Hke::Engine` at `/hke`.
- Engine-derived migrations already present: `db/migrate/*_hke.rb` (e.g. `20231224203715_create_hke_addresses.hke.rb`, `20240919113157_add_community_id_to_hke_relations.hke.rb`, `202505102409...` etc.) plus later additions like `20251024063049_add_statistics_to_hke_csv_imports.rb`.
- Schema includes HKE tables: `db/schema.rb` (`hke_addresses`, `hke_cemeteries`, `hke_communities`, `hke_contact_people`, `hke_csv_imports`, `hke_csv_import_logs`, `hke_deceased_people`, `hke_future_messages`, `hke_landing_pages`, `hke_logs`, `hke_preferences`, `hke_relations`, `hke_relations_selections`, `hke_selections`, `hke_sent_messages`, `hke_systems`).
- Models: `app/models/user.rb` uses HKE roles and `belongs_to :community, class_name: 'Hke::Community'`.
- Controllers: `app/controllers/application_controller.rb` routes post-login to `hke` paths; `app/controllers/users_controller.rb` loads `Hke::Community`, renders `hke/shared/search_results`.
- Views: `app/views/shared/_navbar.html.erb` links to `hke` routes and community switcher; `app/views/dashboard/show.html.erb` references `hke` (per search).
- Routing docs: `routes.txt` includes HKE paths (for reference).
- Tests: `spec/rails_helper.rb` mentions HKE (per search).

## Mapping table (source → destination)
| Source path (hakhel/ or hke/) | Destination path in `hakhel_new/` |
| --- | --- |
| `hke/app/models/hke/**/*.rb` | `hakhel_new/app/models/hke/**/*.rb` (retain module namespace) |
| `hke/app/models/concerns/hke/**/*.rb` | `hakhel_new/app/models/concerns/hke/**/*.rb` |
| `hke/app/controllers/hke/**/*.rb` | `hakhel_new/app/controllers/hke/**/*.rb` (converted to app routes instead of engine) |
| `hke/app/controllers/concerns/hke/**/*.rb` and `concerns/set_locale.rb` | `hakhel_new/app/controllers/concerns/hke/**/*.rb` (and `concerns/set_locale.rb`) |
| `hke/app/services/hke/**/*.rb` | `hakhel_new/app/services/hke/**/*.rb` |
| `hke/app/jobs/hke/**/*.rb` | `hakhel_new/app/jobs/hke/**/*.rb` |
| `hke/app/mailers/hke/**/*.rb` | `hakhel_new/app/mailers/hke/**/*.rb` |
| `hke/app/views/hke/**` and `app/views/layouts/hke/**` | `hakhel_new/app/views/hke/**` (preserve partials/liquid templates/layout) |
| `hke/config/routes.rb` | Merge routes into `hakhel_new/config/routes.rb` under `/hke` scope (no engine mount) |
| `hke/config/locales/*.yml` | `hakhel_new/config/locales/hke.*.yml` |
| `hke/config/initializers/*.rb` | `hakhel_new/config/initializers/hke_*.rb` (namespaced to avoid collision) |
| `hke/db/migrate/*.rb` | `hakhel_new/db/migrate/*.rb` (dedupe against existing `hakhel` migrations; preserve timestamps or re-time as needed) |
| `hke/spec/**` (RSpec) | `hakhel_new/spec/hke/**` (or convert to `test/` if sticking with Minitest) |
| `hakhel/app/models/user.rb` (HKE roles/association) | `hakhel_new/app/models/user.rb` |
| `hakhel/app/controllers/application_controller.rb`, `app/controllers/users_controller.rb` | `hakhel_new/app/controllers/...` (retain HKE redirects/assignments) |
| `hakhel/app/views/shared/_navbar.html.erb` (+ any HKE nav UI) | `hakhel_new/app/views/shared/_navbar.html.erb` |
| `hakhel/db/migrate/*_hke.rb` and `db/migrate/20251024063049_add_statistics_to_hke_csv_imports.rb` | Ensure equivalent migrations exist in `hakhel_new/db/migrate` (drop `.hke` suffix) |

## Proposed migration order (safe sequencing)
- Copy/merge migrations first, reconciling duplicates between `hke/db/migrate` and `hakhel/db/migrate/*_hke.rb`; run `db:migrate` in `hakhel_new` to establish schema.
- Add initializers/config (`i18n.rb`, `logging_filters.rb`, `cors.rb`) and locales to ensure boot and translations succeed.
- Bring models and model concerns (ensure Zeitwerk paths/namespaces work under app/).
- Port services, jobs, mailers; wire any required credentials (Twilio, liquid templates) via credentials/env.
- Integrate controller concerns, then controllers/routes by inlining engine routes into `hakhel_new/config/routes.rb` under `/hke` path; verify before_actions/tenancy filters.
- Move views/layouts/liquid templates; adjust layout references if needed.
- Update host-level integration: user roles/associations, navbar links, post-login redirects, any account/role helpers.
- Port tests (RSpec or convert to Minitest) and factories; align with `hakhel_new` test stack.
- Remove engine dependency/gem reference only after feature parity is confirmed in `hakhel_new`.

## Potential conflicts / risks
- Zeitwerk namespace changes when moving out of engine (ensure module prefixes `Hke::` remain and paths match).
- Table name collisions/duplicate migrations: many existing `.hke` migrations already applied in `hakhel`; need deduping to avoid duplicate table creation or timestamp collisions.
- Tenancy/current tenant: controller concern `set_community_as_tenant` and model scoping must be wired into `hakhel_new` middleware/Current pattern.
- Jumpstart customizations: navbar links, devise redirects, and role handling in `User`/`ApplicationController` rely on HKE paths; ensure equivalents before removing engine mount.
- Sidekiq/job queues: HKE jobs may expect specific queue names and schedule triggers (daily schedulers) that must be added to `config/queue.yml`/scheduler.
- API behavior: endpoints under `/hke/api/v1` include Twilio callbacks and CSV import flows; confirm auth and CORS (`config/initializers/cors.rb`) when re-homing.
- Locale keys and Liquid templates contain Hebrew content; keep encoding and file names stable.
- Test stack mismatch: HKE uses RSpec while `hakhel_new` ships with Minitest; decide whether to introduce RSpec or port tests.
