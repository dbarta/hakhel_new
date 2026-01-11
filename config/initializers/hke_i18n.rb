# Set Hebrew as default locale for the HKE engine
# This affects background jobs and broadcasts
Rails.application.config.i18n.default_locale = :he
Rails.application.config.i18n.available_locales = [:en, :he]

# Ensure the locale is set for background jobs
# The locale is serialized when broadcasts are created and restored when they execute

