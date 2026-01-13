json.extract! contact_person, :id, :first_name, :last_name, :email, :phone, :created_at, :updated_at
json.url contact_person_url(contact_person, format: :json)
