json.extract! future_message, :send_date, :message_type, :delivery_method, :email, :phone, :token
json.rendered_message Hke::MessageRenderer.render(
  relation: future_message.messageable,
  delivery_method: future_message.delivery_method,
  reference_date: future_message.send_date
)
json.url hke_future_message_url(future_message, format: :json)


