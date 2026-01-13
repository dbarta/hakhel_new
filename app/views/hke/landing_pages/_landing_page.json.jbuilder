json.extract! landing_page, :id, :name, :body, :user_id, :created_at, :updated_at
json.url landing_page_url(landing_page, format: :json)
