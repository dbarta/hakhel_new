module Hke
  module Portal
    class EmailVerificationsController < BaseController
      # GET /portal/:portal_token/email_verification/new
      def new
      end

      # POST /portal/:portal_token/email_verification
      def create
        new_email = params[:email].to_s.strip.downcase

        unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
          flash.now[:alert] = "כתובת המייל אינה תקינה"
          render :new, status: :unprocessable_entity
          return
        end

        @contact.initiate_email_verification!(new_email)
        @pending_email = new_email
        render :pending
      end

      # GET /portal/:portal_token/email_verification/verify?token=...
      def verify
        result = @contact.verify_email!(params[:token].to_s)
        case result
        when :ok
          @verified_email = @contact.email
          render :verified
        when :expired
          @error = t("hke.portal.email_verification.invalid_token")
          render :error, status: :unprocessable_entity
        when :invalid
          @error = t("hke.portal.email_verification.invalid_token")
          render :error, status: :unprocessable_entity
        end
      end
    end
  end
end
