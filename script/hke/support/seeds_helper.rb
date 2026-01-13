# seeds_helper.rb
require "csv"
require "logger"
require "json"

module SeedsHelper
  include Hke::ApplicationHelper

  def log(filename)
    log_path = Rails.root.join("db", filename)
    File.delete(log_path) if File.exist?(log_path)
    logger = ::Logger.new(log_path)
    logger.datetime_format = "%Y-%m-%d %H:%M"
    logger
  end

  def log_error(msg)
    @error.error msg
    @num_errors += 1
  end

  def check_response(request_body, response, raise: true)
    if response.success?
      puts "@@@ Succefull call with #{request_body}"
      if response["id"]
        puts "@@@ returned id: #{response["id"]}"
        response["id"]
      else
        nil
      end
    else
      puts "@@@ ERROR: Failed call, code: #{response.code} with: #{request_body}"
      parsed = response.respond_to?(:parsed_response) ? response.parsed_response : nil
      errors = if parsed.is_a?(Hash)
        parsed["errors"] || parsed[:errors]
      elsif response.body.is_a?(Hash)
        response.body["errors"] || response.body[:errors]
      else
        nil
      end

      if errors.is_a?(Hash)
        errors.each do |field, messages|
          Array(messages).each do |message|
            puts "@@@ ERROR: #{field.to_s.capitalize}: #{message}"
          end
        end
      else
        puts "@@@ ERROR: Response body: #{response.body.inspect}"
      end

      raise "@@@ RAISED: API call failed." if raise
      nil
    end
  end

  def create_or_find_cemetery(cemetery_name)
    return nil if cemetery_name.nil?
    cemetery = Hke::Cemetery.find_by_name(cemetery_name)
    unless cemetery
      cemetery = Hke::Cemetery.create!(name: cemetery_name)
      @logger.info "Created cemetery: #{cemetery.name}"
    end
    cemetery
  end

  def create_or_find_deceased_person(dp)
    existing_dp = Hke::DeceasedPerson.find_by(first_name: dp.first_name, last_name: dp.last_name, father_first_name: dp.father_first_name, mother_first_name: dp.mother_first_name)
    if existing_dp
      @logger.info "Deceased #{dp.name} already exists, using it for another contact."
      existing_dp
    else
      if dp.save
        @logger.info "Deceased #{dp.name} saved."
      else
        @logger.error "There were #{dp.errors.count} errors:"
        dp.errors.full_messages.each do |message|
          @logger.info message
        end
      end
      dp
    end
  end

  def create_or_find_contact_person(cp, dp)
    existing_cp = Hke::ContactPerson.find_by(first_name: cp.first_name, last_name: cp.last_name, phone: cp.phone, email: cp.email)
    if existing_cp
      @logger.info "Contact #{cp.name} already exists, connecting it to #{dp.name}"
      existing_cp
    else
      cp.save
      @logger.info "Contact #{cp.name} saved, connecting it to #{dp.name}"
      cp
    end
  end

  def create_or_find_relation(r)
    existing_r = Hke::Relation.find_by(deceased_person_id: r.deceased_person_id, contact_person_id: r.contact_person_id)
    if existing_r
      log_error "Line: #{@line_no} -- relation '#{r.relation_of_deceased_to_contact}' between: #{r.deceased_person.name} and #{r.contact_person.name} already exists, skipping."
    else
      r.save
      @logger.info "relation '#{r.relation_of_deceased_to_contact}' between: #{r.deceased_person.name} and #{r.contact_person.name} saved."
    end
  end

  def english_gender(hebrew_gender)
    he_en_pair = gender_select.find { |pair| pair[0] == hebrew_gender }
    he_en_pair ? he_en_pair[1] : nil
  end

  def validate_hebrew_month(m)
    "month is missing" if m.nil?
  end

  def validate_names_and_gender(row)
    is_valid = true

    if row["שם פרטי של נפטר"].nil? || row["שם משפחה של נפטר"].nil?
      log_error "Line: #{@line_no} -- deceased first or last name is missing, skipping to next person"
      is_valid = false
    end

    if english_gender(row["מין של נפטר"]).nil?
      log_error "Line: #{@line_no} -- deceased gender is missing or invalid, skipping to next person"
      is_valid = false
    end

    if english_gender(row["מין של איש קשר"]).nil?
      log_error "Line: #{@line_no} -- contact person gender is missing or invalid, skipping to next person"
      is_valid = false
    end

    if row["שם פרטי איש קשר"].nil? || row["שם משפחה איש קשר"].nil? || row["טלפון איש קשר"].nil?
      log_error "Line: #{@line_no} -- one of contact person's first name, last name, phone number or gender is missing, skipping to next person."
      is_valid = false
    end

    is_valid
  end

  def validate_and_normalize_hebrew_dates!(row)
    is_valid = true
    day = row["יום פטירה"]
    month = row["חודש פטירה"]
    year = row["שנת פטירה"]

    dates_error = ""
    comma = ""
    if year.nil?
      dates_error = "year is missing"
      comma = ", "
    end

    if month.nil?
      dates_error += comma + "month is missing"
      comma = ", "
    elsif english_month = hebrew_month_to_english(month)
      if english_month.nil?
        dates_error += comma + "unknown month: #{month} provided"
        comma = ", "
      else
        month = english_month_to_hebrew(english_month)
      end
    end

    if day.nil?
      dates_error += comma + "day is missing"
    elsif num = hebrew_date_numeric_value(day)
      if (1..31).include?(num)
        day = hebrew_day_select[num - 1]
      else
        dates_error += comma + "illegal hebrew date #{day}"
      end
    end

    if dates_error != ""
      log_error "Line: #{@line_no} -- #{dates_error}, skipping to next person."
      is_valid = false
    end

    if is_valid
      row["יום פטירה"] = day
      row["חודש פטירה"] = month
      row["שנת פטירה"] = year
    end

    is_valid
  end
end
