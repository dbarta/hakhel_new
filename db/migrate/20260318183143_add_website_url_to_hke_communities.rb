class AddWebsiteUrlToHkeCommunities < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_communities, :website_url, :string
  end
end
