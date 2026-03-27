class AddEmailVerificationToHkeContactPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_contact_people, :pending_email, :string
    add_column :hke_contact_people, :email_verification_token, :string
    add_column :hke_contact_people, :email_verification_sent_at, :datetime
    add_column :hke_contact_people, :bounce_sms_sent_at, :datetime

    add_index :hke_contact_people, :email_verification_token, unique: true
  end
end
