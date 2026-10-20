class AddLocaleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :locale, :string, null: false, default: "en"
    # Reports are rendered in the language of the user who requested them.
    add_column :reports, :locale, :string, null: false, default: "en"
    # Check titles and guidance now live in the locale files (config/locales/checks.*.yml).
    remove_column :check_definitions, :title, :string
    remove_column :check_definitions, :description, :text
    remove_column :check_definitions, :how_to_fix, :text
  end
end
