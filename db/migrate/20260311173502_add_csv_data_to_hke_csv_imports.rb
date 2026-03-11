class AddCsvDataToHkeCsvImports < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_csv_imports, :csv_data, :text
  end
end
