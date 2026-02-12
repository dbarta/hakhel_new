module Hke
  class Community < Hke::ApplicationRecord
    belongs_to :account

    include Hke::Addressable
    include Hke::Preferring

    enum :community_type, {synagogue: "synagogue", school: "school"}

    validates :name, presence: true
    validates :community_type, presence: true

    before_save :ensure_account
    after_create :schedule_daily_job
    after_destroy :remove_daily_job

    def account_name
      account&.name || "N/A"
    end

    private

    def ensure_account
      self.account ||= Account.create!(name: name, personal: false)
    end

    def schedule_daily_job
      puts "@@@@@@@@@@@@@@@@@ Scheduling daily job for community #{id}"

      job_name = "daily_for_community_#{id}"

      resolved = Hke::PreferenceResolver.resolve(preferring: self)
      hh, mm = resolved.daily_sweep_wall_clock_hm || [3, 0]

      puts "=== SCHED resolved wall clock #{hh}:#{mm}"

      cron_expr = "#{mm} #{hh} * * *"

      Sidekiq::Cron::Job.find(job_name)&.destroy

      Sidekiq::Cron::Job.create(
        name: job_name,
        class: "Hke::FutureMessageCommunityDailySchedulerJob",
        args: [id],
        cron: cron_expr
      )

      sweep_str = format("%02d:%02d", hh, mm)

      Hke::Logger.log(
        event_type: "Daily Scheduler Job Ensured",
        details: {
          community_id: id,
          job_name: job_name,
          cron: cron_expr,
          sweep_time: sweep_str
        }
      )
    ensure
      ActsAsTenant.current_tenant = nil
    end

    def remove_daily_job
      job_name = "daily_for_community_#{id}"

      Sidekiq::Cron::Job.find(job_name)&.destroy

      ActsAsTenant.current_tenant = self
      Hke::Logger.log(event_type: "Daily Scheduler Job Removed", details: {community_id: id, job_name: job_name})
    ensure
      ActsAsTenant.current_tenant = nil
    end
  end
end
