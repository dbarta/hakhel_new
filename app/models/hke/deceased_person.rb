module Hke
  class DeceasedPerson < CommunityRecord
    include Hke::Deduplicatable
    include Hke::LogModelEvents
    deduplication_fields :first_name, :last_name, :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death
    has_person_name

    # Associations
    has_many :relations, dependent: :destroy
    has_many :contact_people, through: :relations
    belongs_to :cemetery, optional: true
    has_one :preference, as: :preferring, dependent: :destroy
    accepts_nested_attributes_for :relations, allow_destroy: true, reject_if: :all_blank

    # Validations
    validates :first_name, :last_name, :gender, presence: {message: :presence}
    validates :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death, presence: {message: :presence}
    validates :gender, inclusion: {in: ["male", "female"], message: :gender_invalid}

    # Transformations
    include Hke::HebrewTransformations
    after_validation :transform_hebrew_dates
    after_commit :process_future_messages, on: :update

    def contact_name
      if relations.empty?
        ""
      else
        relations.first.contact_person.name
      end
    end

    def contact_names
      relations.map { |relation| relation.contact_person.name }.join(",")
    end

    private

    def process_future_messages
      relations.each(&:process_future_messages)
    end
  end
end
