# Fail-fast ActsAsTenant Sidekiq behavior.
#
# If a Sidekiq job contains serialized acts_as_tenant context, but the tenant record
# no longer exists, we treat this as a fatal programming/data error:
# - Log a clear error
# - Do NOT retry the job
#
# Rationale: running without a tenant would hide data isolation bugs.

begin
  require "sidekiq"
rescue LoadError
  # Sidekiq not available in this environment
end

begin
  require "acts_as_tenant/sidekiq"
rescue LoadError
  # acts_as_tenant Sidekiq integration not available
end

if defined?(ActsAsTenant::Sidekiq::Server)
  module ActsAsTenant
    module Sidekiq
      module FailFastServerMiddleware
        def call(worker_class, msg, queue, &block)
          super
        rescue ActiveRecord::RecordNotFound => e
          tenant_class = msg.is_a?(Hash) ? msg.dig("acts_as_tenant", "class") : nil
          tenant_id = msg.is_a?(Hash) ? msg.dig("acts_as_tenant", "id") : nil
          jid = msg.is_a?(Hash) ? msg["jid"] : nil
          args = msg.is_a?(Hash) ? msg["args"] : nil

          # Ensure Sidekiq does not retry this job.
          msg["retry"] = false if msg.is_a?(Hash)

          message = "FATAL: ActsAsTenant tenant not found for Sidekiq job. " \
                    "worker_class=#{worker_class} queue=#{queue} jid=#{jid} " \
                    "tenant=#{tenant_class}(id=#{tenant_id}) args=#{args.inspect} " \
                    "error=#{e.class}: #{e.message}"

          Rails.logger.error(message)
          ::Sidekiq.logger.error(message) if defined?(::Sidekiq)

          raise
        end
      end
    end
  end

  ActsAsTenant::Sidekiq::Server.prepend(ActsAsTenant::Sidekiq::FailFastServerMiddleware)
end