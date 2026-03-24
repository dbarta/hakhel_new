require_dependency "hke/loggable"

class Hke::Api::V1::SendgridCallbackController < ActionController::API
  include Hke::Loggable

  before_action :verify_sendgrid_signature
  skip_before_action :verify_authenticity_token, raise: false

  # POST /hke/api/v1/sendgrid/events
  # SendGrid posts an array of event objects.
  # Events we care about: delivered, bounce, spamreport, unsubscribe
  def events
    events = JSON.parse(request.body.read)

    events.each do |event|
      process_event(event)
    end

    head :ok
  rescue JSON::ParserError => e
    log_info "SendGrid webhook: JSON parse error: #{e.message}"
    head :bad_request
  end

  private

  def process_event(event)
    sg_message_id = extract_message_id(event["sg_message_id"])
    event_type    = event["event"].to_s

    log_info "SendGrid event: #{event_type} sg_message_id=#{sg_message_id}"

    return if sg_message_id.blank?

    case event_type
    when "delivered"
      handle_delivered(sg_message_id, event)
    when "bounce", "blocked"
      handle_bounce(sg_message_id, event)
    when "spamreport", "unsubscribe"
      handle_unsubscribe(sg_message_id, event)
    end
  end

  # SendGrid appends a filter ID after a dot: "abc123.filter0001"
  # We store only the part before the dot.
  def extract_message_id(raw)
    raw.to_s.split(".").first.presence
  end

  def handle_delivered(sg_message_id, event)
    sent = Hke::SentMessage.find_by(sendgrid_message_id: sg_message_id)
    if sent.nil?
      log_info "SendGrid delivered: no SentMessage for #{sg_message_id}"
      return
    end
    sent.update_columns(delivery_status: "delivered")
  end

  def handle_bounce(sg_message_id, event)
    sent = Hke::SentMessage.find_by(sendgrid_message_id: sg_message_id)
    if sent.nil?
      log_info "SendGrid bounce: no SentMessage for #{sg_message_id}"
      return
    end

    sent.update_columns(
      delivery_status: "bounced",
      twilio_error_message: event["reason"].to_s.truncate(500)
    )

    # Mark the contact's email as bounced so we don't send to it again.
    if sent.email.present?
      contact = Hke::ContactPerson.find_by(email: sent.email)
      contact&.email_bounced!
    end
  end

  def handle_unsubscribe(sg_message_id, event)
    sent = Hke::SentMessage.find_by(sendgrid_message_id: sg_message_id)
    if sent.nil?
      log_info "SendGrid unsubscribe: no SentMessage for #{sg_message_id}"
      return
    end

    sent.update_columns(delivery_status: "unsubscribed")

    if sent.email.present?
      contact = Hke::ContactPerson.find_by(email: sent.email)
      contact&.email_unsubscribed!
    end
  end

  # Verify the request using the SendGrid ECDSA public key.
  # See: https://docs.sendgrid.com/for-developers/tracking-events/getting-started-event-webhook-security-features
  def verify_sendgrid_signature
    public_key = ENV["SENDGRID_WEBHOOK_PUBLIC_KEY"].presence

    if public_key.blank?
      log_info "SendGrid signature check skipped: SENDGRID_WEBHOOK_PUBLIC_KEY not configured"
      return
    end

    signature  = request.headers["X-Twilio-Email-Event-Webhook-Signature"].to_s
    timestamp  = request.headers["X-Twilio-Email-Event-Webhook-Timestamp"].to_s
    payload    = timestamp + request.body.read
    request.body.rewind

    if signature.blank? || timestamp.blank?
      log_info "SendGrid signature check failed: missing headers"
      head :forbidden and return
    end

    unless valid_sendgrid_signature?(public_key, signature, payload)
      log_info "SendGrid signature validation FAILED"
      head :forbidden
    end
  end

  def valid_sendgrid_signature?(public_key_pem, signature_b64, payload)
    ec_key = OpenSSL::PKey::EC.new(Base64.decode64(public_key_pem))
    digest    = OpenSSL::Digest::SHA256.new
    sig_bytes = Base64.decode64(signature_b64)
    ec_key.verify(digest, sig_bytes, payload)
  rescue OpenSSL::PKey::ECError, OpenSSL::PKey::PKeyError => e
    log_info "SendGrid signature verification error: #{e.message}"
    false
  end
end
