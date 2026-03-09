# config/initializers/sidekiq.rb
require "sidekiq"
require "sidekiq/cron/job"

# Heroku Redis uses self-signed TLS certificates — disable peer verification.
if ENV["REDIS_URL"]&.start_with?("rediss://")
  redis_opts = { url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  Sidekiq.configure_server { |c| c.redis = redis_opts }
  Sidekiq.configure_client { |c| c.redis = redis_opts }
end
