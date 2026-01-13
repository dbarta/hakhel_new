json.extract! deceased_person, :id, :first_name, :last_name, :gender, :occupation, :organization, :religion, :father_first_name, :mother_first_name, :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death, :date_of_death, :time_of_death, :location_of_death, :created_at, :updated_at
json.url deceased_person_url(deceased_person, format: :json)
