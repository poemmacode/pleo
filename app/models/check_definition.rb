# Catalog entries synced from Audit::Catalog; texts come from the locale files in the current language.
class CheckDefinition < ApplicationRecord
  def title = Audit::Check.text(key, :title)

  def description = Audit::Check.text(key, :description)

  def how_to_fix = Audit::Check.text(key, :fix)
end
