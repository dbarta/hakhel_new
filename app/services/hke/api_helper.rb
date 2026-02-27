require "httparty"
require "nokogiri"

module Hke
  module ApiHelper
    include Hke::Loggable

    def clear_database
      # Clear Sidekiq queues first to avoid orphaned jobs
      clear_sidekiq

      # Clear any user community assignments to break foreign key constraints
      if User.table_exists?
        users_with_community = User.where.not(community_id: nil).count
        log_info "@@@ Found #{users_with_community} users with community assignments."

        if users_with_community > 0
          # Temporarily disable foreign key constraint to allow nullifying
          ActiveRecord::Base.connection.execute("SET session_replication_role = replica;")
          User.update_all(community_id: nil)
          ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT;")
          log_info "@@@ Cleared community_id for #{users_with_community} users."
        else
          log_info "@@@ No users with community assignments found."
        end
      end

      [
        Hke::FutureMessage,    # No dependencies
        Hke::SentMessage,      # No dependencies
        Hke::Relation,         # References DeceasedPerson/ContactPerson
        Hke::DeceasedPerson,   # References Cemetery/Community
        Hke::ContactPerson,    # References Community
        Hke::Cemetery,
        Hke::CsvImportLog,
        Hke::CsvImport,         # References Community
        Hke::System,           # No dependencies
        Hke::Log,              # No dependencies
        ApiToken,              # References User
        AccountUser,           # References Account + User
        Hke::Community,        # References Account (delete before Account)
        Account,               # References User (delete before User)
        User                  # Delete last
      ].each do |model|
        model.delete_all
        log_info "@@@ Database table for: #{model} successfully cleared."
      end
      log_info "@@@ All Hakhel database tables successfully cleared."
    end

    def clear_sidekiq
      require "sidekiq/api"

      # Clear all Sidekiq queues and jobs
      Sidekiq::Queue.new.clear
      Sidekiq::RetrySet.new.clear
      Sidekiq::DeadSet.new.clear
      Sidekiq::ScheduledSet.new.clear

      log_info "@@@ All Sidekiq queues successfully cleared."
    rescue LoadError
      log_info "@@@ Sidekiq not available - skipping queue clearing."
    rescue => e
      log_error "@@@ Error clearing Sidekiq queues: #{e.message}"
    end

    def check_response(request_body, response, raise: true)
      if !response.success?
        log_error "Failed call, code: #{response.code} with: #{request_body}"
        if response.body["errors"]
          response.body["errors"].each do |field, messages|
            messages.each { |message| log_error "#{field.capitalize}: #{message}" }
          end
        end
        raise "@@@ RAISED: API call failed." if raise
      end
      # log_info "Successful Api call with #{request_body}. response: #{response.inspect}"
      response
    end

    def post(url, body, headers: nil, raise: true)
      response = HTTParty.post(url, body: body.to_json, headers: headers || @headers, format: :json)
      check_response(body, response, raise: raise)
    end

    def patch(url, body, headers: nil, raise: true)
      response = HTTParty.patch(url, body: body.to_json, headers: headers || @headers, format: :json)
      check_response(body, response, raise: raise)
    end

    def get(url, body, raise: true)
      response = HTTParty.get(url, body: body.to_json, headers: @headers)
      check_response(body, response, raise: raise)
    end

    def login_as_admin
      response = post("#{@hakhel_url}/auth", {email: "david@odeca.net", password: "odeca111"})
      @headers["Authorization"] = "Bearer #{response["token"]}"
      @csrf_headers = fetch_csrf_headers
    end

    def init_urls
      @API_URL = ENV.fetch("HAKHEL_BASE_URL", "http://localhost:3000")
      @hakhel_url = "#{@API_URL}/api/v1"
      @hke_url = "#{@API_URL}/hke/api/v1"
      @headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      @csrf_headers = nil
    end

    def init_api
      init_urls
      login_as_admin
    end

    def csrf_headers
      @csrf_headers ||= fetch_csrf_headers
    end

    def fetch_csrf_headers
      response = HTTParty.get(@API_URL)
      cookie = response.headers["set-cookie"]
      token = extract_csrf_token(response.body)
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "X-CSRF-Token" => token,
        "Cookie" => cookie
      }
    end

    def extract_csrf_token(body)
      doc = Nokogiri::HTML(body)
      meta = doc.at('meta[name="csrf-token"]')
      meta&.attr("content") || raise("CSRF token not found on #{@API_URL}")
    end

    def create_admin_account_community_system
      # Create admin user directly via models to avoid API params/CSRF constraints
      user = User.find_or_initialize_by(email: "david@odeca.net")
      user.assign_attributes(
        first_name: "David",
        last_name: "Barta",
        name: "David Barta",
        password: "odeca111",
        terms_of_service: true,
        system_admin: true, community_admin: false, community_user: false
      )
      user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
      user.save!
      @user_id = user.id
      log_info "@@@ user: 'David Barta' successfully ensured with id: #{@user_id}."

      # Create account
      account_name = "Kfar Vradim"
      account = Account.find_or_create_by!(name: account_name) do |acc|
        acc.owner_id = @user_id
        acc.personal = false if acc.respond_to?(:personal=)
        acc.billing_email = "david@odeca.net" if acc.respond_to?(:billing_email=)
      end
      @account_id = account.id
      log_info "@@@ Account: '#{account_name}' ensured with id: #{@account_id}."

      # Create community
      community_name = "Kfar Vradim Synagogue"
      community = Hke::Community.find_or_create_by!(name: community_name) do |comm|
        comm.community_type = "synagogue"
        comm.account_id = @account_id
      end
      @community_id = community.id
      log_info "@@@ Community: '#{community_name}' ensured with id: #{@community_id}."

      # Ensure system record exists
      system = Hke::System.instance
      system.update!(product_name: "Hakhel", version: "0.1") if system.respond_to?(:product_name)
      log_info "@@@ System record ensured."

      # Ensure system preferences exist
      system_pref = Hke::Preference.find_or_initialize_by(preferring: system)
      system_pref.assign_attributes(
        how_many_days_before_yahrzeit_to_send_message: [7, 1],
        delivery_priority: ["sms", "whatsapp", "email"],
        enable_fallback_delivery_method: true,
        time_zone: "Asia/Jerusalem",
        daily_sweep_job_time: Time.parse("03:00"),
        send_window_start_time: Time.parse("09:00")
      )
      system_pref.save!
      log_info "@@@ System preferences ensured with id: #{system_pref.id}."
    end

    def create_or_find_cemetery(cemetery_name)
      return nil if cemetery_name.nil?

      # Create new cemetery if not found
      response = post("#{@hke_url}/cemeteries", {cemetery: {name: cemetery_name}})
      # log_info "Response from create cemetery: #{response}"
      if response && response["id"]
        response["id"]
      else
        log_error "Failed to create cemetery: #{cemetery_name}"
        nil
      end
    end
  end
end
