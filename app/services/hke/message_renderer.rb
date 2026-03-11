# app/services/hke/message_renderer.rb
module Hke
  # Renders final message text dynamically.
  # Single source of truth for rendering, usable from Sidekiq and controllers.
  class MessageRenderer
    def self.render(relation:, delivery_method:, reference_date:, portal_url: nil)
      new(relation: relation, delivery_method: delivery_method, reference_date: reference_date, portal_url: portal_url).render
    end

    def initialize(relation:, delivery_method:, reference_date:, portal_url: nil)
      @relation = relation
      @delivery_method = delivery_method
      @reference_date = reference_date
      @portal_url = portal_url
      validate_inputs!
    end

    def render
      snippets.fetch(method_key, "").to_s
    end

    private

    attr_reader :relation, :delivery_method, :reference_date, :portal_url

    def validate_inputs!
      raise ArgumentError, "relation is required" unless relation
      raise ArgumentError, "delivery_method is required" if delivery_method.nil?
    end

    def method_key
      delivery_method.to_sym
    end

    def ref_date
      reference_date || Time.zone.today
    end

    def snippets
      # Relation includes Hke::MessageGenerator
      relation.generate_hebrew_snippets(relation, [method_key], reference_date: ref_date, portal_url: portal_url) || {}
    end
  end
end
