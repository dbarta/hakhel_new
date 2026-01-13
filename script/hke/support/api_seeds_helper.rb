require "net/http"
require "json"

module Hke
  module ApiSeedsHelper # Assumes init_logging is called outside of this module
    include Hke::ApplicationHelper

    API_BASE_URL = "http://localhost:3000/api/v1"
    HEADERS = {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }

    def api_request(method, endpoint, params = {})
      uri = URI("#{API_BASE_URL}/#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)

      case method
      when :get
        request = Net::HTTP::Get.new(uri)
        request.set_form_data(params)
      when :post
        request = Net::HTTP::Post.new(uri)
        request.body = params.to_json
      end

      HEADERS.each { |k, v| request[k] = v }

      response = http.request(request)

      JSON.parse(response.body) if response.body
    rescue => e
      log_error "API request failed: #{e.message}"
      nil
    end

    def create_or_find_cemetery(cemetery_name)
      return nil if cemetery_name.nil?

      # Try to find existing cemetery
      response = api_request(:get, "cemeteries", {name: cemetery_name})
      if response && response["data"].any?
        cemetery = response["data"].first
        log_info "Found existing cemetery: #{cemetery["name"]}"
        return cemetery
      end

      # Create new cemetery if not found
      response = api_request(:post, "cemeteries", {cemetery: {name: cemetery_name}})
      if response && response["id"]
        log_info "Created cemetery: #{response["name"]}"
        response
      else
        log_error "Failed to create cemetery: #{cemetery_name}"
        nil
      end
    end

    def create_or_find_deceased_person(dp_params)
      # Search for existing deceased person
      search_params = {
        first_name: dp_params[:first_name],
        last_name: dp_params[:last_name],
        father_first_name: dp_params[:father_first_name],
        mother_first_name: dp_params[:mother_first_name]
      }

      response = api_request(:get, "deceased_people", search_params)
      if response && response["data"].any?
        existing_dp = response["data"].first
        log_info "Deceased #{existing_dp["name"]} already exists, using it for another contact."
        return existing_dp
      end

      # Create new deceased person
      response = api_request(:post, "deceased_people", {deceased_person: dp_params})
      if response && response["id"]
        log_info "Deceased #{response["name"]} saved."
        response
      else
        log_error "Failed to create deceased person: #{dp_params[:name]}"
        nil
      end
    end

    def create_or_find_contact_person(cp_params, dp_id)
      # Search for existing contact person
      search_params = {
        first_name: cp_params[:first_name],
        last_name: cp_params[:last_name],
        phone: cp_params[:phone],
        email: cp_params[:email]
      }

      response = api_request(:get, "contact_people", search_params)
      if response && response["data"].any?
        existing_cp = response["data"].first
        log_info "Contact #{existing_cp["name"]} already exists, connecting it to deceased person #{dp_id}"
        return existing_cp
      end

      # Create new contact person
      response = api_request(:post, "contact_people", {contact_person: cp_params})
      if response && response["id"]
        log_info "Contact #{response["name"]} saved, connecting it to deceased person #{dp_id}"
        response
      else
        log_error "Failed to create contact person: #{cp_params[:name]}"
        nil
      end
    end

    def create_or_find_relation(relation_params)
      # Check if relation exists
      search_params = {
        deceased_person_id: relation_params[:deceased_person_id],
        contact_person_id: relation_params[:contact_person_id]
      }

      response = api_request(:get, "relations", search_params)
      if response && response["data"].any?
        log_error "Line: #{@line_no} -- relation '#{relation_params[:relation_of_deceased_to_contact]}' between: #{relation_params[:deceased_person_id]} and #{relation_params[:contact_person_id]} already exists, skipping."
        return nil
      end

      # Create new relation
      response = api_request(:post, "relations", {relation: relation_params})
      if response && response["id"]
        log_info "relation '#{relation_params[:relation_of_deceased_to_contact]}' between: #{relation_params[:deceased_person_id]} and #{relation_params[:contact_person_id]} saved."
        response
      else
        log_error "Failed to create relation"
        nil
      end
    end

    # Existing helper methods that don't need API changes
    def english_gender(hebrew_gender)
      he_en_pair = gender_select.find { |pair| pair[0] == hebrew_gender }
      he_en_pair ? he_en_pair[1] : nil
    end

    def validate_hebrew_month(m)
      "month is missing" if m.nil?
    end

    def validate_names_and_gender(row)
      # ... keep existing implementation ...
    end

    def validate_and_normalize_hebrew_dates!(row)
      # ... keep existing implementation ...
    end
  end
end
