module Hke
  class ApplicationController < ActionController::Base
    include Hke::Authorization  # Use Hke's authorization instead of main app's

    #include JumpstartApp::Application.routes.url_helpers
    #helper Devise::Controllers::Helpers
    impersonates :user
    include Sortable
    include SetLocale
    include CurrentHelper
    include SetCurrentRequestDetails
    layout 'application'

    # Enable Pundit authorization for all Hke controllers
    after_action :verify_authorized, except: [:index]
    after_action :verify_policy_scoped, only: [:index]
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def remove_empty_relations_from(model_name, nested_model_name)
      x = params[model_name]
      relations = x["relations_attributes"]
      # {"1639369042549"=>{"relation_of_deceased_to_contact"=>"",
      #   "contact_person_attributes"=>{"first_name"=>"", "last_name"=>"", "email"=>"", "phone"=>""}, "_destroy"=>"false"}}
      if relations
        keys_to_remove = []
        relations.each do |rel_key, rel_attrs|
          if rel_attrs["relation_of_deceased_to_contact"].empty?
            keys_to_remove << rel_key
          else
            contact_attrs = rel_attrs[nested_model_name + "_attributes"]
            if contact_attrs
                if contact_attrs.values.all? ""
                  keys_to_remove << rel_key
                end
            end
          end
        end
        puts "2222222222 keys_to_remove: #{keys_to_remove}"
        keys_to_remove.each {|k| relations.delete k}
        puts "3333333333 relations: #{relations}"
        if relations.empty?
          params[model_name].delete "relations_attributes"
        else
          params[model_name]["relations_attributes"] = relations
        end
        puts "4444444444 params: #{params}"
      end
    end

    private

    def set_community_as_current_tenant
      if current_user&.system_admin?
        # System admin: use selected community or global access
        community = selected_community_for_system_admin
        ActsAsTenant.current_tenant = community
      elsif current_user&.community_admin? || current_user&.community_user?
        # Community users: scope to their assigned community
        ActsAsTenant.current_tenant = current_user.community
      else
        # Fallback to hardcoded community (temporary)
        community = Community.find_by(name: "Kfar Vradim Synagogue")
        ActsAsTenant.current_tenant = community if community
      end
    end

    def selected_community_for_system_admin
      # Check if system admin has selected a specific community
      if session[:selected_community_id].present?
        Community.find_by(id: session[:selected_community_id])
      else
        nil # Global access
      end
    end

    def authenticate_admin
      puts "in  authenticate_admin, #{true_user}"
      redirect_to "/", alert: t("unauthorized") unless user_signed_in? && current_user.admin?
    end
  end
end
