require_dependency "hke/loggable"

class Hke::Api::V1::TwilioCallbackController < ActionController::API
  include Hke::Loggable

  before_action :verify_twilio_signature
  skip_before_action :verify_authenticity_token, raise: false

  # POST /hke/api/v1/twilio/sms/status
  # Twilio posts status callbacks here for every status transition on a message.
  # Params of interest: MessageSid, MessageStatus, ErrorCode, ErrorMessage
  def sms_status
    sid     = params[:MessageSid]
    status  = params[:MessageStatus]
    err_code = params[:ErrorCode].presence
    err_msg  = params[:ErrorMessage].presence

    log_info "Twilio callback: SID=#{sid} status=#{status} error=#{err_code}"

    if sid.blank? || status.blank?
      log_info "Twilio callback ignored: missing SID or status"
      head :ok and return
    end

    sent = Hke::SentMessage.find_by(twilio_message_sid: sid)

    if sent.nil?
      # Not found — could be a race (callback arrived before DB commit) or unknown SID.
      # Return 200 so Twilio doesn't retry; nothing to update.
      log_info "Twilio callback: no SentMessage found for SID #{sid}"
      head :ok and return
    end

    # update_columns skips validations and callbacks — safe for an audit-log record.
    sent.update_columns(
      delivery_status: status,
      twilio_error_code: err_code,
      twilio_error_message: err_msg
    )

    head :ok
  end

  private

  # Validate that the request genuinely came from Twilio by checking the
  # X-Twilio-Signature header against our auth token and the request URL.
  # On failure we return 403 and log the attempt.
  def verify_twilio_signature
    auth_token = ENV["TWILIO_AUTH_TOKEN"] ||
                 Rails.application.credentials.dig(:twilio, :auth_token)

    if auth_token.blank?
      log_info "Twilio signature check skipped: no TWILIO_AUTH_TOKEN configured"
      return
    end

    validator = Twilio::Security::RequestValidator.new(auth_token)
    signature = request.headers["X-Twilio-Signature"].to_s

    # Build the full URL Twilio signed — must match exactly what Twilio sees.
    url = request.original_url

    # Twilio signs POST params (not the body) for application/x-www-form-urlencoded.
    post_params = request.POST rescue {}

    unless validator.validate(url, post_params, signature)
      log_info "Twilio signature validation FAILED for #{url}"
      head :forbidden
    end
  end
end
