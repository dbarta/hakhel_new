class BackfillPortalTokens < ActiveRecord::Migration[8.1]
  def up
    ActsAsTenant.without_tenant do
      Hke::ContactPerson.where(portal_token: nil).find_each do |cp|
        cp.regenerate_portal_token
      end
    end
  end

  def down
    # tokens are permanent — do not remove
  end
end
