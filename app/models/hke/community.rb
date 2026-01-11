module Hke
  class Community < Hke::ApplicationRecord

    belongs_to :account
    include Hke::Addressable
    include Hke::Preferring

    # Enum for community type
    enum :community_type, {
      synagogue: "synagogue",
      school: "school"
    }

    validates :name, presence: true
    validates :community_type, presence: true

    before_save :ensure_account
    after_create :schedule_daily_job
    after_destroy :remove_daily_job

    # Method for search_results partial
    def account_name
      account&.name || 'N/A'
    end

    private

    # Ensure an account is created before saving the community
    def ensure_account
      self.account ||= Account.create!(name: name, personal: false)
    end

    def schedule_daily_job
      puts "@@@@@@@@@@@@@@@@@ Scheduling daily job for community #{id}"
      job_name = "daily_for_community_#{id}"
      Sidekiq::Cron::Job.create(
        name: job_name,
        class: 'Hke::FutureMessageCommunityDailySchedulerJob',
        args: [id],
        cron: '0 0 * * *' # every day at midnight
      )
      ActsAsTenant.current_tenant = self
      Hke::Logger.log(event_type: "Daily Scheduler Job Created", details: { community_id: id, job_name: job_name })
      ActsAsTenant.current_tenant = nil
    end

    def remove_daily_job
  job_name = "daily_for_community_#{id}"
  job = Sidekiq::Cron::Job.find(job_name)
  job.destroy if job
  ActsAsTenant.current_tenant = self
  Hke::Logger.log(event_type: "Daily Scheduler Job Removed", details: { community_id: id, job_name: job_name })
  ActsAsTenant.current_tenant = nil
    end
  end
end
