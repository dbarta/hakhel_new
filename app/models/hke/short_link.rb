module Hke
  class ShortLink < CommunityRecord
    belongs_to :contact_person, class_name: "Hke::ContactPerson"

    validates :code, presence: true, uniqueness: true
    validates :contact_person, presence: true

    before_validation :generate_code, on: :create

    def record_click!
      now = Time.current
      update_columns(
        click_count: click_count + 1,
        first_clicked_at: first_clicked_at || now
      )
    end

    def portal_url
      "#{base_url}/portal/#{contact_person.portal_token}"
    end

    def short_url
      "#{base_url}/go/#{code}"
    end

    private

    def generate_code
      self.code ||= loop do
        token = SecureRandom.alphanumeric(7).downcase
        break token unless ShortLink.exists?(code: token)
      end
    end

    def base_url
      ENV.fetch("HAKHEL_BASE_URL", Rails.application.routes.default_url_options[:host] || "https://hakhel.net")
    end
  end
end
