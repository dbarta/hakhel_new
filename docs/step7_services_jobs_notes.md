# Step 7 – services and jobs

## Files copied
- Services: `app/services/hke/message_processor.rb`, `twilio_send.rb`, `twilio_sms_sender.rb`, `liquid_renderer.rb`, `import/csv_import_api_client.rb`, plus `app/services/hke/api_helper.rb`.
- Jobs: `app/jobs/hke/application_job.rb`, `csv_import_job.rb`, `future_message_send_job.rb`, `future_message_daily_scheduler_job.rb`, `future_message_community_daily_scheduler_job.rb`.
- Shared modules moved from lib: `app/models/concerns/hke/job_logging_helper.rb`.

## Refactors / fixes
- Removed engine dependency in `LiquidRenderer` (uses `Rails.root` templates).
- `TwilioSend#webhook_url` now builds a static `/hke/api/v1/twilio/sms/status` URL using `WEBHOOK_HOST`/default host (no engine routes yet).
- Removed engine-relative requires; rely on autoload paths for helpers/concerns.
- `ApiHelper` now lives under `app/services/hke/` without manual require_relative.

## Gems added
- `twilio-ruby`, `sendgrid-ruby`, `liquid` (for Twilio/SendGrid delivery and Liquid rendering).
  *(httparty already present from prior step.)*

## Verification
- `bin/rails zeitwerk:check` passes.
- `bin/rails runner 'puts Hke::MessageProcessor.name; puts Hke::TwilioSmsSender.name; puts Hke::CsvImportJob.name'` returns class names successfully.
