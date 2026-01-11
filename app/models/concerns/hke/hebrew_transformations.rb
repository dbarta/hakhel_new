module Hke
  module HebrewTransformations
    extend ActiveSupport::Concern
    include Hke::ApplicationHelper

    # included do
    #   after_validation :shared_custom_method
    # end

    def transform_gender
      puts "@@@@@ 1 #{gender}"
      self.gender = english_gender(gender)
      puts "@@@@@ 2 #{gender}"
      if gender.nil?
        errors.add(:gender, :gender_invalid)
      end
    end

    def transform_hebrew_dates
      return if errors.any? # Can't do transormations if any field is blank, etc.
      check_and_transform_hebrew_month
      check_and_transform_hebrew_day
      calculate_gregorian_date_of_death
    end

    def check_and_transform_hebrew_month
      english_month = Hke.hebrew_month_to_english(hebrew_month_of_death)
      if english_month
        hebrew_month_of_death = Hke.english_month_to_hebrew(english_month)
      else
        errors.add(:hebrew_month_of_death, :value_invalid)
      end
    end

    def check_and_transform_hebrew_day
      num = Hke.hebrew_date_numeric_value(hebrew_day_of_death)
      if (1..31).include? num
        hebrew_day_of_death = hebrew_day_select[num - 1] # Array begins with 0
      else
        errors.add(:hebrew_day_of_death, :value_invalid)
      end
    end

    def calculate_gregorian_date_of_death
      # puts "@@@@@@@@ in calculate_gregorian_date_of_death: #{name}, #{hebrew_year_of_death}, #{hebrew_month_of_death}, #{hebrew_day_of_death}"
      self.date_of_death = Hke.h2g name, hebrew_year_of_death, hebrew_month_of_death, hebrew_day_of_death
      # puts "@@@@@@@@ after calculate_gregorian_date_of_death: #{date_of_death}"
    end

    def english_gender hebrew_gender
      # [ [ "זכר" , "male" ],  [ "נקבה" , "female" ] ]
      he_en_pair = gender_select.find { |pair| pair[0] == hebrew_gender }
      he_en_pair ? he_en_pair[1] : nil
    end
  end
end
