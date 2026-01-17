json.extract! future_message, :send_date, :full_message, :message_type, :delivery_method, :email, :phone, :token
json.url hke_future_message_url(future_message, format: :json)


