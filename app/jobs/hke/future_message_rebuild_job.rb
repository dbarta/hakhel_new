# frozen_string_literal: true

module Hke
  class FutureMessageRebuildJob
    include Sidekiq::Job

    # mode: "relation" | "community" | "system"
    # id: relation_id or community_id or nil
    def perform(mode, id = nil)
      case mode
      when "relation"
        rebuild_relation(id)
      when "community"
        rebuild_community(id)
      when "system"
        rebuild_system
      else
        Rails.logger.error("FutureMessageRebuildJob unknown mode=#{mode}")
      end
    end

    private

    def rebuild_relation(relation_id)
      r = Hke::Relation.find_by(id: relation_id)
      return unless r
      ActsAsTenant.current_tenant = r.community
      r.process_future_messages
    ensure
      ActsAsTenant.current_tenant = nil
    end

    def rebuild_community(community_id)
      c = Hke::Community.find_by(id: community_id)
      return unless c
      ActsAsTenant.current_tenant = c
      Hke::Relation.where(community_id: c.id).find_each do |r|
        r.process_future_messages
      end
    ensure
      ActsAsTenant.current_tenant = nil
    end

    def rebuild_system
      Hke::Community.find_each do |c|
        ActsAsTenant.current_tenant = c
        Hke::Relation.where(community_id: c.id).find_each do |r|
          r.process_future_messages
        end
      ensure
        ActsAsTenant.current_tenant = nil
      end
    end
  end
end
